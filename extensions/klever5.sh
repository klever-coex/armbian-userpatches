#
# SPDX-License-Identifier: GPL-2.0
#
# klever5 - the drone image profile (Raspberry Pi 5): bundles everything the
# onboard computer needs on top of the shared clover2 layers.
#
# Enables the whole chain via enable_extension, so a board config lists just
# this one extension:
#
#   clover2-user-setup   (10) the pi user
#   clover2-libcamera    (20) libcamera deb (camera pipeline)
#   clover2-ros2         (30) ROS 2 Jazzy + DDS (ros2_dds role)
#   clover2              (40) the clover2 workspace build
#   klever5              (45) drone integration: systemd units, udev rules,
#                            motd, firstboot, camera calibrations, launcher
#                            config - this file
#   clover2-docker       (50) docker-ce + compose v2 + image tars
#   clover2-vscodium     (60) web IDE
#
# The simulation profile (VirtualBox/x86) uses the shared layers without
# this extension - see config-clover2-vb.conf.

enable_extension "clover2-user-setup"
enable_extension "clover2-libcamera"
enable_extension "clover2-ros2"
enable_extension "clover2"
enable_extension "clover2-docker"
enable_extension "clover2-vscodium"

function extension_prepare_config__klever5() {
	display_alert "klever5: drone image profile (systemd/udev/motd/firstboot/camera)" "${EXTENSION}" "info"
}

function post_family_tweaks__45_klever5() {
	klever5_log "installing drone integration assets"
	local src="${USERPATCHES_PATH}"
	local ws_assets="${SDCARD}/opt/clover2/ws/src/clover2/tooling/builder/assets"
	local user="${CLOVER2_USER:-pi}"

	# systemd units + enable (offline enable only creates symlinks, works in chroot)
	run_host_command_logged cp "${src}/systemd/"*.service "${SDCARD}/etc/systemd/system/"
	chroot_sdcard systemctl enable clover2.service clover2-web.service clover2-firstboot.service

	# udev rules, helper scripts
	run_host_command_logged cp "${src}/udev/"*.rules "${SDCARD}/etc/udev/rules.d/"
	run_host_command_logged cp "${src}/systemd/bin/"* "${SDCARD}/usr/local/bin/"
	run_host_command_logged chmod 755 "${SDCARD}/usr/local/bin/clover2_*.sh" "${SDCARD}/usr/local/bin/ros2_launch.sh"

	# firstboot script (wifi AP, docker load, self-removal)
	run_host_command_logged cp "${src}/firstboot/clover2_firstboot.sh" "${SDCARD}/root/"
	run_host_command_logged chmod 755 "${SDCARD}/root/clover2_firstboot.sh"

	# motd
	run_host_command_logged cp "${src}/motd/"* "${SDCARD}/etc/update-motd.d/"
	run_host_command_logged chmod 755 "${SDCARD}/etc/update-motd.d/"*

	# launcher config + camera calibrations (ws assets until they move to
	# the clover2-dev ansible collection)
	run_host_command_logged cp "${ws_assets}/launcher_config.yaml" "${SDCARD}/opt/clover2/.config.yaml"
	run_host_command_logged mkdir -p "${SDCARD}/home/${user}/.ros/camera_info"
	run_host_command_logged cp "${ws_assets}/camera_info/"* "${SDCARD}/home/${user}/.ros/camera_info/"

	# log dir for the clover2 services
	run_host_command_logged mkdir -p "${SDCARD}/var/log/clover2"
	run_host_command_logged chmod 755 "${SDCARD}/var/log/clover2"

	klever5_log "done"
}

klever5_log() {
	display_alert "klever5: $*" "${EXTENSION}" "info"
}
