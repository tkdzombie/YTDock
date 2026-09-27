# Repository structure

- `Sources/DownloaderApp.swift` — native SwiftUI application, queue state machine, process orchestration, and macOS integration.
- `Packaging/Downloader.app/` — app template, Info.plist, and icon.
- `Scripts/` — dependency vendoring, build, verification, and publishing helpers.
- `.github/` — Actions workflow and contribution templates.
- `docs/` — architecture, build, publishing, and Gatekeeper notes.
- `VERSION` — single source of truth for the app version.
- `DEPENDENCIES.lock` — pinned runtime versions and hashes.

Build outputs are written under `build/` and ignored by Git.
