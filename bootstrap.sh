#!/bin/bash
# Takes a fresh Mac from nothing to the first nix-darwin switch.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/M-Pull/Dotfiles/main/bootstrap.sh)"
#
# Using a fork? Append `- <your-repo-url>` to that line. One password prompt,
# nothing else. Safe to re-run: every step skips itself when already done.
# Runs as your normal user; sudo is used only where a step needs it.
set -euo pipefail

EXPECTED_USER="iceBear"
REPO_URL="${1:-https://github.com/M-Pull/Dotfiles.git}"
REPO_DIR="$HOME/Dotfiles"
LINK="$HOME/.dotfiles"
NIX_BIN=/nix/var/nix/profiles/default/bin/nix
NIX_PROFILE_SH=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
CLT_TRIGGER=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

die() {
  echo "    error: $*" >&2
  exit 1
}

SUDO_KEEPALIVE=""
cleanup() {
  [ -n "$SUDO_KEEPALIVE" ] && kill "$SUDO_KEEPALIVE" 2>/dev/null || true
  sudo -n rm -f "$CLT_TRIGGER" 2>/dev/null || true
  sudo -k 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Step 1/6: sanity checks"
REAL_USER="$(whoami)"
[ "$REAL_USER" = "$EXPECTED_USER" ] \
  || die "this bootstrap expects macOS user \"$EXPECTED_USER\"; you are \"$REAL_USER\""
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"
[ "$(uname -m)" = "arm64" ] || die "Apple Silicon only (uname -m says $(uname -m))"
# Under `curl | bash` stdin is the script, so anything interactive must use the terminal.
{ [ -r /dev/tty ] && [ -w /dev/tty ]; } || die "a terminal is required"
echo "    user $REAL_USER, arm64, terminal ok"

echo "==> Step 2/6: your password, once"
# sudo prompts on the terminal and handles retries itself; this script never
# sees the password. The keepalive renews the ticket until the script exits.
sudo -k
sudo -v || die "sudo authentication failed"
(while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done) 2>/dev/null &
SUDO_KEEPALIVE=$!
echo "    no more questions from here on"

echo "==> Step 3/6: Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  echo "    already installed, skipping"
else
  echo "    asking Software Update for the Command Line Tools (quiet for ~1 min)..."
  sudo touch "$CLT_TRIGGER"
  CLT_LIST="$(softwareupdate -l 2>/dev/null)"
  CLT_LABEL="$(printf '%s\n' "$CLT_LIST" \
    | sed -n 's/^[ *]*Label: *\(Command Line Tools.*\)/\1/p' | tail -n 1)"
  # Size must come from THIS label's block: a pending macOS update also lists
  # a size, and taking the last one inflates the bar total.
  CLT_SIZE_KB="$(printf '%s\n' "$CLT_LIST" \
    | grep -A1 -F "Label: $CLT_LABEL" \
    | sed -n 's/.*Size: *\([0-9][0-9]*\).*/\1/p' | head -n 1)"
  if [ -z "$CLT_LABEL" ]; then
    echo "    Software Update did not offer the CLT; falling back to the GUI installer."
    echo "    Finish its dialog, then re-run this script."
    xcode-select --install
    exit 1
  fi
  echo "    installing \"$CLT_LABEL\""
  # softwareupdate downloads silently, so measure the download on disk instead.
  sudo softwareupdate -i "$CLT_LABEL" --verbose >/tmp/clt-install.log 2>&1 &
  CLT_PID=$!
  while kill -0 "$CLT_PID" 2>/dev/null; do
    DL_KB="$(sudo du -sk /Library/Updates 2>/dev/null | cut -f1)"
    DL_KB="${DL_KB:-0}"
    ELAPSED="$(printf '%dm%02ds' $((SECONDS / 60)) $((SECONDS % 60)))"
    if [ -n "$CLT_SIZE_KB" ] && [ "$CLT_SIZE_KB" -gt 0 ]; then
      PCT=$((DL_KB * 100 / CLT_SIZE_KB))
      [ "$PCT" -gt 100 ] && PCT=100
      FILLED=$((PCT * 40 / 100))
      printf '\r    [%-40s] %3d%%  %d/%d MB  %s' \
        "$(printf '%*s' "$FILLED" '' | tr ' ' '#')" \
        "$PCT" $((DL_KB / 1024)) $((CLT_SIZE_KB / 1024)) "$ELAPSED"
    else
      printf '\r    downloaded: %d MB  %s' $((DL_KB / 1024)) "$ELAPSED"
    fi
    sleep 2
  done
  printf '\n'
  wait "$CLT_PID" # fail the script if the install failed
  sudo rm -f "$CLT_TRIGGER"
fi

echo "==> Step 4/6: Determinate Nix"
if [ -x "$NIX_BIN" ]; then
  echo "    already installed, skipping"
else
  # Determinate Nix is the installer's default. It calls sudo itself and
  # finds the ticket from step 2, so it never prompts.
  curl --proto '=https' --tlsv1.2 -fsSL https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
fi
# This shell predates the install; load Nix here instead of asking for a new terminal.
# shellcheck disable=SC1090
[ -r "$NIX_PROFILE_SH" ] && . "$NIX_PROFILE_SH"

echo "==> Step 5/6: the repo at $REPO_DIR"
strip_git() { printf '%s' "${1%/}" | sed 's/\.git$//'; }
if [ -d "$REPO_DIR/.git" ]; then
  ORIGIN="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
  [ "$(strip_git "$ORIGIN")" = "$(strip_git "$REPO_URL")" ] \
    || die "$REPO_DIR exists but its origin is \"$ORIGIN\", expected \"$REPO_URL\""
  # Only tracked files count; untracked ones are left alone and git itself
  # refuses to overwrite any that collide with the pull.
  [ -z "$(git -C "$REPO_DIR" status --porcelain --untracked-files=no)" ] \
    || die "$REPO_DIR has uncommitted changes to tracked files; commit or stash them, then re-run"
  echo "    existing clone, pulling"
  git -C "$REPO_DIR" pull --ff-only
elif [ -e "$REPO_DIR" ]; then
  die "$REPO_DIR exists and is not a git repository"
else
  git clone "$REPO_URL" "$REPO_DIR"
fi
[ -f "$REPO_DIR/flake.lock" ] \
  || die "flake.lock is missing from the repo; CI commits it on push to main, wait for that run"

# Stable path for everything that refers to the repo, whatever the clone's location.
if [ -L "$LINK" ]; then
  TARGET="$(cd "$LINK" 2>/dev/null && pwd -P || readlink "$LINK")"
  [ "$TARGET" = "$(cd "$REPO_DIR" && pwd -P)" ] \
    || die "$LINK already points to \"$TARGET\", not $REPO_DIR; remove it yourself if that is intended"
elif [ -e "$LINK" ]; then
  die "$LINK exists and is not a symlink; move it away yourself"
else
  ln -s "$REPO_DIR" "$LINK"
fi

echo "==> Step 6/6: first switch"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$REPO_DIR/flake.nix" | head -n 1)"
[ "$FLAKE_USER" = "$REAL_USER" ] \
  || die "flake.nix is configured for user \"$FLAKE_USER\"; you are \"$REAL_USER\""
"$REPO_DIR/rebuild.sh"

echo "==> Done. Open a new terminal. Later changes: $REPO_DIR/rebuild.sh"
