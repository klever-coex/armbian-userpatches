# Overrides:
#   CLOVER2_WS_COMMIT: tag or commit
#   CLOVER2_IMPORT_THIRD_PARTY (yes/no): vcs import third_party/clover2.repos
#                                              (needs libcamera in the image:
#                                              camera_ros links against it)
#   CLOVER2_CCACHE (yes/no): ccache-accelerated build

function extension_prepare_config__clover2() {
	display_alert "clover2: the clover2 workspace will be built into the image" "${EXTENSION}" "info"
}

function post_family_tweaks__40_clover2() {
	clover2_main
}

clover2_log() {
	display_alert "clover2: $*" "${EXTENSION}" "info"
}

clover2_fetch_repo() {
	local url="$1" ref="$2" dest="$3"

	if [[ -d "${dest}/.git" ]]; then
		run_host_command_logged git -C "${dest}" fetch --tags origin
	else
		run_host_command_logged git clone "${url}" "${dest}"
	fi

	run_host_command_logged git -C "${dest}" checkout --force "${ref}"
}

clover2_copy_workspace() {
	CLOVER2_WS_REPO="https://github.com/klever-coex/clover2.git"
	CLOVER2_WS_COMMIT="${CLOVER2_WS_COMMIT:-"v0.2.0-rc.1"}"
	CLOVER2_WS_DIR="${SDCARD}/opt/clover2/ws/src/clover2"

	clover2_log "fetching clover2 workspace @ ${CLOVER2_WS_COMMIT}"
	clover2_fetch_repo "${CLOVER2_WS_REPO}" "${CLOVER2_WS_COMMIT}" "${CLOVER2_WS_DIR}"

	if [[ "${CLOVER2_IMPORT_THIRD_PARTY:-"yes"}" == "yes" ]]; then
		if ! command -v vcs >/dev/null 2>&1; then
			run_host_command_logged python3 -m pip install --break-system-packages --quiet vcstool
		fi

		clover2_log "importing third-party packages (vcs)"
		run_host_command_logged vcs import --input "${CLOVER2_WS_DIR}/third_party/clover2.repos" \
			"${SDCARD}/opt/clover2/ws/src"
	fi
}

clover2_install_build_deps() {
	clover2_log "resolving build dependencies with rosdep"
	chroot_sdcard "source /opt/ros/jazzy/setup.bash && env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY rosdep install \
		--from-paths /opt/clover2/ws/src --ignore-src --skip-keys=libcamera -y"
}

clover2_build_workspace() {
	local host_arch

	clover2_log "building workspace natively in chroot (${ARCH})"

	local ccache_args=""
	if [[ "${CLOVER2_CCACHE:-"yes"}" == "yes" ]]; then
		chroot_sdcard_apt_get_install ccache
		mkdir -p "${SRC}/cache/clover2/ccache-${ARCH}" "${SDCARD}/ccache"
		mountpoint -q "${SDCARD}/ccache" || mount --bind "${SRC}/cache/clover2/ccache-${ARCH}" "${SDCARD}/ccache"
		ccache_args="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
		clover2_log "ccache enabled (bind-mounted at /ccache)"
	fi

	chroot_sdcard "source /opt/ros/jazzy/setup.bash && cd /opt/clover2/ws && \
		CCACHE_DIR=/ccache colcon build --symlink-install \
		--cmake-args -DBUILD_TESTING=0 ${ccache_args}"

	if [[ -n "${ccache_args}" ]]; then
		chroot_sdcard ccache --show-stats
		umount "${SDCARD}/ccache"
	fi
}

clover2_install_build_outputs() {
	local user="${CLOVER2_USER:-pi}"
	clover2_log "placing build outputs and user environment"

	run_host_command_logged mkdir -p "${SDCARD}/opt/clover2/map"
	run_host_command_logged cp -r "${SDCARD}/opt/clover2/ws/install/clover2_map/share/clover2_map/map/." \
		"${SDCARD}/opt/clover2/map/"
	run_host_command_logged ln -sfn /opt/clover2/ws/install/clover2/share/clover2/examples \
		"${SDCARD}/home/${user}/examples"

	if [[ -f "${USERPATCHES_PATH}/overlay/home/${user}/.bashrc" ]]; then
		run_host_command_logged cp "${USERPATCHES_PATH}/overlay/home/${user}/.bashrc" \
			"${SDCARD}/home/${user}/.bashrc"
	fi

	local version hash
	version="$(git -C "${CLOVER2_WS_DIR}" describe --tags --always 2>/dev/null || echo unknown)"
	hash="$(git -C "${CLOVER2_WS_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
	run_host_command_logged bash -c "echo CLOVER2_VERSION=${version} >> '${SDCARD}/usr/lib/os-release'"
	run_host_command_logged bash -c "echo CLOVER2_GIT_HASH=${hash} >> '${SDCARD}/usr/lib/os-release'"
}

clover2_fixup_ownership() {
	chroot_sdcard chown -R ${CLOVER2_USER:-pi}:${CLOVER2_USER:-pi} /opt/clover2 /home/${CLOVER2_USER:-pi}
	rm -rf "${SDCARD}"/opt/clover2/ws/src/*/.git
}

clover2_main() {
	clover2_copy_workspace
	clover2_install_build_deps
	clover2_build_workspace
	clover2_install_build_outputs
	clover2_fixup_ownership
	clover2_log "done"
}
