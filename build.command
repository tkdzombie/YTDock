#!/bin/zsh
set -e
ROOT="${0:A:h}"
cd "$ROOT"
ARCH="$(uname -m)"
"$ROOT/Scripts/build-macos.sh" "$ARCH"
"$ROOT/Scripts/verify-release.sh" "$ARCH"
echo
printf "Press Return to close this window..."
read -r _
