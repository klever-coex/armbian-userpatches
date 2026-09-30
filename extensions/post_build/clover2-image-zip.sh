# Overrides:
#   CLOVER2_IMAGE_ZIP (yes/no): (default: yes)
#   CLOVER2_IMAGE_ZIP_LEVEL: comptress level from 0 to 9 (default: 9)

function extension_prepare_config__clover2_image_zip() {
	display_alert "clover2-image-zip: final image will be packed into a .zip" "${EXTENSION}" "info"
}

function post_build_image__990_clover2_image_zip() {
	[[ "${CLOVER2_IMAGE_ZIP:-"yes"}" == "yes" ]] || return 0

	local img="${FINAL_IMAGE_FILE}"
	[[ -f "${img}" ]] || exit_with_error "image not found: ${img}"

	command -v zip >/dev/null 2>&1 || {
		run_host_command_logged apt-get -q update
		run_host_command_logged apt-get -q -y install --no-install-recommends zip
	}

	local level="${CLOVER2_IMAGE_ZIP_LEVEL:-9}"
	local dir basename
	dir="$(dirname "${img}")"
	basename="$(basename "${img}")"

	display_alert "clover2-image-zip: zipping (level ${level})" "${basename}" "info"
	(cd "${dir}" && zip -q -"${level}" "${basename}.zip" "${basename}")

	(cd "${dir}" && sha256sum "${basename}.zip" > "${basename}.zip.sha")

	local img_mb zip_mb
	img_mb=$(($(stat -c %s "${img}") / 1048576))
	zip_mb=$(($(stat -c %s "${img}.zip") / 1048576))
	display_alert "clover2-image-zip: done" "${img_mb} MiB -> ${zip_mb} MiB" "info"
}
