enable_extension "clover2-user-setup"
enable_extension "clover2-vm-firefox"
enable_extension "clover2-vm-vscode"
enable_extension "clover2-vm-deps"
enable_extension "clover2-dev"
enable_extension "clover2-vm-qgroundcontrol"

function extension_prepare_config__clover2_vm() {
	declare -g CLOVER2_USER_SHELL="${CLOVER2_USER_SHELL:-/bin/bash}"
}

function post_family_tweaks__45_clover2_vm() {
	clover2_vm_setup_firstboot_script
	clover2_vm_configure_power_management
}

clover2_vm_log() {
	display_alert "clover2-vm: $*" "${EXTENSION}" "info"
}

clover2_vm_setup_firstboot_script() {
	local source="${USERPATCHES_PATH}/firstboot/clover2_vm_firstboot.sh"
	local destination="${SDCARD}/usr/lib/armbian/armbian-firstlogin"

	if [[ -f "${source}" ]]; then
		run_host_command_logged install -m 0755 "${source}" "${destination}"
        clover2_vm_log "firstboot script installed to ${destination}"
	fi
}

clover2_vm_configure_power_management() {
	local user="${CLOVER2_USER:-pi}"

	clover2_vm_log "configuring display timers and automatic screen locking"
	# Configure the existing VM user without requiring a graphical session.
	# The builder's XDG_RUNTIME_DIR is outside the target rootfs.
	chroot_sdcard "runuser -u ${user@Q} -- env -u XDG_RUNTIME_DIR dbus-run-session -- bash -e -o pipefail -s" <<-'EOF'
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled -n -t bool -s true
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac -n -t uint -s 0
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-sleep -n -t uint -s 0
	xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-on-ac-off -n -t uint -s 0

	xfconf-query -c xfce4-power-manager \
		-p /xfce4-power-manager/lock-screen-suspend-hibernate -n -t bool -s false
	xfconf-query -c xfce4-session -p /shutdown/LockScreen -n -t bool -s false

	gsettings set apps.light-locker lock-after-screensaver 0
	gsettings set apps.light-locker late-locking false
	gsettings set apps.light-locker lock-on-suspend false
	EOF
}
