# Publishing Downloader

1. Update source and documentation.
2. Set the semantic version in `VERSION`.
3. Commit and push `main` for an artifact build.
4. For a public release, create a matching tag such as `v2.0.0`.
5. GitHub Actions builds and verifies the Apple Silicon DMG, then publishes release assets for tags.

The free distribution uses ad-hoc signing. It does not provide Developer ID trust or Apple notarization.
