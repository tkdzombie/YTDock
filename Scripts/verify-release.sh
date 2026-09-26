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
[[ -x "$APP/Contents/MacOS/YTDock" ]] || { echo "Missing native app executable" >&2; exit 2; }
[[ ! -e "$APP/Contents/Resources/app.js" ]] || { echo "Legacy JXA application layer unexpectedly present" >&2; exit 2; }
for f in yt-dlp deno ffmpeg; do
  [[ -x "$APP/Contents/Resources/Tools/$f" ]] || { echo "Missing runtime: $f" >&2; exit 2; }
done
codesign --verify --deep --strict --verbose=2 "$APP"
EXEC="$APP/Contents/MacOS/YTDock"
FILE_DESC="$(file "$EXEC")"
[[ "$FILE_DESC" == *"$ARCH"* ]] || {
  echo "Executable is not $ARCH: $FILE_DESC" >&2
  exit 2
}

# Avoid `strings | grep -q` under pipefail: grep can exit as soon as it finds a
# match, leaving `strings` writing into a closed pipe and producing a false
# `failed to flush output` error on GitHub macOS runners. Scan the Mach-O
# directly instead; -a treats it as text for this simple embedded-string check.
/usr/bin/grep -a -F -q "YTDock" "$EXEC" || {
  echo "Executable smoke check failed" >&2
  exit 2
}
(
  cd "$BUILD"
  shasum -a 256 -c "SHA256SUMS-$ARCH.txt"
)
echo "Verified YTDock $VERSION ($ARCH) native free-distribution artifact."
