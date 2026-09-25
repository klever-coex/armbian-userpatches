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

clover2_docker_images__klever5() {
	clover2_docker_want_image "ghcr.io/klever-coex/clover2/clover2-frontend:${CLOVER2_DOCKER_TAG}"
	clover2_docker_want_image "ghcr.io/klever-coex/clover2/clover2-docs:${CLOVER2_DOCKER_TAG}"
}

function post_family_config__klever5_pin_kernel() {
	if [[ -n "${PINNED_KERNELBRANCH:-}" ]]; then
		declare -g KERNELBRANCH="${PINNED_KERNELBRANCH}"
		display_alert "klever5: kernel pinned to ${KERNELBRANCH}" "${EXTENSION}" "info"
	fi
}

function post_family_tweaks__45_klever5() {
	klever5_main
}


function extension_prepare_config__klever5() {
	display_alert "klever5: drone image profile (systemd/udev/motd/firstboot/camera)" "${EXTENSION}" "info"
}

klever5_setup_zsh() {
	[[ -x "${SDCARD}/bin/zsh" ]] || exit_with_error "zsh not in the rootfs - armbian-zsh missing (BUILD_MINIMAL=yes?)"

	display_alert "clover2-user-setup: writing .zshrc for ${CLOVER2_USER}" "${EXTENSION}" "info"
	cat > "${SDCARD}/home/${CLOVER2_USER}/.zshrc" <<'EOF'
export ZSH="/etc/oh-my-zsh"
ZSH_THEME="gentoo"
ZSH_CACHE_DIR="$HOME/.oh-my-zsh/cache"
DISABLE_AUTO_UPDATE="true"
plugins=(evalcache git git-extras debian tmux screen history extract colorize docker)

source "$ZSH/oh-my-zsh.sh"

# history
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt share_history hist_ignore_dups hist_ignore_space

# completion
autoload -Uz compinit
compinit -d "$ZSH_CACHE_DIR/zcompdump"

# aliases
alias ll='ls -laF'
alias la='ls -A'
alias l='ls -CF'
export EDITOR=nano
EOF

	chroot_sdcard chown "${CLOVER2_USER}:${CLOVER2_USER}" "/home/${CLOVER2_USER}/.zshrc"
}

klever5_copy_files() {
	local src="${USERPATCHES_PATH}"

	# for wifi hotspot mode and motd
	chroot_sdcard_apt_get_install dnsmasq figlet

	# no serial console on the UART that talks to the FCU
	# sed -i -e 's/\( \|^\)console=serial0,115200\( \|$\)/ /g' -e 's/  */ /g' -e 's/^ //;s/ $//' "${SDCARD}/boot/firmware/cmdline.txt"
	local ws_assets="${SDCARD}/opt/clover2/ws/src/clover2/tooling/builder/assets"
	local user="${CLOVER2_USER:-pi}"

	# systemd units + enable (offline enable only creates symlinks, works in chroot)
	run_host_command_logged cp "${src}/systemd/"*.service "${SDCARD}/etc/systemd/system/"
	chroot_sdcard systemctl enable clover2.service clover2-web.service clover2-firstboot.service

	# udev rules, helper scripts
	run_host_command_logged cp "${src}/udev/"*.rules "${SDCARD}/etc/udev/rules.d/"
	run_host_command_logged cp "${src}/systemd/bin/"* "${SDCARD}/usr/local/bin/"
	run_host_command_logged chmod 755 "${SDCARD}/usr/local/bin/clover2_*.sh"

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

	chroot_sdcard chown -R "${CLOVER2_USER}:${CLOVER2_USER}" "/home/${CLOVER2_USER}/.ros"

	# log dir for the clover2 services
	run_host_command_logged mkdir -p "${SDCARD}/var/log/clover2"
	run_host_command_logged chmod 755 "${SDCARD}/var/log/clover2"

	# clover2 env + settings helper into the user's zsh
	local zshrc="${SDCARD}/home/${user}/.zshrc"
	if [[ -f "${zshrc}" ]]; then
		cat >> "${zshrc}" <<'EOF'

# clover2
export RCUTILS_COLORIZED_OUTPUT=1
export CLOVER2_CONFIG_FILE=/opt/clover2/.config.yaml

clover2-settings() {
	ros2 run clover2_ui settings \
		"$(ros2 pkg prefix clover2_bringup --share)/schemas/klever5.yaml" \
		"$CLOVER2_CONFIG_FILE"
}
EOF
	fi
}

klever5_log() {
	display_alert "klever5: $*" "${EXTENSION}" "info"
}

klever5_main() {
	klever5_log "installing drone integration assets"
	klever5_copy_files
	klever5_setup_zsh

	klever5_log "done"
}
