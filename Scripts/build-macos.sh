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

BUILD="$ROOT/build/free"
APP="$BUILD/YTDock.app"
STAGE="$BUILD/dmg-root"
DMG="$BUILD/YTDock-$VERSION.dmg"
TEMPLATE="$ROOT/Packaging/YTDock.app"

rm -rf "$BUILD"
mkdir -p "$BUILD" "$STAGE"
cp -R "$TEMPLATE" "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Tools"
sed "s/__YTDock_VERSION__/$VERSION/g" "$ROOT/Sources/app.js" > "$APP/Contents/Resources/app.js"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

# Native universal Mach-O launcher.
mkdir -p "$BUILD/launcher"
xcrun --sdk macosx swiftc -O -target arm64-apple-macos12.0 "$ROOT/Sources/NativeLauncher.swift" -o "$BUILD/launcher/YTDock-arm64"
xcrun --sdk macosx swiftc -O -target x86_64-apple-macos12.0 "$ROOT/Sources/NativeLauncher.swift" -o "$BUILD/launcher/YTDock-x86_64"
xcrun lipo -create "$BUILD/launcher/YTDock-arm64" "$BUILD/launcher/YTDock-x86_64" -output "$APP/Contents/MacOS/YTDock"
chmod 755 "$APP/Contents/MacOS/YTDock"

# Pinned dependencies, verified before packaging.
"$ROOT/Scripts/vendor-deps.sh" "$APP/Contents/Resources/Tools"
cp "$ROOT/DEPENDENCIES.lock" "$APP/Contents/Resources/DEPENDENCIES.lock"
cp "$ROOT/PRIVACY.md" "$APP/Contents/Resources/PRIVACY.md"
cp "$ROOT/SECURITY.md" "$APP/Contents/Resources/SECURITY.md"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"

# Ad-hoc signatures: coherent code-signature structure, but NOT Developer ID trust.
xattr -cr "$APP"
ENT="$ROOT/Packaging/deno.entitlements.plist"
codesign --force --sign - --options runtime --entitlements "$ENT" "$APP/Contents/Resources/Tools/deno"
for exe in yt-dlp ffmpeg ffprobe; do
  codesign --force --sign - --options runtime "$APP/Contents/Resources/Tools/$exe"
done
codesign --force --sign - --options runtime "$APP/Contents/MacOS/YTDock"
codesign --force --sign - --options runtime "$APP"
codesign --verify --deep --strict --verbose=4 "$APP"

# Build information makes every artifact auditable.
{
  echo "YTDock $VERSION"
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
    "$APP/Contents/Resources/Tools/ffmpeg" \
    "$APP/Contents/Resources/Tools/ffprobe"
} > "$BUILD/BUILDINFO.txt"

cp -R "$APP" "$STAGE/YTDock.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/Packaging/首次打开.txt" "$STAGE/首次打开.txt"
cp "$ROOT/PRIVACY.md" "$STAGE/PRIVACY.md"
cp "$ROOT/SECURITY.md" "$STAGE/SECURITY.md"
cp "$BUILD/BUILDINFO.txt" "$STAGE/BUILDINFO.txt"

hdiutil create -volname "YTDock $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
# Ad-hoc disk-image signing does not create Apple trust; it only gives the image a local code signature structure.
codesign --force --sign - "$DMG" 2>/dev/null || true
(
  cd "$BUILD"
  shasum -a 256 "YTDock-$VERSION.dmg" > SHA256SUMS.txt
)

echo
echo "Created: $DMG"
echo "This build is ad-hoc signed, not Developer ID signed, and not Apple notarized."
echo "Gatekeeper may require System Settings > Privacy & Security > Open Anyway on first launch."
