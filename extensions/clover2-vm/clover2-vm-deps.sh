enable_extension "clover2-ansible"

function extension_prepare_config__clover2_vm_deps() {
	display_alert "clover2-vm-deps: ROS 2 Jazzy will be provisioned into the image" "${EXTENSION}" "info"
}

function post_family_tweaks__30_clover2_vm_deps() {
	clover2_vm_deps_main
}

clover2_vm_deps_log() {
	display_alert "clover2-vm-deps: $*" "${EXTENSION}" "info"
}

clover2_vm_deps_main() {
	clover2_vm_deps_log "provisioning ROS 2 Jazzy and simulation deps via ansible"
	clover2_ansible_playbook_chroot clover2.dev.install_deps --tags simulation
	clover2_vm_deps_log "done"
}
