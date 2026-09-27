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
GENERATED="$BUILD/generated"

rm -rf "$BUILD"
mkdir -p "$BUILD" "$STAGE" "$GENERATED"
cp -R "$TEMPLATE" "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Tools"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :YTDockBuildArchitecture $ARCH" "$APP/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :YTDockBuildArchitecture string $ARCH" "$APP/Contents/Info.plist"

# Native SwiftUI application. There is no JXA/osascript application layer in 1.2+.
sed "s/__YTDock_VERSION__/$VERSION/g" "$ROOT/Sources/YTDockApp.swift" > "$GENERATED/YTDockApp.swift"
TARGET="$ARCH-apple-macos12.0"
xcrun --sdk macosx swiftc \
  -O \
  -parse-as-library \
  -swift-version 5 \
  -target "$TARGET" \
  "$GENERATED/YTDockApp.swift" \
  -framework SwiftUI \
  -framework AppKit \
  -framework UserNotifications \
  -o "$APP/Contents/MacOS/YTDock"
chmod 755 "$APP/Contents/MacOS/YTDock"

# Pinned, architecture-specific runtime dependencies.
"$ROOT/Scripts/vendor-deps.sh" "$APP/Contents/Resources/Tools" "$ARCH"
cp "$ROOT/DEPENDENCIES.lock" "$APP/Contents/Resources/DEPENDENCIES.lock"
cp "$ROOT/PRIVACY.md" "$APP/Contents/Resources/PRIVACY.md"
cp "$ROOT/SECURITY.md" "$APP/Contents/Resources/SECURITY.md"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
[[ -f "$ROOT/COPYRIGHT.md" ]] && cp "$ROOT/COPYRIGHT.md" "$APP/Contents/Resources/COPYRIGHT.md"
[[ -f "$ROOT/docs/ARCHITECTURE.md" ]] && cp "$ROOT/docs/ARCHITECTURE.md" "$APP/Contents/Resources/ARCHITECTURE.md"

# Free-distribution integrity signing. This is not Developer ID trust.
xattr -cr "$APP"
ENT="$ROOT/Packaging/deno.entitlements.plist"
codesign --force --sign - --entitlements "$ENT" "$APP/Contents/Resources/Tools/deno"
# yt-dlp is a PyInstaller single-file executable. Hardened Runtime makes
# macOS reject its Python shared library after extraction to the temp folder.
# Keep it ad-hoc signed for bundle integrity, but do not enable runtime hardening.
codesign --force --sign - "$APP/Contents/Resources/Tools/yt-dlp"
codesign --force --sign - "$APP/Contents/Resources/Tools/ffmpeg"
codesign --force --sign - "$APP/Contents/MacOS/YTDock"
codesign --force --sign - "$APP"
codesign --verify --deep --strict --verbose=4 "$APP"

{
  echo "YTDock $VERSION"
  echo "Application architecture: native SwiftUI"
  echo "Release architecture: $ARCH"
  echo "Build UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Signing: ad-hoc (no Developer ID / no Apple notarization)"
  echo "Host: $(sw_vers -productVersion) / $(uname -m)"
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Source commit: $(git -C "$ROOT" rev-parse HEAD)"
  fi
  echo "Executable: $(file "$APP/Contents/MacOS/YTDock")"
  echo
  shasum -a 256 \
    "$APP/Contents/MacOS/YTDock" \
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

# UDZO + max zlib level keeps the runtime self-contained while reducing download size.
hdiutil create -volname "YTDock $VERSION ($ARCH)" -srcfolder "$STAGE" -ov -format UDZO -imagekey zlib-level=9 "$DMG"
codesign --force --sign - "$DMG" 2>/dev/null || true
(
  cd "$BUILD"
  shasum -a 256 "YTDock-$VERSION-$ARCH.dmg" > "SHA256SUMS-$ARCH.txt"
)

echo
echo "Created: $DMG"
echo "Architecture: $ARCH"
echo "UI: native SwiftUI"
echo "This build is ad-hoc signed, not Developer ID signed, and not Apple notarized."
