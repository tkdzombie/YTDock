# Repository structure

The repository separates application source from packaging and publishing infrastructure:

- `Sources/` — human-edited application source.
- `Packaging/` — the unsigned `.app` template, icon, first-open note and runtime entitlements.
- `Scripts/` — dependency vendoring, macOS build, verification and GitHub release helpers.
- `.github/` — CI/release workflow and contribution templates.
- `docs/` — build, publishing and Gatekeeper documentation.
- `VERSION` — single source of truth for the application/release version.
- `DEPENDENCIES.lock` — pinned runtime versions and executable asset hashes.

Generated `.app`, `.dmg`, checksums and build metadata are written under `build/` and are intentionally ignored by Git.
