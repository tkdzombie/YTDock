# Building Downloader on macOS

## Requirements

- macOS 12 or newer
- Xcode Command Line Tools or Xcode with SwiftUI support
- Internet access while vendoring the pinned runtime dependencies

Build the Apple Silicon package:

```zsh
./Scripts/build-macos.sh arm64
./Scripts/verify-release.sh arm64
```

The DMG is written to `build/free/arm64/Downloader-<version>-arm64.dmg`. The build vendors yt-dlp, Deno, and FFmpeg, verifies SHA-256 values, signs the bundle ad-hoc, and creates a compressed DMG.

The free build is not Developer ID signed or Apple notarized.
