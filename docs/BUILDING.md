# Building YTDock on macOS

## Requirements

- macOS 12 or newer
- Xcode Command Line Tools / Xcode toolchain with SwiftUI support
- Internet access while vendoring pinned runtime dependencies

Build for the current Mac architecture:

```zsh
./build.command
```

Or build a specific release architecture:

```zsh
./Scripts/build-macos.sh arm64
./Scripts/verify-release.sh arm64

./Scripts/build-macos.sh x86_64
./Scripts/verify-release.sh x86_64
```

Output is written to `build/free/<architecture>/`.

Each build:

1. compiles `Sources/YTDockApp.swift` into the real native app executable;
2. vendors pinned yt-dlp, Deno, and FFmpeg runtime assets;
3. verifies upstream SHA-256 values;
4. ad-hoc signs nested executable code and the app bundle;
5. verifies the bundle and rejects the legacy JXA application layer;
6. creates a compressed UDZO DMG;
7. writes build metadata and checksums.

This free build is **not** Developer ID signed and **not** Apple notarized.
