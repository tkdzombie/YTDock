#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD="$ROOT/build/free"
APP="$BUILD/YTDock.app"
DMG="$BUILD/YTDock-$VERSION.dmg"

[[ "$(uname -s)" == Darwin ]] || { echo "Verification must run on macOS." >&2; exit 2; }
[[ -d "$APP" ]] || { echo "Missing $APP; run Scripts/build-macos.sh first." >&2; exit 2; }
[[ -f "$DMG" ]] || { echo "Missing $DMG; run Scripts/build-macos.sh first." >&2; exit 2; }

codesign --verify --deep --strict --verbose=4 "$APP"
file "$APP/Contents/MacOS/YTDock"
file "$APP/Contents/Resources/Tools/yt-dlp" "$APP/Contents/Resources/Tools/deno" \
  "$APP/Contents/Resources/Tools/ffmpeg" "$APP/Contents/Resources/Tools/ffprobe"
(
  cd "$BUILD"
  shasum -a 256 -c SHA256SUMS.txt
)
echo "Release verification passed."
