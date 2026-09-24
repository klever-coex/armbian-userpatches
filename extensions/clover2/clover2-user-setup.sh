# Overrides:
#   CLOVER2_USER: user name (default pi)
#   CLOVER2_USER_PASSWORD: plain password (default raspberry)
#   CLOVER2_USER_GROUPS: supplementary groups (comma-separated)

function extension_prepare_config__clover2_user_setup() {
	display_alert "clover2-user-setup: user '${CLOVER2_USER:-"pi"}' will be created in the image" "${EXTENSION}" "info"
}

function post_family_tweaks__10_clover2_user_setup() {
	clover2_user_setup_main
}

function clover2_user_setup_create_user() {
	CLOVER2_USER="${CLOVER2_USER:-"pi"}"
	CLOVER2_USER_PASSWORD="${CLOVER2_USER_PASSWORD:-"raspberry"}"
	CLOVER2_USER_GROUPS="${CLOVER2_USER_GROUPS:-"sudo,adm,dialout,cdrom,plugdev,video,audio,netdev,render"}"

	display_alert "clover2-user-setup: creating user ${CLOVER2_USER}" "${EXTENSION}" "info"
	chroot_sdcard "id -u ${CLOVER2_USER} &>/dev/null || useradd -m -s /bin/zsh \
		-G ${CLOVER2_USER_GROUPS} ${CLOVER2_USER}"
	chroot_sdcard "echo '${CLOVER2_USER}:${CLOVER2_USER_PASSWORD}' | chpasswd"

	echo "${CLOVER2_USER} ALL=(ALL) NOPASSWD:ALL" > "${SDCARD}/etc/sudoers.d/01-nopasswd"
	run_host_command_logged chmod 440 "${SDCARD}/etc/sudoers.d/01-nopasswd"

	chroot_sdcard "visudo -cf /etc/sudoers.d/01-nopasswd"
}

clover2_user_setup_zsh() {
	[[ -x "${SDCARD}/bin/zsh" ]] || exit_with_error "zsh not in the rootfs - armbian-zsh missing (BUILD_MINIMAL=yes?)"

	display_alert "clover2-user-setup: writing .zshrc for ${CLOVER2_USER}" "${EXTENSION}" "info"
	cat > "${SDCARD}/home/${CLOVER2_USER}/.zshrc" <<'EOF'
export ZSH="/etc/oh-my-zsh"
ZSH_THEME="gentoo"
ZSH_CACHE_DIR="$HOME/.oh-my-zsh/cache"
DISABLE_AUTO_UPDATE="true"
plugins=(evalcache git git-extras debian tmux screen history extract colorize docker)

source "$ZSH/oh-my-zsh.sh"

# history
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt share_history hist_ignore_dups hist_ignore_space

# completion
autoload -Uz compinit
compinit -d "$ZSH_CACHE_DIR/zcompdump"

# aliases
alias ll='ls -laF'
alias la='ls -A'
alias l='ls -CF'
export EDITOR=nano
EOF

	chroot_sdcard chown "${CLOVER2_USER}:${CLOVER2_USER}" "/home/${CLOVER2_USER}/.zshrc"
}

function clover2_user_setup_main() {
	clover2_user_setup_create_user
	clover2_user_setup_zsh
}
