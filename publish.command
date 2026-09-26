#!/bin/zsh
set -e
ROOT="${0:A:h}"
cd "$ROOT"
"$ROOT/Scripts/publish-tag.sh"
echo
printf "Press Return to close this window..."
read -r _
