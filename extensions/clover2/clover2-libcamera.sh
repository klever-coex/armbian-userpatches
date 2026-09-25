# Overrides:
#   CLOVER2_LIBCAMERA_REF: git tag or commit (default: v0.7.1+rpt20260429)

function extension_prepare_config__clover2_libcamera() {
	display_alert "clover2-libcamera: libcamera will be built as a deb into the image" "${EXTENSION}" "info"
}

function post_family_tweaks__20_clover2_libcamera() {
	clover2_libcamera_main
}

clover2_libcamera_log() {
	display_alert "clover2-libcamera: $*" "${EXTENSION}" "info"
}

clover2_libcamera_fetch_repo() {
	local url="$1" ref="$2" dest="$3"
	if [[ -d "${dest}/.git" ]]; then
		run_host_command_logged git -C "${dest}" fetch --tags origin
	else
		run_host_command_logged git clone "${url}" "${dest}"
	fi
	run_host_command_logged git -C "${dest}" checkout --force "${ref}"
}

clover2_libcamera_resolve_sources() {
	CLOVER2_LIBCAMERA_REPO="${CLOVER2_LIBCAMERA_REPO:-"https://github.com/raspberrypi/libcamera.git"}"
	CLOVER2_LIBCAMERA_REF="${CLOVER2_LIBCAMERA_REF:-"v0.7.1+rpt20260429"}"
	CLOVER2_LIBPISP_REF="${CLOVER2_LIBPISP_REF:-"v1.3.0"}"
	CLOVER2_LIBYUV_REF="${CLOVER2_LIBYUV_REF:-"500f45652c459cfccd20f83f297eb66cb7b015cb"}"
	CLOVER2_LIBCAMERA_SRC="${SRC}/cache/clover2/libcamera"
	CLOVER2_LIBCAMERA_DEB_DIR="${SRC}/cache/clover2/debs"
	CLOVER2_LIBCAMERA_DEBIAN_OVERLAY="${USERPATCHES_PATH}/libcamera-debian"

	mkdir -p "${CLOVER2_LIBCAMERA_DEB_DIR}"

	clover2_libcamera_log "fetching libcamera @ ${CLOVER2_LIBCAMERA_REF}"
	clover2_libcamera_fetch_repo "${CLOVER2_LIBCAMERA_REPO}" "${CLOVER2_LIBCAMERA_REF}" "${CLOVER2_LIBCAMERA_SRC}"
}

clover2_libcamera_expected_stamp() {
	(echo "${CLOVER2_LIBCAMERA_REF}"; echo "${CLOVER2_LIBPISP_REF}"; echo "${CLOVER2_LIBYUV_REF}"; \
		find "${CLOVER2_LIBCAMERA_DEBIAN_OVERLAY}" -type f -exec cat {} +) \
		| sha256sum | cut -d' ' -f1
}

clover2_libcamera_cached_deb() {
	local stamp expected
	stamp="${CLOVER2_LIBCAMERA_DEB_DIR}/libcamera.stamp"
	expected="$(clover2_libcamera_expected_stamp)"

	if [[ -f "${stamp}" && "$(cat "${stamp}")" == "${expected}" ]]; then
		echo "$(ls -1 "${CLOVER2_LIBCAMERA_DEB_DIR}"/libcamera_*"_${ARCH}.deb" 2>/dev/null | head -1)"
		return 0
	fi
	return 1
}

