#!/usr/bin/env bash
# Pulls the latest paco (Dockerfile/overlay/CLI) and, in native mode, the
# latest francinette too, then re-applies the overlay and rebuilds whatever
# needs rebuilding.
set -euo pipefail

BLUE=$'\033[0;36m'
WHITE=$'\033[0;37m'
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
NC=$'\033[0m'
log() { printf "${BLUE}[paco]${NC} ${WHITE}%s${NC}\n" "$1"; }
die() { printf "${BLUE}[paco]${NC} ${RED}%s${NC}\n" "$1" >&2; exit 1; }

if [ -z "${INSTALL_DIR:-}" ]; then
	if [ -d "$HOME/paco" ]; then
		INSTALL_DIR="$HOME"
	else
		read -r -p "Install directory used by paco: " INSTALL_DIR
	fi
fi
[ -d "$INSTALL_DIR" ] && INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"

PACO_DIR="$INSTALL_DIR/paco"
FRANCINETTE_DIR="$INSTALL_DIR/francinette"

[ -d "$PACO_DIR/.git" ] || die "paco is not installed in $PACO_DIR. Run install.sh first."

log "Pulling latest paco"
git -C "$PACO_DIR" pull --ff-only
chmod +x "$PACO_DIR/paco"

MODE="$(cat "$PACO_DIR/.mode" 2>/dev/null || echo docker)"

if [ "$MODE" = "native" ]; then
	[ -d "$FRANCINETTE_DIR/.git" ] || die "francinette is not installed in $FRANCINETTE_DIR."
	log "Pulling latest francinette"
	git -C "$FRANCINETTE_DIR" pull --ff-only
	git -C "$FRANCINETTE_DIR" submodule update --init --recursive
	if [ -d "$PACO_DIR/overlay" ]; then
		cp -RT "$PACO_DIR/overlay" "$FRANCINETTE_DIR"
	fi
	(cd "$FRANCINETTE_DIR" && pip3 install --user --no-cache-dir -r requirements.txt norminette)
	log "francinette updated natively"
else
	if command -v docker >/dev/null 2>&1 && docker image inspect paco-francinette >/dev/null 2>&1; then
		log "Rebuilding the docker image with --no-cache so the update actually takes"
		docker rm -f paco-runner >/dev/null 2>&1 || true
		docker build --no-cache -t paco-francinette "$PACO_DIR"
	else
		log "Docker image will be built on next 'paco' run"
	fi
fi

printf '%s\n' "${BLUE}[paco]${NC} ${WHITE}Updated ${GREEN}OK${NC}"
