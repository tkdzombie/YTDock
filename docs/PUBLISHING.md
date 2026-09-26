# Publishing with GitHub

## Existing YTDock repository

For normal updates:

1. change and test the source;
2. update `VERSION` (for this release: `1.1.0`);
3. update `CHANGELOG.md`;
4. commit and push `main`;
5. run `./publish.command`.

`publish.command` creates and pushes the matching `vX.Y.Z` tag. The tag triggers `.github/workflows/build-macos.yml`.

YTDock 1.1 builds two release assets independently:

- `YTDock-X.Y.Z-arm64.dmg` for Apple Silicon;
- `YTDock-X.Y.Z-x86_64.dmg` for Intel Macs.

The workflow verifies each app bundle/DMG, uploads temporary Actions artifacts, then a release job combines their checksums and publishes both DMGs plus `BUILDINFO-arm64.txt`, `BUILDINFO-x86_64.txt`, and `SHA256SUMS.txt` to the GitHub Release.

## First publication of a new repository

`setup-github.command` remains available for a fresh repository. It uses GitHub CLI browser authentication, initializes Git, creates the repository, pushes `main`, pushes the version tag, watches Actions, and prints the Release URL. No GitHub token is written into the repository.
