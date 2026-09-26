#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DEST="${1:-$ROOT/build/vendor/Tools}"
ARCH="${2:-$(uname -m)}"
[[ "$ARCH" == "arm64" || "$ARCH" == "x86_64" ]] || { echo "ARCH must be arm64 or x86_64" >&2; exit 2; }
LIC="$DEST/../Licenses"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DEST" "$LIC"

YTDLP_VER="2026.08.19"
YTDLP_SHA="0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202"
DENO_VER="2.9.7"
DENO_ARM_SHA="5cd46d6268f6f78f5d88bdc7159d20bd44cdaa4b3303474839f87ec6fe7ae25c"
DENO_X64_SHA="95daaff11c116a52ad54785e7914c8e9c9cdcaba793c5ed929c74ca2d8e6259a"
FF_TAG="b6.1.1"
FF_ARM_SHA="a90e3db6a3fd35f6074b013f948b1aa45b31c6375489d39e572bea3f18336584"
FF_X64_SHA="ebdddc936f61e14049a2d4b549a412b8a40deeff6540e58a9f2a2da9e6b18894"
FF_ARM_LIC_SHA="cb48bf09a11f5fb576cddb0431c8f5ed0a60157a9ec942adffc13907cbe083f2"
FF_X64_LIC_SHA="2e1d16c72fd74e12063776371da757322f8b77589386532f4fd8634bde7de1af"

fetch() {
  local url="$1" out="$2"
  echo "fetch: ${out:t}"
  curl -L --fail --retry 3 --connect-timeout 20 -o "$out" "$url"
}
verify() {
  local file="$1" want="$2"
  local got="$(shasum -a 256 "$file" | awk '{print $1}')"
  [[ "$got" == "$want" ]] || {
    echo "SHA-256 mismatch: ${file:t}" >&2
    echo "expected $want" >&2
    echo "actual   $got" >&2
    exit 9
  }
}

# yt-dlp official macOS standalone binary. Kept intact because its one-file payload
# is not safely reducible with lipo in the same way as a normal thin Mach-O.
fetch "https://github.com/yt-dlp/yt-dlp/releases/download/$YTDLP_VER/yt-dlp_macos" "$TMP/yt-dlp"
verify "$TMP/yt-dlp" "$YTDLP_SHA"
install -m 755 "$TMP/yt-dlp" "$DEST/yt-dlp"

# Architecture-specific Deno: this is one of the main size reductions introduced after 1.0.
if [[ "$ARCH" == "arm64" ]]; then
  DENO_ASSET="deno-aarch64-apple-darwin.zip"
  DENO_SHA="$DENO_ARM_SHA"
  FF_ARCH="arm64"
  FF_SHA="$FF_ARM_SHA"
  FF_LIC_SHA="$FF_ARM_LIC_SHA"
else
  DENO_ASSET="deno-x86_64-apple-darwin.zip"
  DENO_SHA="$DENO_X64_SHA"
  FF_ARCH="x64"
  FF_SHA="$FF_X64_SHA"
  FF_LIC_SHA="$FF_X64_LIC_SHA"
fi
fetch "https://github.com/denoland/deno/releases/download/v$DENO_VER/$DENO_ASSET" "$TMP/$DENO_ASSET"
verify "$TMP/$DENO_ASSET" "$DENO_SHA"
mkdir -p "$TMP/deno"
ditto -x -k "$TMP/$DENO_ASSET" "$TMP/deno"
install -m 755 "$TMP/deno/deno" "$DEST/deno"

# Architecture-specific FFmpeg. ffprobe is intentionally not bundled because YTDock does not invoke it.
fetch "https://github.com/eugeneware/ffmpeg-static/releases/download/$FF_TAG/ffmpeg-darwin-$FF_ARCH" "$TMP/ffmpeg"
verify "$TMP/ffmpeg" "$FF_SHA"
install -m 755 "$TMP/ffmpeg" "$DEST/ffmpeg"

# Preserve upstream notices in the bundle.
fetch "https://github.com/eugeneware/ffmpeg-static/releases/download/$FF_TAG/darwin-$FF_ARCH.LICENSE" "$LIC/FFmpeg-darwin-$FF_ARCH.LICENSE"
verify "$LIC/FFmpeg-darwin-$FF_ARCH.LICENSE" "$FF_LIC_SHA"
fetch "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$YTDLP_VER/THIRD_PARTY_LICENSES.txt" "$LIC/yt-dlp-THIRD_PARTY_LICENSES.txt"
fetch "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$YTDLP_VER/LICENSE" "$LIC/yt-dlp-LICENSE.txt"
fetch "https://raw.githubusercontent.com/denoland/deno/v$DENO_VER/LICENSE.md" "$LIC/Deno-LICENSE.md" || \
  fetch "https://raw.githubusercontent.com/denoland/deno/v$DENO_VER/LICENSE" "$LIC/Deno-LICENSE.txt"

printf '%s\n' \
  "architecture=$ARCH" \
  "yt-dlp=$YTDLP_VER" \
  "deno=$DENO_VER" \
  "ffmpeg=6.1.1" > "$DEST/versions.txt"
file "$DEST/yt-dlp" "$DEST/deno" "$DEST/ffmpeg"
echo "Vendored and verified runtime tools for $ARCH: $DEST"
