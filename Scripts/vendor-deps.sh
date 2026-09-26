#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DEST="${1:-$ROOT/build/vendor/Tools}"
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
FP_ARM_SHA="bb2db6f5d8cef919da12fbf592119a987202a8c060a886f3cab091f9cab90b64"
FP_X64_SHA="fa3add0ce901f7241abe0dfc0155d958fc834aca3f8ce61f87cc712ae669c1e0"
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

# yt-dlp
fetch "https://github.com/yt-dlp/yt-dlp/releases/download/$YTDLP_VER/yt-dlp_macos" "$TMP/yt-dlp"
verify "$TMP/yt-dlp" "$YTDLP_SHA"
install -m 755 "$TMP/yt-dlp" "$DEST/yt-dlp"

# Deno: combine both macOS architectures into one universal executable.
for arch in arm64 x64; do
  if [[ "$arch" == arm64 ]]; then
    asset="deno-aarch64-apple-darwin.zip"
    want="$DENO_ARM_SHA"
  else
    asset="deno-x86_64-apple-darwin.zip"
    want="$DENO_X64_SHA"
  fi
  fetch "https://github.com/denoland/deno/releases/download/v$DENO_VER/$asset" "$TMP/$asset"
  verify "$TMP/$asset" "$want"
  mkdir -p "$TMP/deno-$arch"
  ditto -x -k "$TMP/$asset" "$TMP/deno-$arch"
done
xcrun lipo -create "$TMP/deno-arm64/deno" "$TMP/deno-x64/deno" -output "$DEST/deno"
chmod 755 "$DEST/deno"

# FFmpeg + ffprobe: combine both macOS architectures into universal executables.
for kind in ffmpeg ffprobe; do
  for arch in arm64 x64; do
    file="$kind-darwin-$arch"
    if [[ "$kind/$arch" == ffmpeg/arm64 ]]; then want="$FF_ARM_SHA"
    elif [[ "$kind/$arch" == ffmpeg/x64 ]]; then want="$FF_X64_SHA"
    elif [[ "$kind/$arch" == ffprobe/arm64 ]]; then want="$FP_ARM_SHA"
    else want="$FP_X64_SHA"
    fi
    fetch "https://github.com/eugeneware/ffmpeg-static/releases/download/$FF_TAG/$file" "$TMP/$file"
    verify "$TMP/$file" "$want"
    chmod 755 "$TMP/$file"
  done
  xcrun lipo -create "$TMP/$kind-darwin-arm64" "$TMP/$kind-darwin-x64" -output "$DEST/$kind"
  chmod 755 "$DEST/$kind"
done

# Preserve upstream license notices.
fetch "https://github.com/eugeneware/ffmpeg-static/releases/download/$FF_TAG/darwin-arm64.LICENSE" "$LIC/FFmpeg-darwin-arm64.LICENSE"
verify "$LIC/FFmpeg-darwin-arm64.LICENSE" "$FF_ARM_LIC_SHA"
fetch "https://github.com/eugeneware/ffmpeg-static/releases/download/$FF_TAG/darwin-x64.LICENSE" "$LIC/FFmpeg-darwin-x64.LICENSE"
verify "$LIC/FFmpeg-darwin-x64.LICENSE" "$FF_X64_LIC_SHA"
fetch "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$YTDLP_VER/THIRD_PARTY_LICENSES.txt" "$LIC/yt-dlp-THIRD_PARTY_LICENSES.txt"
fetch "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$YTDLP_VER/LICENSE" "$LIC/yt-dlp-LICENSE.txt"
fetch "https://raw.githubusercontent.com/denoland/deno/v$DENO_VER/LICENSE.md" "$LIC/Deno-LICENSE.md" || \
  fetch "https://raw.githubusercontent.com/denoland/deno/v$DENO_VER/LICENSE" "$LIC/Deno-LICENSE.txt"

printf '%s\n' "yt-dlp=$YTDLP_VER" "deno=$DENO_VER" "ffmpeg=6.1.1" > "$DEST/versions.txt"
file "$DEST/yt-dlp" "$DEST/deno" "$DEST/ffmpeg" "$DEST/ffprobe"
echo "Vendored and verified runtime tools: $DEST"
