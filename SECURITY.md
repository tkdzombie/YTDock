# YTDock 1.0 Security Model — free distribution

## Distribution model

YTDock's free build is structured as a normal macOS application bundle with a native universal Swift Mach-O launcher. Runtime dependencies are pinned to exact versions and verified with SHA-256 before packaging.

The free release path uses **ad-hoc code signing**. That gives the bundle a coherent local code-signature structure, but it is **not** a Developer ID signature and it does **not** create Apple trust or a notarization ticket.

## No privileged or persistent service installation

YTDock does not install:

- LaunchAgents or LaunchDaemons;
- login items;
- privileged helpers;
- kernel/system extensions;
- a persistent YTDock Application Support database;
- telemetry, analytics or advertising SDKs.

The yt-dlp cache is disabled. Deno cache, thumbnails and diagnostic logs are directed to system temporary storage.

## Dependency integrity

Pinned hashes are recorded in `DEPENDENCIES.lock` for:

- yt-dlp 2026.08.19;
- Deno 2.9.7 for Apple Silicon and Intel;
- FFmpeg/ffprobe 6.1.1 static binaries for Apple Silicon and Intel.

The macOS build combines architecture-specific Deno/FFmpeg executables into universal Mach-O binaries with `lipo`, then ad-hoc signs executable code. Deno receives only the `com.apple.security.cs.allow-jit` entitlement required by its V8 JIT runtime.

GitHub Actions uses the same build scripts and publishes `BUILDINFO.txt` plus `SHA256SUMS.txt` with each tagged Release.

## Gatekeeper limitation

Without Apple Developer Program membership, this project cannot obtain a Developer ID Application certificate or submit the app for Apple's standard notarization flow. Gatekeeper can therefore show an unidentified-developer / unable-to-check warning on first launch.

Do not disable Gatekeeper globally. If you trust the repository, source, workflow and exact DMG checksum, use Apple's normal per-app **System Settings > Privacy & Security > Open Anyway** flow after the first blocked launch.

## Secrets

Do not commit browser cookies, GitHub tokens, passwords, `.p12` files, private keys or downloaded private media. `.gitignore` excludes common signing-secret file types, but users are still responsible for reviewing commits before pushing.
