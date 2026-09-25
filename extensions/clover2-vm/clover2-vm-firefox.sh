function extension_prepare_config__install_firefox() {
	display_alert "Firefox from Mozilla's APT repository will be installed" "${EXTENSION}" "info"
}

clover2_vm_firefox_install() {
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
	chroot_sdcard_apt_get_install firefox xdg-utils
}

clover2_vm_firefox_set_default() {
	local user="${CLOVER2_USER:-pi}"
	local user_home="/home/${user}"
	local user_xfce_dir="${SDCARD}${user_home}/.config/xfce4"
	local mime_type

	display_alert "Setting Firefox as the default browser" "${EXTENSION}" "info"
	chroot_sdcard "update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox 200"
	chroot_sdcard "update-alternatives --set x-www-browser /usr/bin/firefox"

	run_host_command_logged install -d -m 0755 "${SDCARD}/etc/xdg/xfce4"
	cat > "${SDCARD}/etc/xdg/xfce4/helpers.rc" <<-'EOF'
	[Helpers]
	WebBrowser=firefox
	EOF

	cat > "${SDCARD}/etc/xdg/xfce-mimeapps.list" <<-'EOF'
	[Default Applications]
	application/xhtml+xml=firefox.desktop
	text/html=firefox.desktop
	x-scheme-handler/http=firefox.desktop
	x-scheme-handler/https=firefox.desktop
	EOF

	run_host_command_logged install -d -m 0755 "${user_xfce_dir}"
	cat > "${user_xfce_dir}/helpers.rc" <<-'EOF'
	[Helpers]
	WebBrowser=firefox
	EOF
	chroot_sdcard "chown -R ${user}:${user} ${user_home}/.config"

	for mime_type in \
		application/xhtml+xml \
		text/html \
		x-scheme-handler/http \
		x-scheme-handler/https; do
		chroot_sdcard "runuser -u ${user} -- env HOME=${user_home} XDG_CONFIG_HOME=${user_home}/.config xdg-mime default firefox.desktop ${mime_type}"
	done
}

clover2_vm_firefox_configure_profile() {
	local user="${CLOVER2_USER:-pi}"
	local firefox_config_dir="${SDCARD}/home/${user}/.mozilla/firefox"
	local firefox_profile_dir="${firefox_config_dir}/clover2.default-release"

	display_alert "Configuring Firefox for ${user}" "${EXTENSION}" "info"
	run_host_command_logged install -d -m 0755 "${firefox_profile_dir}"
	cat > "${firefox_config_dir}/profiles.ini" <<-'EOF'
	[General]
	StartWithLastProfile=1
	Version=2

	[Profile0]
	Name=default-release
	IsRelative=1
	Path=clover2.default-release
	Default=1
	EOF

	cat > "${firefox_profile_dir}/user.js" <<-'EOF'
	user_pref("browser.preferences.defaultPerformanceSettings.enabled", false);
	user_pref("layers.acceleration.disabled", true);
	EOF
	chroot_sdcard "chown -R ${user}:${user} /home/${user}/.mozilla"
}

clover2_vm_firefox_install_policies() {
	run_host_command_logged install -d -m 0755 "${SDCARD}/etc/firefox/policies"
	cat > "${SDCARD}/etc/firefox/policies/policies.json" <<-'EOF'
	{
	  "policies": {
	    "Homepage": {
	      "URL": "https://klever-doc.tech/",
	      "Locked": true,
	      "StartPage": "homepage"
	    },
	    "OverrideFirstRunPage": "https://klever-doc.tech/",
	    "HardwareAcceleration": false,
	    "OverridePostUpdatePage": "",
	    "DisableTelemetry": true,
	    "DisableFirefoxStudies": true,
	    "DisablePocket": true,
	    "DontCheckDefaultBrowser": true,
	    "NoDefaultBookmarks": true,
	    "FirefoxHome": {
	      "SponsoredTopSites": false
	    },
	    "ManagedBookmarks": [
	      {
	        "toplevel_name": "Klever"
	      },
	      {
	        "url": "https://klever-doc.tech/",
	        "name": "Klever DOC"
	      }
	    ]
	  }
	}
	EOF
}

function post_family_tweaks__20_install_firefox() {
	clover2_vm_firefox_install
	clover2_vm_firefox_set_default
	clover2_vm_firefox_configure_profile
	clover2_vm_firefox_install_policies
}
