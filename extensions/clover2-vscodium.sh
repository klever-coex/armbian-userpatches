# Overrides:
#   CLOVER2_VSCODIUM_VERSION: vscodium release (default 1.116.02821)
#   CLOVER2_VSCODIUM_EXTENSIONS: space-separated list of name@version
#                                 (default "meta.pyrefly@1.0.0")

function extension_prepare_config__clover2_vscodium() {
	display_alert "clover2-vscodium: VSCodium web server will be installed into the image" "${EXTENSION}" "info"
}

function post_family_tweaks__60_clover2_vscodium() {
	clover2_vscodium_main
}

clover2_vscodium_log() {
	display_alert "clover2-vscodium: $*" "${EXTENSION}" "info"
}

clover2_vscodium_arch_suffix() {
	case "${ARCH}" in
		arm64) echo "linux-arm64" ;;
		amd64) echo "linux-x64" ;;
		*) exit_with_error "clover2-vscodium: unsupported target arch ${ARCH}" ;;
	esac
}

clover2_vscodium_install_server() {
	local suffix ver url tarball
	suffix="$(clover2_vscodium_arch_suffix)"
	ver="${CLOVER2_VSCODIUM_VERSION:-"1.116.02821"}"
	url="https://github.com/VSCodium/vscodium/releases/download/${ver}/vscodium-reh-web-${suffix}-${ver}.tar.gz"

	mkdir -p "${SRC}/cache/clover2/vscodium"
	tarball="${SRC}/cache/clover2/vscodium/reh-web-${ver}-${suffix}.tar.gz"

	if [[ ! -f "${tarball}" ]]; then
		clover2_vscodium_log "downloading vscodium ${ver} (${suffix})"
		run_host_command_logged curl -fL --retry 3 -o "${tarball}" "${url}"
	fi

	clover2_vscodium_log "unpacking vscodium into /opt/vscodium"
	run_host_command_logged mkdir -p "${SDCARD}/opt/vscodium"
	run_host_command_logged tar -xzf "${tarball}" -C "${SDCARD}/opt/vscodium"
}

clover2_vscodium_install_service() {
	local unit="${SDCARD}/etc/systemd/system/codium-server@.service"
	cat > "${unit}" <<'EOS'
[Unit]
Description=VSCodium Remote Server (user: %i)
After=network.target

[Service]
Type=simple
User=%i
ExecStart=/opt/vscodium/bin/codium-server --host 0.0.0.0 --without-connection-token --port 9880
Restart=always

[Install]
WantedBy=multi-user.target
EOS

	chroot_sdcard systemctl enable codium-server@pi.service
}

clover2_vscodium_install_extensions() {
	local suffix="${1}"
	local -a extensions=()
	read -r -a extensions <<< "${CLOVER2_VSCODIUM_EXTENSIONS:-"meta.pyrefly@1.0.0"}"

	local ext name publisher extension version vsix dl_url
	for ext in "${extensions[@]}"; do
		name="${ext%@*}"
		publisher="${name%%.*}"
		extension="${name#*.}"
		version="${ext##*@}"
		vsix="${SRC}/cache/clover2/vscodium/${name}-${version}-${suffix}.vsix"

		if [[ ! -f "${vsix}" ]]; then
			clover2_vscodium_log "downloading extension ${name}@${version} (${suffix})"

			dl_url="$(curl -fsSL --retry 3 "https://open-vsx.org/api/${publisher}/${extension}/${suffix}/${version}" \
				| python3 -c 'import json,sys; print(json.load(sys.stdin)["files"]["download"])' 2>/dev/null || true)"
			[[ -n "${dl_url}" ]] || dl_url="https://open-vsx.org/api/${publisher}/${extension}/${suffix}/${version}/file/${name}-${version}@${suffix}.vsix"

			run_host_command_logged curl -fL --retry 5 --retry-all-errors --retry-delay 5 -o "${vsix}" "${dl_url}"
		fi

		run_host_command_logged cp "${vsix}" "${SDCARD}/tmp/${name}-${version}.vsix"
		chroot_sdcard "runuser -u pi -- env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY \
			TMPDIR=/tmp /opt/vscodium/bin/codium-server --install-extension /tmp/${name}-${version}.vsix"
		run_host_command_logged rm -f "${SDCARD}/tmp/${name}-${version}.vsix"
	done
}

clover2_vscodium_main() {
	declare suffix
	suffix="$(clover2_vscodium_arch_suffix)"

	clover2_vscodium_install_server
	clover2_vscodium_install_service
	clover2_vscodium_install_extensions "${suffix}"
	clover2_vscodium_log "done"
}
