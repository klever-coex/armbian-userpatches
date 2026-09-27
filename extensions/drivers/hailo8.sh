declare -g HAILO8_REPO="https://github.com/hailo-ai/hailort-drivers"
declare -g HAILO8_REF="tag:v4.24.0"
declare -g HAILO8_VERSION="${HAILO8_REF#tag:v}"
declare -g HAILO8_USERSPACE_DIR="${USERPATCHES_PATH}/hailo"

function extension_prepare_config__hailo8() {
	display_alert "hailo8: Hailo-8 PCIe driver (in-tree) + hailort ${HAILO8_VERSION} userspace" "${EXTENSION}" "info"
}

function post_family_config__hailo8_fetch() {
	declare -g HAILO8_SRC_DIR="${SRC}/cache/sources/hailort-drivers/${HAILO8_REF#*:}"

	[[ "${CONFIG_DEFS_ONLY}" == "yes" ]] && return 0

	fetch_from_repo "${HAILO8_REPO}" "hailort-drivers" "${HAILO8_REF}" "yes"
}

function custom_kernel_config__hailo8_modules() {
	kernel_config_modifying_hashes+=("hailo8_driver=${HAILO8_REF}")
	kernel_config_modifying_hashes+=("hailo8_logic=$(declare -f custom_kernel_config__hailo8_modules | sha256sum | cut -d' ' -f1)")

	[[ ! -f .config ]] && return 0

	# shellcheck disable=SC2154 # provided by the kernel build
	declare hailo_dir="${kernel_work_dir}/drivers/misc/hailo"
	declare misc_kconfig="${kernel_work_dir}/drivers/misc/Kconfig"
	declare misc_makefile="${kernel_work_dir}/drivers/misc/Makefile"

	display_alert "hailo8" "adding driver ${HAILO8_VERSION} to kernel tree" "info"

	run_host_command_logged rm -rf "${hailo_dir}"
	run_host_command_logged mkdir -p "${hailo_dir}"
	run_host_command_logged cp -a "${HAILO8_SRC_DIR}/common" "${hailo_dir}/common"
	run_host_command_logged cp -a "${HAILO8_SRC_DIR}/linux" "${hailo_dir}/linux"

	sed -i -E 's/^([[:space:]]*ccflags-y[[:space:]]*\+=)[[:space:]]*-Werror[[:space:]]*$/\1/' \
		"${hailo_dir}/linux/pcie/Kbuild"
	grep -q -- "-Werror" "${hailo_dir}/linux/pcie/Kbuild" &&
		exit_with_error "hailo8: failed to strip -Werror from the vendored Kbuild"

	cat > "${hailo_dir}/Kconfig" <<- 'EOF'
	config HAILO_PCI
		bool "Hailo-8 PCIe AI accelerator driver"
		depends on PCI
		help
		  Support for Hailo-8 AI accelerators attached over PCIe, built
		  from the vendored hailort-drivers sources (hailo_pci module).

		  This is a bool on purpose: the vendored Kbuild always builds
		  hailo_pci as a module; the option only gates whether kbuild
		  descends into the driver directory.
	EOF
	cat > "${hailo_dir}/Makefile" <<- 'EOF'
		obj-$(CONFIG_HAILO_PCI) += linux/pcie/
	EOF

	if ! grep -q "drivers/misc/hailo/Kconfig" "${misc_kconfig}"; then
		sed -i 's|^endmenu|source "drivers/misc/hailo/Kconfig"\n&|' "${misc_kconfig}"
	fi
	if ! grep -q "drivers/misc/hailo/" "${misc_makefile}"; then
		echo 'obj-$(CONFIG_HAILO_PCI) += hailo/' >> "${misc_makefile}"
	fi

	kernel_config_set_y CONFIG_HAILO_PCI
}

function post_family_tweaks__hailo8_userspace() {
	[[ "${ARCH}" != "arm64" ]] && return 0

	declare hailort_deb="${HAILO8_USERSPACE_DIR}/hailort_${HAILO8_VERSION}_arm64.deb"
	declare hailort_whl="${HAILO8_USERSPACE_DIR}/hailort-${HAILO8_VERSION}-cp312-cp312-linux_aarch64.whl"
	[[ -f "${hailort_deb}" ]] || exit_with_error "hailo8: hailort deb not found" "${hailort_deb}"
	[[ -f "${hailort_whl}" ]] || exit_with_error "hailo8: hailort wheel not found" "${hailort_whl}"

	display_alert "hailo8" "installing hailort ${HAILO8_VERSION} userspace" "info"

	run_host_command_logged install -D -m 0644 \
		"${HAILO8_SRC_DIR}/linux/pcie/51-hailo-udev.rules" \
		"${SDCARD}/etc/udev/rules.d/51-hailo-udev.rules"

	run_host_command_logged cp "${hailort_deb}" "${SDCARD}/root/hailort.deb"
	chroot_sdcard_apt_get install /root/hailort.deb
	run_host_command_logged rm -f "${SDCARD}/root/hailort.deb"

	declare hailort_whl_name
	hailort_whl_name="$(basename "${hailort_whl}")"
	run_host_command_logged cp "${hailort_whl}" "${SDCARD}/root/${hailort_whl_name}"
	chroot_sdcard_apt_get_install python3-pip
	chroot_sdcard pip3 install --break-system-packages "/root/${hailort_whl_name}"
	run_host_command_logged rm -f "${SDCARD}/root/${hailort_whl_name}"
}
