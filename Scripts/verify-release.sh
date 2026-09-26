#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ARCH="${1:-$(uname -m)}"
[[ "$ARCH" == "arm64" || "$ARCH" == "x86_64" ]] || { echo "Architecture must be arm64 or x86_64" >&2; exit 2; }
BUILD="$ROOT/build/free/$ARCH"
APP="$BUILD/YTDock.app"
DMG="$BUILD/YTDock-$VERSION-$ARCH.dmg"

[[ -d "$APP" ]] || { echo "Missing app: $APP" >&2; exit 2; }
[[ -f "$DMG" ]] || { echo "Missing DMG: $DMG" >&2; exit 2; }
for f in yt-dlp deno ffmpeg; do
  [[ -x "$APP/Contents/Resources/Tools/$f" ]] || { echo "Missing runtime: $f" >&2; exit 2; }
done
codesign --verify --deep --strict --verbose=2 "$APP"
file "$APP/Contents/MacOS/YTDock" | grep -q "$ARCH" || { echo "Launcher is not $ARCH" >&2; exit 2; }
(
  cd "$BUILD"
  shasum -a 256 -c "SHA256SUMS-$ARCH.txt"
)
echo "Verified YTDock $VERSION ($ARCH) free-distribution artifact."
