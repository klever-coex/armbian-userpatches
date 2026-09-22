# Overrides:
#   CLOVER2_DEV_COMMIT: ansible collection source, pinned

clover2_ansible_fetch_repo() {
	local url="$1" ref="$2" dest="$3"
	if [[ -d "${dest}/.git" ]]; then
		run_host_command_logged git -C "${dest}" fetch --tags origin
	else
		run_host_command_logged git clone "${url}" "${dest}"
	fi

	run_host_command_logged git -C "${dest}" checkout --force "${ref}"
}

clover2_ansible_ensure() {
	[[ "${CLOVER2_ANSIBLE_READY:-"no"}" == "yes" ]] && return 0

	CLOVER2_DEV_REPO="https://github.com/klever-coex/clover2-dev.git"
	CLOVER2_DEV_COMMIT="${CLOVER2_DEV_COMMIT:-"a958ddafd1b1279012c9e0f3bacd6ec324250cc6"}"
	CLOVER2_ANSIBLE_VERSION="10.7.0"
	CLOVER2_ANSIBLE_BIN_DIR="${CLOVER2_ANSIBLE_BIN_DIR:-"/root/.local/bin"}"
	CLOVER2_DEV_DIR="${SRC}/cache/clover2/clover2-dev"
	CLOVER2_COLLECTIONS_PATH="${SRC}/cache/clover2/collections"

	display_alert "clover2-ansible: init (clover2-dev @ ${CLOVER2_DEV_COMMIT:0:12}, ansible ${CLOVER2_ANSIBLE_VERSION})" "clover2-ansible" "info"

	clover2_ansible_fetch_repo "${CLOVER2_DEV_REPO}" "${CLOVER2_DEV_COMMIT}" "${CLOVER2_DEV_DIR}"

	run_host_command_logged apt-get -q update
	run_host_command_logged apt-get -q -y install --no-install-recommends curl python3-pip rsync

	if ! command -v "${CLOVER2_ANSIBLE_BIN_DIR}/uv" >/dev/null 2>&1; then
		run_host_command_logged curl -fsSL -o /tmp/clover2-uv-install.sh https://astral.sh/uv/install.sh
		run_host_command_logged bash /tmp/clover2-uv-install.sh
	fi

	if ! "${CLOVER2_ANSIBLE_BIN_DIR}/ansible-playbook" --version >/dev/null 2>&1; then
		run_host_command_logged "${CLOVER2_ANSIBLE_BIN_DIR}/uv" tool install \
			--python-preference only-system \
			--with-executables-from "ansible-core" \
			"ansible==${CLOVER2_ANSIBLE_VERSION}"
	fi

	export PATH="${CLOVER2_ANSIBLE_BIN_DIR}:${PATH}"

	mkdir -p "${CLOVER2_COLLECTIONS_PATH}"
	run_host_command_logged "${CLOVER2_ANSIBLE_BIN_DIR}/ansible-galaxy" collection build \
		"${CLOVER2_DEV_DIR}/ansible" --output-path "${SRC}/cache/clover2" --force

	local tarball
	tarball="$(ls -1 "${SRC}/cache/clover2"/clover2-dev-*.tar.gz | head -1)"
	[[ -n "${tarball}" ]] || exit_with_error "clover2.dev collection tarball not produced"
	run_host_command_logged "${CLOVER2_ANSIBLE_BIN_DIR}/ansible-galaxy" collection install \
		"${tarball}" -p "${CLOVER2_COLLECTIONS_PATH}" --force

	CLOVER2_ANSIBLE_READY="yes"
}

# clover2_ansible_playbook_chroot <playbook> [extra ansible-playbook args...]
clover2_ansible_playbook_chroot() {
	local playbook="$1"
	shift
	clover2_ansible_ensure

	chroot_sdcard_apt_get_install python3 python3-apt sudo

	display_alert "clover2-ansible: playbook ${playbook} (chroot)" "clover2-ansible" "info"
	ANSIBLE_COLLECTIONS_PATH="${CLOVER2_COLLECTIONS_PATH}" ANSIBLE_RETRY_FILES_ENABLED=0 TMPDIR="/tmp" \
		run_host_command_logged env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
		"${CLOVER2_ANSIBLE_BIN_DIR}/ansible-playbook" "${playbook}" \
		-i "${SDCARD}," -c chroot \
		-e ansible_python_interpreter=/usr/bin/python3 \
		-e target=all "$@"
}
