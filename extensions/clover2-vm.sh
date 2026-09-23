enable_extension "clover2-user-setup"
enable_extension "clover2-vm-firefox"
enable_extension "clover2-vm-deps"
enable_extension "clover2-dev"
enable_extension "clover2-vm-qgroundcontrol"

function post_family_tweaks__45_clover2_vm() {
	clover2_vm_setup_firstboot_script
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
