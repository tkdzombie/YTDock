# YTDock 1.1 Security Model — free distribution

## Distribution model

YTDock's free build is a normal macOS application bundle with a native Swift Mach-O launcher. Tagged GitHub Releases publish separate Apple Silicon (`arm64`) and Intel (`x86_64`) DMGs so each user receives only the runtime architecture they need.

The free release path uses **ad-hoc code signing**. This gives executable code a coherent local signature structure, but it is **not** a Developer ID signature and does **not** create Apple trust or a notarization ticket.

## No privileged or persistent service installation

YTDock does not install LaunchAgents/LaunchDaemons, login items, privileged helpers, kernel/system extensions, a persistent YTDock Application Support database, telemetry, analytics, or advertising SDKs.

The yt-dlp cache is disabled. Deno cache, thumbnails, and diagnostic logs are directed to system temporary storage. The visible queue is session-only and is not written to disk by YTDock.

## Dependency integrity and minimization

Pinned hashes are recorded in `DEPENDENCIES.lock` for:

- yt-dlp 2026.08.19;
- Deno 2.9.7 for Apple Silicon and Intel;
- FFmpeg 6.1.1 static binaries for Apple Silicon and Intel.

YTDock 1.1 intentionally no longer bundles ffprobe because the application does not invoke it. Avoiding unused executable dependencies reduces release size and attack surface.

Each architecture build downloads only its matching Deno and FFmpeg assets, verifies SHA-256 before packaging, and ad-hoc signs executable code. Deno receives only the `com.apple.security.cs.allow-jit` entitlement required by its V8 JIT runtime.

GitHub Actions publishes per-architecture `BUILDINFO` files plus a combined `SHA256SUMS.txt` with each tagged Release.

## Gatekeeper limitation

Without Apple Developer Program membership, this project cannot obtain a Developer ID Application certificate or submit the app for Apple's standard notarization flow. Gatekeeper can therefore show an unidentified-developer / unable-to-check warning on first launch.

Do not disable Gatekeeper globally. If you trust the repository, workflow, source, and exact DMG checksum, use Apple's normal per-app **System Settings > Privacy & Security > Open Anyway** flow after the first blocked launch.

## Secrets

Do not commit browser cookies, GitHub tokens, passwords, `.p12` files, private keys, or downloaded private media. `.gitignore` excludes common signing-secret file types, but contributors should still review commits before pushing.
