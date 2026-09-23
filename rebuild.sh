#!/usr/bin/env bash
# Forces a clean rebuild: in docker mode, drops the container/image and
# rebuilds from scratch (no layer cache); in native mode, wipes the
# francinette checkout and reinstalls it.
set -euo pipefail

BLUE='\033[0;36m'
WHITE='\033[0;37m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
log() { printf "${BLUE}[paco]${NC} ${WHITE}%s${NC}\n" "$1"; }
die() { printf "${BLUE}[paco]${NC} ${RED}%s${NC}\n" "$1" >&2; exit 1; }

if [ -z "${INSTALL_DIR:-}" ]; then
	if [ -d "$HOME/paco" ]; then
		INSTALL_DIR="$HOME"
	else
		read -r -p "Install directory used by paco: " INSTALL_DIR
	fi
fi

PACO_DIR="$INSTALL_DIR/paco"
[ -d "$PACO_DIR" ] || die "paco is not installed in $PACO_DIR. Run install.sh first."

MODE="$(cat "$PACO_DIR/.mode" 2>/dev/null || echo docker)"

if [ "$MODE" = "native" ]; then
	rm -rf "$INSTALL_DIR/francinette"
	log "Removed native francinette checkout, reinstalling"
	INSTALL_DIR="$INSTALL_DIR" bash "$PACO_DIR/install.sh"
else
	command -v docker >/dev/null 2>&1 || die "docker not found in PATH."
	docker rm -f paco-runner >/dev/null 2>&1 || true
	docker rmi -f paco-francinette >/dev/null 2>&1 || true
	log "Removed docker image/container, rebuilding"
	docker build --no-cache -t paco-francinette "$PACO_DIR"
fi

printf '%s\n' "${BLUE}[paco]${NC} ${WHITE}Rebuilt ${GREEN}OK${NC}"
