# Building YTDock on macOS

## Requirements

- macOS 12 or newer
- Xcode Command Line Tools / Xcode toolchain
- Internet access while vendoring pinned runtime dependencies

Build for the current Mac:

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

Each build compiles a thin native launcher for the requested architecture, vendors the pinned yt-dlp, Deno, and FFmpeg runtime, verifies upstream SHA-256 values, ad-hoc signs executable code, creates a maximally compressed UDZO DMG, and writes per-architecture build metadata and checksums.

This free build is **not** Developer ID signed and **not** Apple notarized.
