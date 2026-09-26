# Repository structure

- `Sources/` — YTDock application source and native launcher.
- `Packaging/` — unsigned app template, icon, first-open note, and runtime entitlements.
- `Scripts/` — architecture-aware dependency vendoring, macOS build, verification, and GitHub helpers.
- `.github/` — CI/release workflow and contribution templates.
- `docs/` — architecture, build, publishing, and Gatekeeper documentation.
- `VERSION` — single source of truth for the application/release version.
- `DEPENDENCIES.lock` — pinned third-party runtime versions and upstream hashes.
- `COPYRIGHT.md` — authorship notice for YTDock's own project work.
- `THIRD_PARTY_NOTICES.md` — separate attribution for bundled runtime software.

Generated apps, DMGs, checksums, and build metadata are written under `build/` and ignored by Git.
