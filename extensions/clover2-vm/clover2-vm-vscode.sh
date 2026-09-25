# Overrides:
#   CLOVER2_DEV_VSCODE_EXTENSIONS: space-separated list of name@version
#                                  (default "meta.pyrefly")

function extension_prepare_config__install_vscode() {
	display_alert "Visual Studio Code from Microsoft's APT repository will be installed" "${EXTENSION}" "info"
}

clover2_vm_vscode_log() {
	display_alert "clover2-vm-vscode: $*" "${EXTENSION}" "info"
}

function post_family_tweaks__25_install_vscode() {
	local keyring_dir="${SDCARD}/usr/share/keyrings"
	local signing_key="${keyring_dir}/microsoft.gpg"
	local user="${CLOVER2_USER:-pi}"

	clover2_vm_vscode_log "Adding Microsoft Visual Studio Code APT repository"
	chroot_sdcard_apt_get_install wget gpg
	run_host_command_logged install -d -m 0755 "${keyring_dir}"
	chroot_sdcard "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --batch --yes --dearmor -o /usr/share/keyrings/microsoft.gpg"
	run_host_command_logged chmod 0644 "${signing_key}"

	cat > "${SDCARD}/etc/apt/sources.list.d/vscode.sources" <<-'EOF'
	Types: deb
	URIs: https://packages.microsoft.com/repos/code
	Suites: stable
	Components: main
	Architectures: amd64,arm64,armhf
	Signed-By: /usr/share/keyrings/microsoft.gpg
	EOF

	do_with_retries 3 chroot_sdcard_apt_get_update
	chroot_sdcard_apt_get_install code
	clover2_vm_vscode_log "Visual Studio Code installed"

	local -a extensions=()
	read -r -a extensions <<< "${CLOVER2_DEV_VSCODE_EXTENSIONS:-"meta.pyrefly"}"

	local extension
	for extension in "${extensions[@]}"; do
		clover2_vm_vscode_log "Installing extension ${extension} for ${user}"
		chroot_sdcard "runuser -u ${user} -- env HOME=/home/${user} code --install-extension ${extension}"
	done
}
