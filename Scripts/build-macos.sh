#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
[[ "$(uname -s)" == Darwin ]] || { echo "This build must run on macOS." >&2; exit 2; }
for cmd in xcrun codesign hdiutil shasum ditto xattr curl file; do
  command -v "$cmd" >/dev/null || { echo "Missing tool: $cmd" >&2; exit 2; }
done
[[ -x /usr/libexec/PlistBuddy ]] || { echo "Missing /usr/libexec/PlistBuddy" >&2; exit 2; }

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$VERSION" == <->.<->.<-> ]] || { echo "VERSION must be semantic x.y.z (found: $VERSION)" >&2; exit 2; }
ARCH="${1:-$(uname -m)}"
[[ "$ARCH" == "arm64" || "$ARCH" == "x86_64" ]] || { echo "Architecture must be arm64 or x86_64" >&2; exit 2; }

BUILD="$ROOT/build/free/$ARCH"
APP="$BUILD/YTDock.app"
STAGE="$BUILD/dmg-root"
DMG="$BUILD/YTDock-$VERSION-$ARCH.dmg"
TEMPLATE="$ROOT/Packaging/YTDock.app"

rm -rf "$BUILD"
mkdir -p "$BUILD" "$STAGE"
cp -R "$TEMPLATE" "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Tools"
sed "s/__YTDock_VERSION__/$VERSION/g" "$ROOT/Sources/app.js" > "$APP/Contents/Resources/app.js"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :YTDockBuildArchitecture $ARCH" "$APP/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :YTDockBuildArchitecture string $ARCH" "$APP/Contents/Info.plist"

# Thin native launcher for the selected release architecture.
TARGET="$ARCH-apple-macos12.0"
xcrun --sdk macosx swiftc -O -target "$TARGET" "$ROOT/Sources/NativeLauncher.swift" -o "$APP/Contents/MacOS/YTDock"
chmod 755 "$APP/Contents/MacOS/YTDock"

# Pinned, architecture-specific runtime dependencies.
"$ROOT/Scripts/vendor-deps.sh" "$APP/Contents/Resources/Tools" "$ARCH"
cp "$ROOT/DEPENDENCIES.lock" "$APP/Contents/Resources/DEPENDENCIES.lock"
cp "$ROOT/PRIVACY.md" "$APP/Contents/Resources/PRIVACY.md"
cp "$ROOT/SECURITY.md" "$APP/Contents/Resources/SECURITY.md"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
[[ -f "$ROOT/COPYRIGHT.md" ]] && cp "$ROOT/COPYRIGHT.md" "$APP/Contents/Resources/COPYRIGHT.md"

# Free-distribution integrity signing. This is not Developer ID trust.
xattr -cr "$APP"
ENT="$ROOT/Packaging/deno.entitlements.plist"
codesign --force --sign - --options runtime --entitlements "$ENT" "$APP/Contents/Resources/Tools/deno"
for exe in yt-dlp ffmpeg; do
  codesign --force --sign - --options runtime "$APP/Contents/Resources/Tools/$exe"
done
codesign --force --sign - --options runtime "$APP/Contents/MacOS/YTDock"
codesign --force --sign - --options runtime "$APP"
codesign --verify --deep --strict --verbose=4 "$APP"

{
  echo "YTDock $VERSION"
  echo "Release architecture: $ARCH"
  echo "Build UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Signing: ad-hoc (no Developer ID / no Apple notarization)"
  echo "Host: $(sw_vers -productVersion) / $(uname -m)"
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Source commit: $(git -C "$ROOT" rev-parse HEAD)"
  fi
  echo "Launcher: $(file "$APP/Contents/MacOS/YTDock")"
  echo
  shasum -a 256 \
    "$APP/Contents/Resources/Tools/yt-dlp" \
    "$APP/Contents/Resources/Tools/deno" \
    "$APP/Contents/Resources/Tools/ffmpeg"
} > "$BUILD/BUILDINFO-$ARCH.txt"

cp -R "$APP" "$STAGE/YTDock.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/Packaging/首次打开.txt" "$STAGE/首次打开.txt"
cp "$ROOT/PRIVACY.md" "$STAGE/PRIVACY.md"
cp "$ROOT/SECURITY.md" "$STAGE/SECURITY.md"
cp "$BUILD/BUILDINFO-$ARCH.txt" "$STAGE/BUILDINFO.txt"

# UDZO + max zlib level for a smaller download without changing runtime contents.
hdiutil create -volname "YTDock $VERSION ($ARCH)" -srcfolder "$STAGE" -ov -format UDZO -imagekey zlib-level=9 "$DMG"
codesign --force --sign - "$DMG" 2>/dev/null || true
(
  cd "$BUILD"
  shasum -a 256 "YTDock-$VERSION-$ARCH.dmg" > "SHA256SUMS-$ARCH.txt"
)

echo
echo "Created: $DMG"
echo "Architecture: $ARCH"
echo "This build is ad-hoc signed, not Developer ID signed, and not Apple notarized."
