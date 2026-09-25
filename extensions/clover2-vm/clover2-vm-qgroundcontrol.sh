# Overrides:
#   CLOVER2_QGC_VERSION: QGroundControl release tag (default: v5.1.4)

function extension_prepare_config__clover2_vm_qgroundcontrol() {
	display_alert "clover2-vm-qgroundcontrol: QGroundControl will be installed into the image" "${EXTENSION}" "info"
}

function post_family_tweaks__50_clover2_vm_qgroundcontrol() {
	clover2_vm_qgroundcontrol_install
}

clover2_vm_qgroundcontrol_log() {
	display_alert "clover2-vm-qgroundcontrol: $*" "${EXTENSION}" "info"
}

clover2_vm_qgroundcontrol_fetch() {
	local qgc_version="$1" qgc_arch="$2" qgc_dest="$3" icon_dest="$4"
	local image_name="QGroundControl-${qgc_version}-${qgc_arch}.AppImage"
	local icon_name="qgroundcontrol-${qgc_version}.png"
	local qgc_url="https://github.com/mavlink/qgroundcontrol/releases/download/${qgc_version}/QGroundControl-${qgc_arch}.AppImage"
	local icon_url="https://raw.githubusercontent.com/mavlink/qgroundcontrol/${qgc_version}/resources/icons/qgroundcontrol.png"
	local cache_dir="${SRC}/cache/clover2/qgroundcontrol/"

	run_host_command_logged mkdir -p "${cache_dir}"

	if [[ ! -f "${cache_dir}/${image_name}" ]]; then
		clover2_vm_qgroundcontrol_log "fetching QGroundControl ${qgc_version} from ${qgc_url}"
		run_host_command_logged wget -q "${qgc_url}" -O "${cache_dir}/${image_name}"
		clover2_vm_qgroundcontrol_log "QGroundControl ${qgc_version} fetched into ${cache_dir}"
	else
		clover2_vm_qgroundcontrol_log "QGroundControl ${qgc_version} already exists in ${cache_dir}, skipping download"
	fi

	if [[ ! -f "${cache_dir}/${icon_name}" ]]; then
		clover2_vm_qgroundcontrol_log "fetching QGroundControl ${qgc_version} icon from ${icon_url}"
		run_host_command_logged wget -q "${icon_url}" -O "${cache_dir}/${icon_name}"
		clover2_vm_qgroundcontrol_log "QGroundControl ${qgc_version} icon fetched into ${cache_dir}"
	else
		clover2_vm_qgroundcontrol_log "QGroundControl ${qgc_version} icon already exists in ${cache_dir}, skipping download"
	fi

	run_host_command_logged cp "${cache_dir}/${image_name}" "${qgc_dest}"
	run_host_command_logged cp "${cache_dir}/${icon_name}" "${icon_dest}"
}

clover2_vm_qgroundcontrol_install() {
	local qgc_version="${CLOVER2_QGC_VERSION:-"v5.1.4"}"
	local user="${CLOVER2_USER:-pi}"
	local qgc_arch

	case "${ARCH}" in
		arm64) qgc_arch="aarch64" ;;
		amd64) qgc_arch="x86_64" ;;
		*) exit_with_error "No QGroundControl AppImage for architecture: ${ARCH}" ;;
	esac

	local qgc_path="${SDCARD}/home/${user}/.local/bin/qgroundcontrol"
	local icon_path="${SDCARD}/home/${user}/.local/share/icons/qgroundcontrol.png"
	local desktop_path="${SDCARD}/home/${user}/.local/share/applications/qgroundcontrol.desktop"

	clover2_vm_qgroundcontrol_log "installing QGroundControl ${qgc_version} for ${ARCH}"
	run_host_command_logged mkdir -p \
		"$(dirname "${qgc_path}")" \
		"$(dirname "${icon_path}")" \
		"$(dirname "${desktop_path}")"
	clover2_vm_qgroundcontrol_fetch "${qgc_version}" "${qgc_arch}" "${qgc_path}" "${icon_path}"
	run_host_command_logged chmod 755 "${qgc_path}"

	cat > "${desktop_path}" <<-EOF
	[Desktop Entry]
	Name=QGroundControl
	Comment=Ground control station for drones
	Exec=/home/${user}/.local/bin/qgroundcontrol
	Icon=qgroundcontrol
	Terminal=false
	Type=Application
	Categories=Development;Science;
	EOF
	run_host_command_logged chmod 755 "${desktop_path}"
	chroot_sdcard chown -R "${user}:${user}" "/home/${user}/.local"

	clover2_vm_qgroundcontrol_log "done"
}
