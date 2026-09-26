# Building YTDock on macOS

## Requirements

- macOS 12 or newer
- Xcode Command Line Tools / Xcode toolchain
- Internet access while vendoring pinned runtime dependencies

Run:

```zsh
./build.command
```

or:

```zsh
./Scripts/build-macos.sh
./Scripts/verify-release.sh
```

Output is written to `build/free/`.

The build creates a universal native launcher, vendors the pinned yt-dlp, Deno, FFmpeg and ffprobe binaries, verifies upstream SHA-256 values, ad-hoc signs the executable bundle, creates a DMG, and writes `BUILDINFO.txt` plus `SHA256SUMS.txt`.

This free build is **not** Developer ID signed and **not** Apple notarized.
