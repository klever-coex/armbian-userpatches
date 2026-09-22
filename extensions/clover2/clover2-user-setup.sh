# Overrides:
#   CLOVER2_USER: user name (default pi)
#   CLOVER2_USER_PASSWORD: plain password (default raspberry)
#   CLOVER2_USER_GROUPS: supplementary groups (comma-separated)

function extension_prepare_config__clover2_user_setup() {
	display_alert "clover2-user-setup: user '${CLOVER2_USER:-"pi"}' will be created in the image" "${EXTENSION}" "info"
}

function post_family_tweaks__10_clover2_user_setup() {
	CLOVER2_USER="${CLOVER2_USER:-"pi"}"
	CLOVER2_USER_PASSWORD="${CLOVER2_USER_PASSWORD:-"raspberry"}"
	CLOVER2_USER_GROUPS="${CLOVER2_USER_GROUPS:-"sudo,adm,dialout,cdrom,plugdev,video,audio,netdev,render"}"

	display_alert "clover2-user-setup: creating user ${CLOVER2_USER}" "${EXTENSION}" "info"
	chroot_sdcard "id -u ${CLOVER2_USER} &>/dev/null || useradd -m -s /bin/bash \
		-G ${CLOVER2_USER_GROUPS} ${CLOVER2_USER}"
	chroot_sdcard "echo '${CLOVER2_USER}:${CLOVER2_USER_PASSWORD}' | chpasswd"

	# passwordless sudo for the image user (sudoers/01-nopasswd)
	local sudoers_src="${USERPATCHES_PATH}/sudoers"
	if [[ -d "${sudoers_src}" ]]; then
		run_host_command_logged cp "${sudoers_src}/"* "${SDCARD}/etc/sudoers.d/"
		run_host_command_logged chmod 440 "${SDCARD}/etc/sudoers.d/"*
	fi
}
