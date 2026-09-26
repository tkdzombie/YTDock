# Contributing

YTDock aims to stay small, auditable, portable, and macOS-focused.

The main application source is `Sources/YTDockApp.swift`. Keep the product/engine boundary described in `docs/ARCHITECTURE.md`.

Before submitting a change:

1. Do not commit cookies, passwords, tokens, private URLs, downloaded media, or signing keys.
2. Keep runtime dependencies pinned and update `DEPENDENCIES.lock` when versions or hashes change.
3. Keep YTDock-owned queue/history state portable; do not add LaunchAgents, daemons, privileged helpers, or persistent app databases without an explicit design decision.
4. Build the architecture you changed with `./Scripts/build-macos.sh <arch>` and verify it with `./Scripts/verify-release.sh <arch>`.
5. Preserve third-party attribution. Do not remove upstream notices or represent bundled engines as YTDock-authored code.

YTDock's own source does not yet have a formal open-source license. Discuss licensing/redistribution expectations before submitting changes intended for third-party reuse.
