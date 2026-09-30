# Overrides:
#   CLOVER2_COMMIT: tag or commit
#   CLOVER2_IMPORT_THIRD_PARTY (yes/no): vcs import third_party/clover2.repos
#                                              (needs libcamera in the image:
#                                              camera_ros links against it)

enable_extension "clover2-ws"

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
	[[ -n "${CLOVER2_COMMIT}" ]] ||
		exit_with_error "CLOVER2_COMMIT is not set (expected in _config-clover2-common.conf)"
	CLOVER2_WS_REPO="https://github.com/klever-coex/clover2.git"
	CLOVER2_WS_DIR="${SDCARD}/opt/clover2/ws/src/clover2"

	clover2_log "fetching clover2 workspace @ ${CLOVER2_COMMIT}"
	clover2_fetch_repo "${CLOVER2_WS_REPO}" "${CLOVER2_COMMIT}" "${CLOVER2_WS_DIR}"

	if [[ "${CLOVER2_IMPORT_THIRD_PARTY:-"yes"}" == "yes" ]]; then
		if ! command -v vcs >/dev/null 2>&1; then
			run_host_command_logged python3 -m pip install --break-system-packages --quiet vcstool
		fi

		clover2_log "importing third-party packages (vcs)"
		run_host_command_logged vcs import --input "${CLOVER2_WS_DIR}/third_party/clover2.repos" \
			"${SDCARD}/opt/clover2/ws/src"
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

	cat > "${SDCARD}/etc/clover2-release" <<EOF
CLOVER2_VERSION=${CLOVER2_VERSION}
CLOVER2_GIT_HASH=${CLOVER2_GIT_HASH}
EOF
}

clover2_fixup_ownership() {
	chroot_sdcard chown -R ${CLOVER2_USER:-pi}:${CLOVER2_USER:-pi} /opt/clover2 /home/${CLOVER2_USER:-pi}
}

clover2_install_ros_deps() {
	clover2_rosdep_install_chroot "/opt/clover2/ws/src" "--ignore-src --skip-keys=libcamera"
}

clover2_build() {
	clover2_build_ws_chroot "/opt/clover2/ws"
}

clover2_resolve_version() {
	clover2_ansible_ensure

	if version="$(cd "${CLOVER2_WS_DIR}" && clover2 version compose --field version)" 		&& hash="$(cd "${CLOVER2_WS_DIR}" && clover2 version compose --field git_hash)"; then
		:
	else
		display_alert "clover2: clover2-cli version compose failed, falling back to git describe" "${EXTENSION}" "wrn"
		version="$(git -C "${CLOVER2_WS_DIR}" describe --tags --always 2>/dev/null || echo unknown)"
		hash="$(git -C "${CLOVER2_WS_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
	fi
	CLOVER2_VERSION="${version}"
	CLOVER2_GIT_HASH="${hash}"
	clover2_log "clover2 version: ${CLOVER2_VERSION} (${CLOVER2_GIT_HASH})"
}

clover2_main() {
	clover2_copy_workspace
	clover2_resolve_version
	clover2_install_ros_deps
	clover2_build
	clover2_install_build_outputs
	clover2_fixup_ownership
	clover2_log "done"
}
