#!/usr/bin/env bash
# Applies paco's fixes (patches/*.patch, in order) on top of a francinette
# checkout. Used by both the Docker image and native installs, so the two
# always run exactly the same code. Expects a pristine checkout: install.sh
# and update.sh reset francinette before calling it.
#
# usage: patch-francinette.sh <francinette-dir>
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/patches"
TARGET="${1:?usage: patch-francinette.sh <francinette-dir>}"

# Run git outside of any repository: inside a checkout, `git apply` would
# refuse to touch files that live in submodules (the vendored testers).
apply() { (cd "$TARGET" && GIT_DIR=/nonexistent GIT_CEILING_DIRECTORIES="$PWD/.." git apply "$@"); }

for patch in "$PATCH_DIR"/*.patch; do
	[ -e "$patch" ] || continue
	if ! apply "$patch"; then
		echo "patch-francinette: $(basename "$patch") does not apply to $TARGET" >&2
		exit 1
	fi
done
