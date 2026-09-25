# shellcheck shell=bash
#
# clover2-hailo - Hailo AI accelerator support (HailoRT runtime + PCIe driver
# + Python bindings), for the klever5 profile.
#
# Installs the official 4.24.0 artifacts kept in userpatches/hailo/:
#   hailort_4.24.0_arm64.deb            - runtime libs, CLI tools, gstreamer plugin
#   hailort-pcie-driver_4.24.0_all.deb  - firmware + driver sources
#   hailort-*.whl                       - python bindings for the system cpython
#
# The pcie-driver deb is unpacked WITHOUT its postinst: it runs
# `dkms build` for `uname -r`, which inside the build chroot is the host
# kernel, not the image one. We generate the dkms tree and build for the
# image kernel (headers come from INSTALL_HEADERS=yes) ourselves.
#
# arm64-only: the artifacts are aarch64; on other ARCH the extension no-ops.
#
# Overrides:
#   CLOVER2_HAILO_VERSION - driver version, must match the debs (4.24.0)

CLOVER2_HAILO_VERSION="${CLOVER2_HAILO_VERSION:-4.24.0}"

function extension_prepare_config__clover2_hailo() {
	[[ "${ARCH}" == "arm64" ]] || { display_alert "clover2-hailo: skipped, arm64 only" "${EXTENSION}" "wrn"; return 0; }
	display_alert "clover2-hailo: HailoRT ${CLOVER2_HAILO_VERSION} will be installed" "${EXTENSION}" "info"
	[[ "${INSTALL_HEADERS}" == "yes" ]] || exit_with_error "clover2-hailo requires INSTALL_HEADERS=yes (DKMS driver build)"
}

clover2_hailo_log() {
	display_alert "clover2-hailo: $*" "${EXTENSION}" "info"
}

clover2_hailo_install_runtime() {
	local src="${USERPATCHES_PATH}/hailo"
	run_host_command_logged cp "${src}/hailort_${CLOVER2_HAILO_VERSION}_arm64.deb" "${SDCARD}/root/"
	chroot_sdcard_apt_get install "/root/hailort_${CLOVER2_HAILO_VERSION}_arm64.deb"
	run_host_command_logged rm -f "${SDCARD}/root/hailort_${CLOVER2_HAILO_VERSION}_arm64.deb"
}

clover2_hailo_install_pcie_driver() {
	local src="${USERPATCHES_PATH}/hailo" deb="/root/hailort-pcie-driver_${CLOVER2_HAILO_VERSION}_all.deb"
	local dkms_src="${SDCARD}/usr/src/hailort-pcie-driver-${CLOVER2_HAILO_VERSION}"
	local kernel
	kernel="$(ls "${SDCARD}/lib/modules" 2>/dev/null | head -1)"
	[[ -d "${SDCARD}/lib/modules/${kernel}/build" ]] ||
		exit_with_error "kernel headers for ${kernel} not found - INSTALL_HEADERS=yes?"

	run_host_command_logged cp "${src}/hailort-pcie-driver_${CLOVER2_HAILO_VERSION}_all.deb" "${SDCARD}${deb}"
	chroot_sdcard dpkg --unpack "${deb}" # no maintainer scripts on unpack

	# neutralize the postinst: it builds for uname -r (the HOST kernel here)
	echo -e "#!/bin/sh\nexit 0" > "${SDCARD}/var/lib/dpkg/info/hailort-pcie-driver.postinst"
	chroot_sdcard dpkg --configure hailort-pcie-driver

	# what the postinst would have done: firmware symlink
	chroot_sdcard "ln -sf /lib/firmware/hailo/hailo8_fw.${CLOVER2_HAILO_VERSION}.bin /lib/firmware/hailo/hailo8_fw.bin"

	# assemble the dkms tree (normally done by `make install_dkms`, which
	# also runs a bare `dkms build` for the wrong kernel)
	run_host_command_logged mkdir -p "${dkms_src}"
	run_host_command_logged cp -r "${SDCARD}/usr/src/hailort-pcie-driver/common" "${dkms_src}/common"
	run_host_command_logged cp -r "${SDCARD}/usr/src/hailort-pcie-driver/hailort" "${dkms_src}/hailort"
	run_host_command_logged sed "s/@PCIE_DRIVER_VERSION@/${CLOVER2_HAILO_VERSION}/" \
		"${SDCARD}/usr/src/hailort-pcie-driver/hailort/drivers/linux/pcie/dkms.conf.in" \
		> "${dkms_src}/dkms.conf"

	chroot_sdcard "dkms add -m hailo_pci -v ${CLOVER2_HAILO_VERSION} && \
		dkms build -m hailo_pci -v ${CLOVER2_HAILO_VERSION} -k ${kernel} && \
		dkms install -m hailo_pci -v ${CLOVER2_HAILO_VERSION} -k ${kernel} --force"

	run_host_command_logged rm -f "${SDCARD}${deb}"
	clover2_hailo_log "hailo_pci ${CLOVER2_HAILO_VERSION} built for ${kernel}"
}

clover2_hailo_install_python_bindings() {
	local src="${USERPATCHES_PATH}/hailo" whl
	whl="$(ls "${src}"/*.whl 2>/dev/null | head -1)"
	[[ -n "${whl}" ]] || { clover2_hailo_log "no python wheel found, skipping pyhailort"; return 0; }

	chroot_sdcard_apt_get_install python3-pip
	run_host_command_logged cp "${whl}" "${SDCARD}/root/"
	chroot_sdcard "env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
		python3 -m pip install --no-deps --break-system-packages /root/$(basename "${whl}")"
	run_host_command_logged rm -f "${SDCARD}/root/$(basename "${whl}")"
}

function post_family_tweaks__22_clover2_hailo() {
	[[ "${ARCH}" == "arm64" ]] || return 0

	local src="${USERPATCHES_PATH}/hailo"
	[[ -d "${src}" ]] || exit_with_error "hailo artifacts not found: ${src}"

	chroot_sdcard_apt_get_install dkms
	clover2_hailo_install_runtime
	clover2_hailo_install_pcie_driver
	clover2_hailo_install_python_bindings
	# the hailo_pci module lands in /lib/modules/<kernel>/updates/dkms and
	# loads via PCI modalias on the real board; hailort.service ships
	# disabled-safe from the deb
	clover2_hailo_log "installed HailoRT stack"
}
