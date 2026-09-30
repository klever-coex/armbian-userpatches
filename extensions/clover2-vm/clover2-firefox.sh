function extension_prepare_config__install_firefox() {
	display_alert "Firefox from Mozilla's APT repository will be installed" "${EXTENSION}" "info"
}

function post_family_tweaks__20_install_firefox() {
	local keyring_dir="${SDCARD}/etc/apt/keyrings"
	local signing_key="${keyring_dir}/packages.mozilla.org.asc"
	local gpg_home="${EXTENSION_MANAGER_TMP_DIR}/mozilla-gnupg"
	local expected_fingerprint="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
	local actual_fingerprint

	display_alert "Adding Mozilla APT repository" "${EXTENSION}" "info"
	run_host_command_logged install -d -m 0755 "${keyring_dir}"
	run_host_command_logged wget -q \
		https://packages.mozilla.org/apt/repo-signing-key.gpg \
		-O "${signing_key}"
	run_host_command_logged chmod 0644 "${signing_key}"
	run_host_command_logged install -d -m 0700 "${gpg_home}"

	actual_fingerprint="$(gpg --homedir "${gpg_home}" --batch --with-colons --show-keys "${signing_key}" \
		| awk -F: '$1 == "fpr" { print $10; exit }')"
	if [[ "${actual_fingerprint}" != "${expected_fingerprint}" ]]; then
		exit_with_error "Mozilla repository signing key fingerprint mismatch" \
			"expected ${expected_fingerprint}, got ${actual_fingerprint:-unknown}"
	fi

	cat > "${SDCARD}/etc/apt/sources.list.d/mozilla.list" <<-'EOF'
	deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main
	EOF

	cat > "${SDCARD}/etc/apt/preferences.d/mozilla" <<-'EOF'
	Package: *
	Pin: origin packages.mozilla.org
	Pin-Priority: 1000

	Package: firefox
	Pin: release o=Ubuntu
	Pin-Priority: -1
	EOF

	do_with_retries 3 chroot_sdcard_apt_get_update
	chroot_sdcard_apt_get_install firefox
}
