# Repository structure

- `Sources/YTDockApp.swift` — native SwiftUI application, queue state machine, process orchestration, and macOS integration.
- `Packaging/` — unsigned app template, icon, first-open note, and Deno runtime entitlement.
- `Scripts/` — dependency vendoring, macOS build, verification, update, and publishing helpers.
- `.github/` — CI/release workflow and contribution templates.
- `docs/` — product architecture, build, publishing, and Gatekeeper documentation.
- `VERSION` — single source of truth for application/release version.
- `DEPENDENCIES.lock` — pinned third-party runtime versions and upstream hashes.
- `COPYRIGHT.md` — authorship notice for YTDock-owned project work.
- `THIRD_PARTY_NOTICES.md` — separate attribution for bundled runtime software.

Generated apps, DMGs, checksums, and build metadata are written under `build/` and ignored by Git.
