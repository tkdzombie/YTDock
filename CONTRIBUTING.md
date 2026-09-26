# Contributing

YTDock is intentionally small and privacy-oriented. Keep changes easy to audit.

## Before submitting a change

1. Do not commit cookies, passwords, tokens, private URLs, downloaded media, or signing keys.
2. Keep runtime dependencies pinned and update `DEPENDENCIES.lock` when versions or hashes change.
3. Build on macOS with `./Scripts/build-macos.sh`.
4. Verify with `./Scripts/verify-release.sh`.
5. Keep application data portable: do not add launch agents, daemons, privileged helpers, or persistent YTDock state outside the app bundle without documenting and justifying it first.

The free distribution build is ad-hoc signed and is not Apple-notarized.
