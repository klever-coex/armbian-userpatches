# Overrides:
#   CLOVER2_COMPOSE_PROFILES - compose profiles (default robot)
#   CLOVER2_FRONTEND_PORT    - frontend host port (default 80)

enable_extension "docker-ce"

declare -g -A CLOVER2_DOCKER_IMAGES_WANTED=() # image ref -> requesting extension

function extension_prepare_config__clover2_docker() {
	display_alert "clover2-docker: docker-ce + compose v2 + registry images will be installed" "${EXTENSION}" "info"
}

function post_family_tweaks__50_clover2_docker() {
	clover2_docker_main
}

clover2_docker_log() {
	display_alert "clover2-docker: $*" "${EXTENSION}" "info"
}

clover2_docker_want_image() {
	CLOVER2_DOCKER_IMAGES_WANTED["$1"]="${EXTENSION:-manual}"
}

clover2_docker_setup_user() {
	chroot_sdcard "usermod -aG docker ${CLOVER2_USER:-pi}"
}

clover2_docker_install_compose_file() {
	local compose_src="${SDCARD}/opt/clover2/ws/src/clover2/docker/compose.yaml"
	[[ -f "${compose_src}" ]] || exit_with_error "docker/compose.yaml not found - run after the clover2 extension"

	local tag
	tag="$(grep -oP 'CLOVER2_GIT_HASH=\K.*' "${SDCARD}/etc/clover2-release" 2>/dev/null || true)"
	[[ -n "${tag}" && "${tag}" != "unknown" ]] ||
		exit_with_error "CLOVER2_GIT_HASH not found in os-release - is clover2-docker ordered after the clover2 extension?"
	tag="${tag:0:7}" # clover2 CI tags images with the short commit hash

	clover2_docker_log "installing docker-compose.yaml + .env (TAG=${tag}, profiles=${CLOVER2_COMPOSE_PROFILES:-robot})"
	run_host_command_logged cp "${compose_src}" "${SDCARD}/opt/clover2/docker-compose.yaml"

	cat > "${SDCARD}/opt/clover2/.env" <<EOF
TAG=${tag}
COMPOSE_PROFILES=${CLOVER2_COMPOSE_PROFILES:-robot}
FRONTEND_PORT=${CLOVER2_FRONTEND_PORT:-80}
EOF

	CLOVER2_DOCKER_TAG="${tag}" # for the clover2_docker_images__* declarators
}

clover2_docker_download_images() {
	local fn ref
	for fn in $(compgen -A function | grep '^clover2_docker_images__' | sort); do
		"${fn}"
	done
	for ref in "${!CLOVER2_DOCKER_IMAGES_WANTED[@]}"; do
		clover2_docker_log "pulling ${ref} (${ARCH}, requested by ${CLOVER2_DOCKER_IMAGES_WANTED[${ref}]})"
		clover2_docker_pull "${ref}"
	done
}

clover2_docker_pull() {
	local ref="$1" name
	name="$(basename "${ref%%:*}")"

	command -v skopeo >/dev/null 2>&1 || {
		run_host_command_logged apt-get -q update
		run_host_command_logged apt-get -q -y install --no-install-recommends skopeo ca-certificates
	}

	run_host_command_logged skopeo copy --retry-times 5 \
		--override-os linux --override-arch "${ARCH}" \
		"docker://${ref}" "docker-archive:${SDCARD}/root/${name}.tar:${ref}"
}

clover2_docker_main() {
	clover2_docker_setup_user
	clover2_docker_install_compose_file
	clover2_docker_download_images
	clover2_docker_log "done"
}
