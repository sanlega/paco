#!/usr/bin/env bash
# Updates paco to the latest version of its branch, re-applies the patches
# to francinette (native mode) or rebuilds the image if needed (Docker
# mode). Also available as `paco --update`.
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
[ -d "$PACO_DIR/.git" ] || die "$PACO_DIR is not a paco install. Run install.sh."

branch="$(git -C "$PACO_DIR" rev-parse --abbrev-ref HEAD)"
before="$(git -C "$PACO_DIR" rev-parse HEAD)"
log "Fetching the latest paco ($branch)"
git -C "$PACO_DIR" fetch -q --depth 1 origin "$branch" || die "Could not reach GitHub."
# reset rather than pull: never fails on local changes or diverged shallow history
git -C "$PACO_DIR" reset -q --hard FETCH_HEAD
chmod +x "$PACO_DIR/paco" "$PACO_DIR"/*.sh

if [ "$before" = "$(git -C "$PACO_DIR" rev-parse HEAD)" ]; then
	log "paco is already up to date"
else
	log "Updated paco to $(git -C "$PACO_DIR" log -1 --format='%h (%cs)')"
fi

if [ "$(cat "$PACO_DIR/.mode")" = "native" ]; then
	[ -d "$FRANCINETTE_DIR/.git" ] || die "francinette is missing from $FRANCINETTE_DIR. Run 'paco --rebuild'."
	log "Re-applying the patches to francinette"
	# back to a pristine checkout (patched files, untracked/ignored leftovers), then patch again
	git -C "$FRANCINETTE_DIR" reset -q --hard
	git -C "$FRANCINETTE_DIR" clean -qfdx
	git -C "$FRANCINETTE_DIR" submodule -q foreach --recursive 'git reset -q --hard && git clean -qfdx'
	"$PACO_DIR/patch-francinette.sh" "$FRANCINETTE_DIR"
else
	"$PACO_DIR/paco" --prepare || true
fi

printf '%s[paco]%s %sUpdated %sOK%s\n' "$BLUE" "$NC" "$WHITE" "$GREEN" "$NC"
