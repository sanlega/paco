#!/usr/bin/env bash
# paco installer.
#
# Strategy: use as little disk/CPU as possible.
#   1. If this is Linux and the real compiler toolchain (gcc, clang,
#      valgrind, python3, libbsd/ncurses headers) is already present, install
#      francinette straight onto the host. Zero container overhead.
#   2. Otherwise (macOS, Windows/WSL without the toolchain, a locked-down
#      Linux session without those packages...) fall back to the slim
#      Docker image built from this repo, which only builds on first use.
#
# Both paths apply the same overlay/ patch (mandatory get_next_line bonus),
# so behaviour is identical either way.
set -euo pipefail

REPO_URL="https://github.com/sanlega/paco.git"
FRANCINETTE_URL="https://github.com/xicodomingues/francinette.git"

WHITE=$'\033[0;37m'
BLUE=$'\033[0;36m'
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
B_WHITE=$'\033[1;37m'
NC=$'\033[0m'

log()  { printf "${BLUE}[paco]${NC} %s\n" "$1"; }
ok()   { printf "${BLUE}[paco]${NC} ${WHITE}%s ${GREEN}OK${NC}\n" "$1"; }
warn() { printf "${BLUE}[paco]${NC} ${YELLOW}%s${NC}\n" "$1"; }
die()  { printf "${BLUE}[paco]${NC} ${RED}%s${NC}\n" "$1" >&2; exit 1; }

if [ -z "${INSTALL_DIR:-}" ]; then
	default_dir="$HOME"
	read -r -p "Install directory (default: $default_dir): " user_input
	INSTALL_DIR="${user_input:-$default_dir}"
fi
mkdir -p "$INSTALL_DIR"
# Resolve to an absolute path: the script later does 'cd' (e.g. into
# francinette to pip install), and every relative path built from
# INSTALL_DIR before that point would silently resolve against whatever
# directory that 'cd' left us in instead.
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
export INSTALL_DIR

PACO_DIR="$INSTALL_DIR/paco"
FRANCINETTE_DIR="$INSTALL_DIR/francinette"

# ---------------------------------------------------------------------------
# 1. Fetch/update this repo (Dockerfile, overlay/, the paco CLI itself).
# ---------------------------------------------------------------------------
if [ -d "$PACO_DIR/.git" ]; then
	log "Updating existing paco checkout in $PACO_DIR"
	git -C "$PACO_DIR" pull --ff-only
else
	rm -rf "$PACO_DIR"
	log "Cloning paco into $PACO_DIR"
	git clone --depth 1 "$REPO_URL" "$PACO_DIR"
fi
chmod +x "$PACO_DIR/paco"

apply_overlay() {
	target="$1"
	if [ -d "$PACO_DIR/overlay" ]; then
		cp -RT "$PACO_DIR/overlay" "$target"
	fi
}

# ---------------------------------------------------------------------------
# 2. Decide native vs docker.
# ---------------------------------------------------------------------------
can_go_native() {
	[ "$(uname -s)" = "Linux" ] || return 1
	for bin in gcc clang valgrind git python3 pip3 make; do
		command -v "$bin" >/dev/null 2>&1 || return 1
	done
	# libbsd-dev installs its public headers under an include/bsd/ dir,
	# not as a top-level bsd*.h, on every distro that packages it this way.
	{ [ -d /usr/include/bsd ] || [ -d /usr/local/include/bsd ]; } || return 1
	{ [ -f /usr/include/ncurses.h ] || [ -f /usr/include/ncurses/ncurses.h ] \
		|| [ -f /usr/include/curses.h ] || [ -f /usr/local/include/ncurses.h ]; } || return 1
	return 0
}

MODE="docker"
if can_go_native; then
	MODE="native"
fi

