# Overrides:
#   CLOVER2_DEV_COMMIT: clover2-dev tag or commit (default: master)

enable_extension "clover2-ws"

function extension_prepare_config__clover2_dev() {
	display_alert "clover2-dev: the simulation workspace will be built into the image" "${EXTENSION}" "info"
}

function post_family_tweaks__40_clover2_dev() {
	clover2_dev_main
}

clover2_dev_log() {
	display_alert "clover2-dev: $*" "${EXTENSION}" "info"
}

clover2_dev_fetch_repo() {
	local url="$1" ref="$2" dest="$3"

	if [[ -d "${dest}/.git" ]]; then
		run_host_command_logged git -C "${dest}" fetch --tags origin
	else
		run_host_command_logged git clone "${url}" "${dest}"
	fi

	run_host_command_logged git -C "${dest}" checkout --force "${ref}"
}

clover2_dev_prepare_workspace() {
	CLOVER2_DEV_REPO="https://github.com/klever-coex/clover2-dev.git"
	CLOVER2_DEV_COMMIT="${CLOVER2_DEV_COMMIT:-"master"}"
	CLOVER2_DEV_DIR="${SDCARD}/home/pi/clover2-dev"

	clover2_dev_log "fetching clover2-dev workspace @ ${CLOVER2_DEV_COMMIT}"
	clover2_dev_fetch_repo "${CLOVER2_DEV_REPO}" "${CLOVER2_DEV_COMMIT}" "${CLOVER2_DEV_DIR}"

	if ! command -v vcs >/dev/null 2>&1; then
		run_host_command_logged python3 -m pip install --break-system-packages --quiet vcstool
	fi

	clover2_dev_log "importing simulation sources on the host"
	run_host_command_logged vcs import --input "${CLOVER2_DEV_DIR}/repos/simulation.yaml" "${CLOVER2_DEV_DIR}/src"

	local px4_prebuilt_dir="${CLOVER2_DEV_DIR}/src/clover2-sim/px4_sim/prebuilt/px4_sitl_default"
	clover2_dev_log "copying prebuilt PX4 files for ${ARCH}"
	run_host_command_logged mkdir -p "${px4_prebuilt_dir}/bin" "${px4_prebuilt_dir}/etc"
	run_host_command_logged cp -r "${USERPATCHES_PATH}/px4/bin_${ARCH}/." "${px4_prebuilt_dir}/bin/"
	run_host_command_logged cp -r "${USERPATCHES_PATH}/px4/etc/." "${px4_prebuilt_dir}/etc/"

    # FIXME: workaround for prebuilt PX4
    run_host_command_logged rm "${CLOVER2_DEV_DIR}/src/clover2-sim/px4_sim/CMakeLists.txt"
    run_host_command_logged cp "${USERPATCHES_PATH}/px4/CMakeLists.txt" "${CLOVER2_DEV_DIR}/src/clover2-sim/px4_sim/CMakeLists.txt"
}

clover2_dev_fixup_ownership() {
	chroot_sdcard chown -R ${CLOVER2_USER:-pi}:${CLOVER2_USER:-pi} /home/pi/clover2-dev
}

clover2_dev_main() {
	clover2_dev_prepare_workspace
    clover2_rosdep_update_chroot
	clover2_rosdep_install_chroot "/home/pi/clover2-dev/src" "--ignore-src"
	clover2_build_ws_chroot "/home/pi/clover2-dev"
	clover2_dev_fixup_ownership
	clover2_dev_log "done"
}