clover2_libcamera_build() {
	local arch
	arch="${ARCH}"

	clover2_libcamera_log "installing build dependencies in the chroot"
	chroot_sdcard_apt_get_install \
		build-essential debhelper meson ninja-build pkg-config cmake clang \
		libdrm-dev libdw-dev libevent-dev libexif-dev libgstreamer1.0-dev \
		libgstreamer-plugins-base1.0-dev libgtest-dev libjpeg-dev \
		liblttng-ust-dev libpython3-dev libssl-dev libtiff-dev libudev-dev \
		libunwind-dev libyaml-dev libyuv-dev libcrypto++-dev lttng-tools \
		nlohmann-json3-dev \
		pybind11-dev python3-jinja2 python3-ply python3-yaml

	clover2_libcamera_log "staging sources into the rootfs"
	run_host_command_logged mkdir -p "${SDCARD}/opt/build/libcamera"
	run_host_command_logged rsync -a --delete --exclude '.git/' \
		"${CLOVER2_LIBCAMERA_SRC}/" "${SDCARD}/opt/build/libcamera/"

	run_host_command_logged rm -rf "${SDCARD}/opt/build/libcamera/debian"
	run_host_command_logged cp -r "${CLOVER2_LIBCAMERA_DEBIAN_OVERLAY}" "${SDCARD}/opt/build/libcamera/debian"

	clover2_libcamera_log "staging libpisp subproject @ ${CLOVER2_LIBPISP_REF}"
	clover2_libcamera_fetch_repo "https://github.com/raspberrypi/libpisp.git" \
		"${CLOVER2_LIBPISP_REF}" "${SRC}/cache/clover2/libpisp"
	run_host_command_logged mkdir -p "${SDCARD}/opt/build/libcamera/subprojects/libpisp"
	run_host_command_logged rsync -a --delete --exclude '.git/' \
		"${SRC}/cache/clover2/libpisp/" "${SDCARD}/opt/build/libcamera/subprojects/libpisp/"

	clover2_libcamera_log "staging libyuv subproject @ ${CLOVER2_LIBYUV_REF:0:12}"
	clover2_libcamera_fetch_repo "https://chromium.googlesource.com/libyuv/libyuv.git" \
		"${CLOVER2_LIBYUV_REF}" "${SRC}/cache/clover2/libyuv"
	run_host_command_logged git -C "${SRC}/cache/clover2/libyuv" apply --check \
		"${CLOVER2_LIBCAMERA_SRC}/subprojects/packagefiles/libyuv/0004-CMakeLists.txt-Do-not-enable-NEON-for-armel-armhf.patch" \
		&& run_host_command_logged git -C "${SRC}/cache/clover2/libyuv" apply \
		"${CLOVER2_LIBCAMERA_SRC}/subprojects/packagefiles/libyuv/0004-CMakeLists.txt-Do-not-enable-NEON-for-armel-armhf.patch" || true
	run_host_command_logged mkdir -p "${SDCARD}/opt/build/libcamera/subprojects/libyuv"
	run_host_command_logged rsync -a --delete --exclude '.git/' \
		"${SRC}/cache/clover2/libyuv/" "${SDCARD}/opt/build/libcamera/subprojects/libyuv/"

	local host_arch
	host_arch="$(dpkg --print-architecture)"
	if [[ "${ARCH}" != "${host_arch}" ]]; then
		display_alert "clover2-libcamera: building under qemu emulation (slow, once — deb is cached)" "${EXTENSION}" "wrn"
	fi

	clover2_libcamera_log "dpkg-buildpackage (this takes a while)"
	chroot_sdcard "cd /opt/build/libcamera && dpkg-buildpackage -us -uc -b -j\$(nproc)"

	local built deb_name
	built="$(ls -1 "${SDCARD}/opt/build/libcamera_"*"_${arch}.deb" 2>/dev/null | head -1)"
	[[ -n "${built}" ]] || exit_with_error "libcamera deb was not produced"

	deb_name="libcamera_0.7.1+rpt_${ARCH}.deb"
	run_host_command_logged mv "${built}" "${CLOVER2_LIBCAMERA_DEB_DIR}/${deb_name}"
	echo "$(clover2_libcamera_expected_stamp)" > "${CLOVER2_LIBCAMERA_DEB_DIR}/libcamera.stamp"

	run_host_command_logged rm -rf "${SDCARD}/opt/build"
}

clover2_libcamera_expected_stamp() {
	(echo "${CLOVER2_LIBCAMERA_REF}"; echo "${CLOVER2_LIBPISP_REF}"; echo "${CLOVER2_LIBYUV_REF}"; \
		find "${CLOVER2_LIBCAMERA_DEBIAN_OVERLAY}" -type f -exec cat {} +) \
		| sha256sum | cut -d' ' -f1
}

clover2_libcamera_install_deb() {
	local deb="$1"
	run_host_command_logged cp "${deb}" "${SDCARD}/root/libcamera.deb"
	chroot_sdcard_apt_get install /root/libcamera.deb
	run_host_command_logged rm -f "${SDCARD}/root/libcamera.deb"
	clover2_libcamera_log "libcamera installed into the rootfs"
}

clover2_libcamera_main() {
	local deb
	clover2_libcamera_resolve_sources

	if deb="$(clover2_libcamera_cached_deb)"; then
		clover2_libcamera_log "using cached ${deb}"
	else
		clover2_libcamera_build
		deb="$(ls -1 "${CLOVER2_LIBCAMERA_DEB_DIR}"/libcamera_*"_${ARCH}.deb" | head -1)"
	fi

	clover2_libcamera_install_deb "${deb}"
	clover2_libcamera_log "done"
}