if [ "$MODE" = "native" ] && [ -d "$FRANCINETTE_DIR" ]; then
	# Already installed natively before; force is only needed if the user
	# explicitly wants to switch to Docker.
	if [ -t 0 ]; then
		read -r -p "francinette is already installed natively in $FRANCINETTE_DIR. Reinstall? (y/N) " answer
	else
		answer="n"
	fi
	case "$answer" in
		[Yy]*) rm -rf "$FRANCINETTE_DIR" ;;
		*) ;;
	esac
fi

if [ "$MODE" = "native" ]; then
	log "Native toolchain detected: installing francinette directly (no Docker needed)."
	if [ ! -d "$FRANCINETTE_DIR" ]; then
		git clone --recursive --shallow-submodules --depth 1 "$FRANCINETTE_URL" "$FRANCINETTE_DIR"
	fi
	apply_overlay "$FRANCINETTE_DIR"

	cd "$FRANCINETTE_DIR"
	if ! pip3 install --user --no-cache-dir -r requirements.txt norminette; then
		warn "pip install failed in the default environment."
		if [ -t 0 ]; then
			read -r -p "Force install into the system environment with --break-system-packages? (y/N) " answer
		else
			answer="n"
		fi
		if [[ "$answer" =~ ^[Yy]$ ]]; then
			pip3 install --user --no-cache-dir --break-system-packages -r requirements.txt norminette \
				|| die "Could not install francinette's Python dependencies."
		else
			die "Could not install francinette's Python dependencies."
		fi
	fi
	echo "native" > "$PACO_DIR/.mode"
	ok "francinette installed natively in $FRANCINETTE_DIR"
else
	if ! command -v docker >/dev/null 2>&1; then
		die "Docker is required on this system (no native toolchain was found) but was not found in PATH. Install Docker Desktop / Docker Engine and re-run this script."
	fi
	log "No usable native toolchain found: paco will run through the slim Docker image instead."
	log "The image builds automatically the first time you run 'paco' (or 'francinette') in a project."
	mkdir -p "$PACO_DIR/logs" "$PACO_DIR/temp"
	echo "docker" > "$PACO_DIR/.mode"
	ok "paco set up in Docker mode"
fi

# ---------------------------------------------------------------------------
# 3. Wire up the 'paco' / 'francinette' commands for every shell rc file
#    this user actually has (bash and/or zsh), instead of assuming zsh.
# ---------------------------------------------------------------------------
BLOCK_START="# >>> paco (francinette) >>>"
BLOCK_END="# <<< paco (francinette) <<<"

write_block() {
	rc_file="$1"
	[ -f "$rc_file" ] || touch "$rc_file"
	if grep -qF "$BLOCK_START" "$rc_file" 2>/dev/null; then
		# remove the previous block so we can rewrite it cleanly (idempotent installs/updates)
		sed -i.bak "/$BLOCK_START/,/$BLOCK_END/d" "$rc_file" && rm -f "$rc_file.bak"
	fi
	{
		echo ""
		echo "$BLOCK_START"
		echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
		echo "alias paco=\"$PACO_DIR/paco\""
		echo "alias francinette=\"$PACO_DIR/paco\""
		echo "$BLOCK_END"
	} >> "$rc_file"
}

wrote_any=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
	if [ -f "$rc" ] || [ "$rc" = "$HOME/.$( basename "${SHELL:-/bin/bash}" )rc" ]; then
		write_block "$rc"
		wrote_any=1
	fi
done
if [ "$wrote_any" -eq 0 ]; then
	# Neither rc file existed yet (fresh account): create the one matching $SHELL.
	write_block "$HOME/.$( basename "${SHELL:-/bin/bash}" )rc"
fi

ok "Installation completed!"
printf '%s\n' "${WHITE}Use the ${B_WHITE}paco${WHITE} (or ${B_WHITE}francinette${WHITE}) command inside a project directory.${NC}"
printf '%s\n' "${WHITE}Open a new shell, or run: ${B_WHITE}source ~/.bashrc${WHITE} (or ~/.zshrc) to use it now.${NC}"
