# Pin the kernel Git reference after the board family configuration has been
# sourced. Some families, including bcm2711, unconditionally replace an early
# KERNELBRANCH value from the user configuration.
#
# Required configuration:
#   PINNED_KERNELBRANCH="tag:v6.18.52"

function late_family_config__kernel_branch_pin() {
	if [[ -z "${PINNED_KERNELBRANCH:-}" ]]; then
		exit_with_error "kernel-branch-pin requires PINNED_KERNELBRANCH"
	fi

	display_alert "Pinning kernel branch" "${KERNELBRANCH:-<unset>} -> ${PINNED_KERNELBRANCH}" "info"
	declare -g KERNELBRANCH="${PINNED_KERNELBRANCH}"
}
