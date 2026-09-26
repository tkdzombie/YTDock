# YTDock 1.2 Security Model — free distribution

## What the project does

- Compiles a native SwiftUI application from source on the macOS build runner.
- Pins runtime engine versions and SHA-256 values in `DEPENDENCIES.lock`.
- Verifies vendored yt-dlp, Deno, and FFmpeg release assets before packaging.
- Ad-hoc signs nested executables and the app bundle, then verifies the resulting code-signature structure.
- Keeps Deno's Hardened Runtime JIT exception scoped to the Deno executable rather than the YTDock main executable.
- Does not install LaunchAgents, daemons, privileged helpers, kernel/system extensions, or a YTDock history database.
- Does not globally disable Gatekeeper.
- Keeps the diagnostic log in memory instead of writing a persistent YTDock log database.

## Bundled runtime software

YTDock currently packages:

- yt-dlp 2026.08.19;
- Deno 2.9.7;
- FFmpeg 6.1.1 static builds from the pinned release source documented in `DEPENDENCIES.lock`.

ffprobe is intentionally not bundled because the application does not invoke it.

## Free distribution limitation

Ad-hoc signing is **not** Developer ID signing. The project cannot claim Apple notarization without an eligible Apple Developer Program identity and a successful notarization submission. Gatekeeper can therefore require the normal per-app manual approval flow on first launch.

Do not disable Gatekeeper globally for YTDock. See `docs/GATEKEEPER.md`.
