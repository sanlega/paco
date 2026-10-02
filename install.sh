#!/usr/bin/env bash
# paco installer. Non-interactive: safe to run as
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanlega/paco/main/install.sh)"
#
# 1. Removes any previous install (paco, the original francinette,
#    francinette-image...) - see uninstall.sh. Installing always gives you a
#    clean, current version.
# 2. Native mode when the real toolchain is already there (Linux with gcc,
#    clang, valgrind, libbsd/ncurses headers): zero container overhead.
#    Docker mode otherwise (macOS, WSL without the toolchain...), with a slim
#    image that runs exactly the same patched francinette.
#
# Environment overrides:
#   INSTALL_DIR=/path     where to install (default: $HOME)
#   PACO_MODE=native|docker   skip the auto-detection
#   PACO_BRANCH=name      install another branch of paco (default: main)
set -euo pipefail

REPO_URL="${PACO_REPO:-https://github.com/sanlega/paco.git}"
BRANCH="${PACO_BRANCH:-main}"
FRANCINETTE_URL="https://github.com/xicodomingues/francinette.git"

WHITE=$'\033[0;37m'
BLUE=$'\033[0;36m'
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
B_WHITE=$'\033[1;37m'
NC=$'\033[0m'

log()  { printf '%s[paco]%s %s\n' "$BLUE" "$NC" "$1"; }
ok()   { printf '%s[paco]%s %s%s %sOK%s\n' "$BLUE" "$NC" "$WHITE" "$1" "$GREEN" "$NC"; }
warn() { printf '%s[paco]%s %s%s%s\n' "$BLUE" "$NC" "$YELLOW" "$1" "$NC"; }
die()  { printf '%s[paco]%s %s%s%s\n' "$BLUE" "$NC" "$RED" "$1" "$NC" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required to install paco."

INSTALL_DIR="${INSTALL_DIR:-$HOME}"
mkdir -p "$INSTALL_DIR"
# Absolute path: everything below is built from it, and the script cd's around.
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
export INSTALL_DIR
cd "$INSTALL_DIR"

PACO_DIR="$INSTALL_DIR/paco"
FRANCINETTE_DIR="$INSTALL_DIR/francinette"

# ---------------------------------------------------------------------------
# 1. Fetch the new version first, so a failed download leaves the current
#    install untouched; then remove every previous version and move it in.
# ---------------------------------------------------------------------------
NEW_DIR="$(mktemp -d "$INSTALL_DIR/.paco-install.XXXXXX")"
trap 'rm -rf "$NEW_DIR"' EXIT
log "Downloading paco ($BRANCH)"
git clone -q --depth 1 --branch "$BRANCH" "$REPO_URL" "$NEW_DIR/paco" \
	|| die "Could not download paco from $REPO_URL ($BRANCH)."

log "Removing previous versions"
bash "$NEW_DIR/paco/uninstall.sh" | sed 's/^/  /'
mv "$NEW_DIR/paco" "$PACO_DIR"
chmod +x "$PACO_DIR/paco" "$PACO_DIR"/*.sh

# ---------------------------------------------------------------------------
# 2. Native or Docker.
# ---------------------------------------------------------------------------
can_go_native() {
	[ "$(uname -s)" = "Linux" ] || return 1
	for bin in gcc clang clang++ valgrind make python3; do
		command -v "$bin" >/dev/null 2>&1 || return 1
	done
	python3 -m pip --version >/dev/null 2>&1 || python3 -m venv --help >/dev/null 2>&1 || return 1
	# libbsd-dev ships include/bsd/, libncurses-dev ships ncurses.h/curses.h
	{ [ -d /usr/include/bsd ] || [ -d /usr/local/include/bsd ]; } || return 1
	{ [ -f /usr/include/ncurses.h ] || [ -f /usr/include/ncurses/ncurses.h ] \
		|| [ -f /usr/include/curses.h ] || [ -f /usr/local/include/ncurses.h ]; } || return 1
}

MODE="${PACO_MODE:-}"
if [ -z "$MODE" ]; then
	if can_go_native; then MODE="native"; else MODE="docker"; fi
fi
case "$MODE" in native|docker) ;; *) die "PACO_MODE must be 'native' or 'docker'." ;; esac

# Installs francinette's Python dependencies. A venv first (isolated, and
# immune to PEP 668 "externally managed environment" errors); --user, then
# --break-system-packages, as fallbacks for systems without python3-venv.
install_python_deps() {
	local req="$FRANCINETTE_DIR/requirements.txt"
	if python3 -m venv "$PACO_DIR/venv" >/dev/null 2>&1 \
		&& "$PACO_DIR/venv/bin/python" -m pip install -q --no-cache-dir -r "$req" norminette; then
		return 0
	fi
	rm -rf "$PACO_DIR/venv"
	warn "python3-venv is not available, installing the Python packages with pip --user."
	python3 -m pip install -q --user --no-cache-dir -r "$req" norminette 2>/dev/null \
		|| python3 -m pip install -q --user --no-cache-dir --break-system-packages -r "$req" norminette
}

if [ "$MODE" = "native" ]; then
	log "Native toolchain found: installing francinette directly (no Docker needed)"
	git clone -q --recursive --shallow-submodules --depth 1 "$FRANCINETTE_URL" "$FRANCINETTE_DIR" \
		|| die "Could not download francinette."
	"$PACO_DIR/patch-francinette.sh" "$FRANCINETTE_DIR" || die "Could not apply paco's patches to francinette."
	install_python_deps || die "Could not install francinette's Python dependencies."
	echo native > "$PACO_DIR/.mode"
	ok "francinette installed natively in $FRANCINETTE_DIR"
else
	command -v docker >/dev/null 2>&1 \
		|| die "No native toolchain found, and Docker is not installed. Install Docker Desktop / Docker Engine (or gcc, clang, valgrind, libbsd-dev, libncurses-dev) and run this again."
	echo docker > "$PACO_DIR/.mode"
	if docker info >/dev/null 2>&1; then
		log "Building the Docker image (only this once, a few minutes)"
		"$PACO_DIR/paco" --prepare || die "Could not build the Docker image."
		ok "paco set up in Docker mode"
	else
		ok "paco set up in Docker mode"
		warn "Docker is not running right now: the image will be built the first time you run paco."
	fi
fi

# ---------------------------------------------------------------------------
# 3. 'paco' and 'francinette' commands, for whichever of bash/zsh you use.
# ---------------------------------------------------------------------------
write_block() {
	local rc="$1"
	{
		echo ""
		echo "# >>> paco (francinette) >>>"
		echo "alias paco=\"$PACO_DIR/paco\""
		echo "alias francinette=\"$PACO_DIR/paco\""
		echo "# <<< paco (francinette) <<<"
	} >> "$rc"
}

user_rc="$HOME/.$(basename "${SHELL:-/bin/bash}")rc"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
	if [ -f "$rc" ] || [ "$rc" = "$user_rc" ]; then
		write_block "$rc"
	fi
done

echo
ok "Installation completed"
printf '%s\n' "${WHITE}Open a new terminal (or run ${B_WHITE}source $user_rc${WHITE}), then run ${B_WHITE}paco${WHITE} inside a project folder.${NC}"
