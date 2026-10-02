#!/usr/bin/env bash
# Rebuilds paco's runtime from scratch: the Docker image without any layer
# cache (Docker mode), or a fresh francinette checkout (native mode). Use it
# if something got corrupted. Also available as `paco --rebuild`.
set -euo pipefail

BLUE=$'\033[0;36m'
WHITE=$'\033[0;37m'
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
NC=$'\033[0m'
log() { printf '%s[paco]%s %s%s%s\n' "$BLUE" "$NC" "$WHITE" "$1" "$NC"; }
die() { printf '%s[paco]%s %s%s%s\n' "$BLUE" "$NC" "$RED" "$1" "$NC" >&2; exit 1; }

PACO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
INSTALL_DIR="$(dirname "$PACO_DIR")"
FRANCINETTE_DIR="$INSTALL_DIR/francinette"
MODE="$(cat "$PACO_DIR/.mode" 2>/dev/null || true)"

rm -rf "$PACO_DIR/logs" "$PACO_DIR/temp"
if [ "$MODE" = "native" ]; then
	log "Reinstalling francinette from scratch"
	rm -rf "$FRANCINETTE_DIR" "$PACO_DIR/venv"
	git clone -q --recursive --shallow-submodules --depth 1 \
		https://github.com/xicodomingues/francinette.git "$FRANCINETTE_DIR" || die "Could not download francinette."
	"$PACO_DIR/patch-francinette.sh" "$FRANCINETTE_DIR"
	req="$FRANCINETTE_DIR/requirements.txt"
	if python3 -m venv "$PACO_DIR/venv" >/dev/null 2>&1; then
		"$PACO_DIR/venv/bin/python" -m pip install -q --no-cache-dir -r "$req" norminette
	else
		rm -rf "$PACO_DIR/venv"
		python3 -m pip install -q --user --no-cache-dir -r "$req" norminette 2>/dev/null \
			|| python3 -m pip install -q --user --no-cache-dir --break-system-packages -r "$req" norminette
	fi
elif [ "$MODE" = "docker" ]; then
	log "Rebuilding the Docker image without cache"
	"$PACO_DIR/paco" --build-image
else
	die "paco is not installed correctly. Run install.sh again."
fi

printf '%s[paco]%s %sRebuilt %sOK%s\n' "$BLUE" "$NC" "$WHITE" "$GREEN" "$NC"
