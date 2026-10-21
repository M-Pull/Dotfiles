#!/usr/bin/env bash
# The one rebuild path. bootstrap.sh calls it for the first switch; you call it
# for every change after that. Applies this repo's config, never updates the lock.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FLAKE_HOST="mac"
NIX_DARWIN_REF="github:nix-darwin/nix-darwin/nix-darwin-26.05"

# Right after bootstrap, the calling shell predates the Nix install, so nix
# may not be on PATH yet. sudo also resets PATH, so absolute paths throughout.
NIX_BIN="$(command -v nix 2>/dev/null || true)"
[ -n "$NIX_BIN" ] || NIX_BIN=/nix/var/nix/profiles/default/bin/nix
[ -x "$NIX_BIN" ] || { echo "nix not found; run bootstrap.sh first" >&2; exit 1; }

DARWIN_REBUILD="$(command -v darwin-rebuild 2>/dev/null || true)"
[ -n "$DARWIN_REBUILD" ] || [ ! -x /run/current-system/sw/bin/darwin-rebuild ] \
  || DARWIN_REBUILD=/run/current-system/sw/bin/darwin-rebuild

if [ -n "$DARWIN_REBUILD" ]; then
  exec sudo "$DARWIN_REBUILD" switch --flake "$DIR#$FLAKE_HOST"
fi
# First switch: darwin-rebuild does not exist yet, so fetch it from the pinned branch.
exec sudo "$NIX_BIN" run "$NIX_DARWIN_REF#darwin-rebuild" -- switch --flake "$DIR#$FLAKE_HOST"
