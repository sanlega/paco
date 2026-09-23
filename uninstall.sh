#!/usr/bin/env bash
# Removes paco: the docker image/container (if any), the native francinette
# checkout (if any), and the shell rc blocks that alias 'paco'/'francinette'.
set -euo pipefail

BLUE='\033[0;36m'
WHITE='\033[0;37m'
GREEN='\033[0;32m'
NC='\033[0m'
log() { printf "${BLUE}[paco]${NC} ${WHITE}%s${NC}\n" "$1"; }

if [ -z "${INSTALL_DIR:-}" ]; then
	if [ -d "$HOME/paco" ] || [ -d "$HOME/francinette" ]; then
		INSTALL_DIR="$HOME"
	else
		read -r -p "Install directory used by paco: " INSTALL_DIR
	fi
fi

PACO_DIR="$INSTALL_DIR/paco"
FRANCINETTE_DIR="$INSTALL_DIR/francinette"
IMAGE_NAME="paco-francinette"
CONTAINER_NAME="paco-runner"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
		docker rm -f "$CONTAINER_NAME" >/dev/null
		log "Removed docker container $CONTAINER_NAME"
	fi
	if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
		docker rmi -f "$IMAGE_NAME" >/dev/null
		log "Removed docker image $IMAGE_NAME"
	fi
fi

rm -rf "$PACO_DIR" "$FRANCINETTE_DIR"
log "Removed $PACO_DIR and $FRANCINETTE_DIR"

BLOCK_START="# >>> paco (francinette) >>>"
BLOCK_END="# <<< paco (francinette) <<<"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
	if [ -f "$rc" ] && grep -qF "$BLOCK_START" "$rc"; then
		sed -i.bak "/$BLOCK_START/,/$BLOCK_END/d" "$rc" && rm -f "$rc.bak"
		log "Removed paco block from $rc"
	fi
done

printf '%s\n' "${BLUE}[paco]${NC} ${WHITE}Uninstalled ${GREEN}OK${NC}"
