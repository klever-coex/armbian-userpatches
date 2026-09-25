# Overrides:
#   CLOVER2_CCACHE (yes/no): ccache-accelerated build
#   CLOVER2_WS_SEQUENTIAL_BUILD (yes/no): run colcon with sequential arg

clover2_ws_log() {
	display_alert "clover2-ws: $*" "${EXTENSION}" "info"
}

clover2_rosdep_update_chroot() {
	clover2_ws_log "updating rosdep database in chroot"
	chroot_sdcard "source /opt/ros/jazzy/setup.bash && env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY rosdep update"
}

clover2_rosdep_install_chroot() {
    local from_paths="$1"
    clover2_ws_log "resolving build dependencies with rosdep"
    chroot_sdcard "source /opt/ros/jazzy/setup.bash && env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
        rosdep install -y --from-paths $from_paths $@"
}

clover2_build_ws_chroot() {
    local ws_dir="$1"
	clover2_ws_log "building workspace natively in chroot (${ARCH})"

	local ccache_args=""
	if [[ "${CLOVER2_CCACHE:-"yes"}" == "yes" ]]; then
		chroot_sdcard_apt_get_install ccache
		mkdir -p "${SRC}/cache/clover2/ccache-${ARCH}" "${SDCARD}/ccache"
		mountpoint -q "${SDCARD}/ccache" || mount --bind "${SRC}/cache/clover2/ccache-${ARCH}" "${SDCARD}/ccache"
		ccache_args="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
		clover2_ws_log "ccache enabled (bind-mounted at /ccache)"
	fi

	local extra_args=""
	if [[ "${CLOVER2_WS_SEQUENTIAL_BUILD:-"yes"}" == "yes" ]]; then
		extra_args="--executor sequential"
	fi

	chroot_sdcard "source /opt/ros/jazzy/setup.bash && cd ${ws_dir} && \
		CCACHE_DIR=/ccache colcon build --symlink-install ${extra_args} \
		--cmake-args -DBUILD_TESTING=0 ${ccache_args}"

	if [[ -n "${ccache_args}" ]]; then
		chroot_sdcard ccache --show-stats
		umount "${SDCARD}/ccache"
	fi
}