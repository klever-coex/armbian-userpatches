# Overrides:
#   CLOVER2_USER: user name (default pi)
#   CLOVER2_USER_PASSWORD: plain password (default raspberry)
#   CLOVER2_USER_GROUPS: supplementary groups (comma-separated)
#   CLOVER2_USER_SHELL: login shell (default /bin/bash)

function extension_prepare_config__clover2_user_setup() {
	display_alert "clover2-user-setup: user '${CLOVER2_USER:-"pi"}' will be created in the image" "${EXTENSION}" "info"
}

function post_family_tweaks__10_clover2_user_setup() {
	clover2_user_setup_main
}

function clover2_user_setup_create_user() {
	CLOVER2_USER="${CLOVER2_USER:-"pi"}"
	CLOVER2_USER_PASSWORD="${CLOVER2_USER_PASSWORD:-"raspberry"}"
	CLOVER2_USER_GROUPS="${CLOVER2_USER_GROUPS:-"sudo,adm,dialout,cdrom,plugdev,video,audio,netdev,render"}"
	local user_shell="${CLOVER2_USER_SHELL:-/bin/bash}"
	[[ -x "${SDCARD}${user_shell}" ]] || exit_with_error "clover2-user-setup: ${user_shell} not in the rootfs"

	display_alert "clover2-user-setup: creating user ${CLOVER2_USER}" "${EXTENSION}" "info"
	chroot_sdcard "id -u ${CLOVER2_USER} &>/dev/null || useradd -m -s ${user_shell} \
		-G ${CLOVER2_USER_GROUPS} ${CLOVER2_USER}"
	chroot_sdcard "echo '${CLOVER2_USER}:${CLOVER2_USER_PASSWORD}' | chpasswd"

	echo "${CLOVER2_USER} ALL=(ALL) NOPASSWD:ALL" > "${SDCARD}/etc/sudoers.d/01-nopasswd"
	run_host_command_logged chmod 440 "${SDCARD}/etc/sudoers.d/01-nopasswd"

	chroot_sdcard "visudo -cf /etc/sudoers.d/01-nopasswd"
}

function clover2_user_setup_main() {
	clover2_user_setup_create_user
}
