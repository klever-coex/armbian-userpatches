# Overrides:
#   CLOVER2_DDS_PROFILE: dds profile, see clover2-dev ansible ros2_dds role (default: loopback)
# 	CLOVER2_DDS_RMW: dds implimentation, see clover2-dev ansible ros2_dds role (default: cyclonedds)
# 	CLOVER2_DDS_DOMAIN_ID: ros2 domain id, see clover2-dev ansible ros2_dds role (default: 0)

enable_extension "clover2-ansible"

function extension_prepare_config__clover2_ros2() {
	display_alert "clover2-ros2: ROS 2 Jazzy will be provisioned into the image" "${EXTENSION}" "info"
}

function post_family_tweaks__30_clover2_ros2() {
	clover2_ros2_main
}

clover2_ros2_log() {
	display_alert "clover2-ros2: $*" "${EXTENSION}" "info"
}

clover2_ros2_install_build_tools() {
	chroot_sdcard_apt_get_install python3-colcon-common-extensions python3-rosdep

	chroot_sdcard "rosdep init 2>/dev/null || true"
	local rosdep_list="${SDCARD}/etc/rosdep/sources.list.d/20-default.list"
	if [[ ! -f "${rosdep_list}" ]]; then
		mkdir -p "${SDCARD}/etc/rosdep/sources.list.d"
		cat > "${rosdep_list}" <<'EOS'
yaml https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/base.yaml
yaml https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/python.yaml
yaml https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/ruby.yaml
gbpdistro https://raw.githubusercontent.com/ros/rosdistro/master/releases/fuerte.yaml fuerte
EOS
	fi
	chroot_sdcard "env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY rosdep update"
}

clover2_ros2_configure_dds() {
	clover2_ros2_log "configuring DDS via ros2_dds role"
	clover2_ansible_playbook_chroot clover2.dev.configure_dds --tags ros2_dds \
		-e ros2_dds_profile="${CLOVER2_DDS_PROFILE:-loopback}" \
		-e ros2_dds_rmw="${CLOVER2_DDS_RMW:-cyclonedds}" \
		-e ros2_dds_ros_domain_id="${CLOVER2_DDS_DOMAIN_ID:-0}"
}

clover2_ros2_zsh_env() {
	local zshrc="${SDCARD}/home/${CLOVER2_USER:-pi}/.zshrc"
	[[ -f "${zshrc}" ]] || return 0
	cat >> "${zshrc}" <<'EOF'

source /opt/ros/jazzy/setup.zsh
[ -f /etc/ros2/dds/env ] && . /etc/ros2/dds/env
EOF
}

clover2_ros2_main() {
	clover2_ros2_log "provisioning ROS 2 Jazzy via ansible"
	clover2_ansible_playbook_chroot clover2.dev.install_deps --tags core
	clover2_ros2_configure_dds
	clover2_ros2_install_build_tools
	clover2_ros2_zsh_env
	clover2_ros2_log "done"
}
