#!/usr/bin/env bash
# Removes paco and everything an earlier install may have left behind:
#   - this project's Docker container/image, and the native francinette
#     checkout it installs
#   - older layouts: the original francinette (~/francinette) and
#     francinette-image (its 'run-paco' container, 'francinette-image' image
#     and the blocks it appended to ~/.zshrc)
#   - the 'paco'/'francinette' aliases in ~/.bashrc and ~/.zshrc
#
# install.sh runs this before every install, so installing always replaces
# whatever version was there. Non-interactive; honours INSTALL_DIR like
# install.sh does (default: $HOME).
set -uo pipefail

BLUE=$'\033[0;36m'
WHITE=$'\033[0;37m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'
log()  { printf '%s[paco]%s %s%s%s\n' "$BLUE" "$NC" "$WHITE" "$1" "$NC"; }
warn() { printf '%s[paco]%s %s%s%s\n' "$BLUE" "$NC" "$YELLOW" "$1" "$NC"; }

INSTALL_DIR="${INSTALL_DIR:-$HOME}"
[ -d "$INSTALL_DIR" ] && INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"

PACO_DIR="$INSTALL_DIR/paco"
FRANCINETTE_DIR="$INSTALL_DIR/francinette"

# Everything any version ever created.
CONTAINERS=(paco-runner run-paco)
IMAGES=(paco-francinette francinette-image)
DIRS=("$PACO_DIR" "$FRANCINETTE_DIR" "$INSTALL_DIR/francinette-image" "$INSTALL_DIR/.tmp_francinette"
	"$INSTALL_DIR/.tmp_francinette-image")
[ "$INSTALL_DIR" != "$HOME" ] && DIRS+=("$HOME/francinette" "$HOME/francinette-image")

docker_ok() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

# Older versions ran their container as root, so the logs/temp folders they
# mounted from the host can be owned by root. Delete those through Docker,
# while one of the images still exists, instead of failing on them.
remove_dir() {
	local dir="$1" image
	[ -e "$dir" ] || return 0
	rm -rf "$dir" 2>/dev/null
	if [ -e "$dir" ] && docker_ok; then
		for image in "${IMAGES[@]}"; do
			docker image inspect "$image" >/dev/null 2>&1 || continue
			docker run --rm --entrypoint /bin/sh -v "$dir:/wipe" "$image" \
				-c 'rm -rf /wipe/* /wipe/.[!.]* /wipe/..?*' >/dev/null 2>&1
			break
		done
		rm -rf "$dir" 2>/dev/null
	fi
	if [ -e "$dir" ]; then
		warn "Could not fully remove $dir (permission denied). Remove it with: sudo rm -rf \"$dir\""
	else
		log "Removed $dir"
	fi
}

# Drops paco's own block, the aliases older versions added, and the
# docker-autostart blocks francinette-image appended, from a shell rc file.
clean_rc() {
	local rc="$1" tmp
	[ -f "$rc" ] || return 0
	grep -qE 'paco|francinette' "$rc" || return 0
	tmp="$(mktemp)"
	awk '
		/^# >>> paco \(francinette\) >>>/ { skip_block = 1; next }
		skip_block { if (/^# <<< paco \(francinette\) <<</) skip_block = 0; next }
		# francinette-image: three top-level if...fi blocks
		/^if / && /(systemctl status docker|francinette-image|run-paco)/ { skip_if = 1; next }
		skip_if { if (/^fi[[:space:]]*$/) skip_if = 0; next }
		/^[[:space:]]*alias (paco|francinette)=/ { next }
		{ print }
	' "$rc" > "$tmp"
	if ! cmp -s "$rc" "$tmp"; then
		cp "$rc" "$rc.paco-backup"
		cat "$tmp" > "$rc"
		log "Cleaned paco/francinette entries from $rc (backup: $rc.paco-backup)"
	fi
	rm -f "$tmp"
}

if docker_ok; then
	for container in "${CONTAINERS[@]}"; do
		if docker container inspect "$container" >/dev/null 2>&1; then
			docker rm -f "$container" >/dev/null 2>&1 && log "Removed Docker container $container"
		fi
	done
fi

for dir in "${DIRS[@]}"; do
	remove_dir "$dir"
done

if docker_ok; then
	for image in "${IMAGES[@]}"; do
		if docker image inspect "$image" >/dev/null 2>&1; then
			docker rmi -f "$image" >/dev/null 2>&1 && log "Removed Docker image $image"
		fi
	done
fi

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
	clean_rc "$rc"
done

printf '%s[paco]%s %sUninstalled %sOK%s\n' "$BLUE" "$NC" "$WHITE" "$GREEN" "$NC"
