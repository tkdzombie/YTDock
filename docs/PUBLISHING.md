# Publishing YTDock

## Normal release flow

1. Update application code and documentation.
2. Set `VERSION` to the new semantic version (for this release: `1.2.0`).
3. Commit and push `main`.
4. Run `./publish.command`.
5. Confirm creation of the matching tag (`v1.2.0`).
6. GitHub Actions builds Apple Silicon and Intel DMGs independently.
7. The release job publishes both DMGs, combined SHA-256 checksums, and per-architecture BUILDINFO files.

A tag whose version does not match `VERSION` is rejected by the workflow.

## Free distribution boundary

The automated build uses ad-hoc code signing for bundle integrity only. It does not produce Developer ID trust or Apple notarization. No Apple credential, signing key, GitHub Personal Access Token, or app-specific password is stored in this repository.
