# Publishing with GitHub

## First publication

This repository includes `setup-github.command` for a new GitHub repository.

If the folder is in `/Users/lazydog/Downloads/YTDock-1.0.0`, either double-click `setup-github.command` in Finder, or run:

```zsh
cd /Users/lazydog/Downloads/YTDock-1.0.0
./setup-github.command
```

The helper:

1. checks/installs GitHub CLI via Homebrew when available and you approve it;
2. opens GitHub's browser login if `gh` is not already authenticated;
3. initializes the local Git repository;
4. commits the source;
5. creates a public/private GitHub repository;
6. pushes `main`;
7. pushes the version tag from `VERSION` (`v1.0.0` initially);
8. watches GitHub Actions until the macOS build finishes;
9. prints the repository and Release URLs.

No GitHub token is written into this repository.

## Later releases

1. Make and test your code changes.
2. Change `VERSION`, for example from `1.0.0` to `1.0.1`.
3. Update `CHANGELOG.md`.
4. Commit and push `main`.
5. Double-click `publish.command`, or run:

```zsh
./publish.command
```

The script refuses to publish when the working tree is dirty, when local `main` differs from `origin/main`, or when the tag already exists.

Pushing `vX.Y.Z` triggers `.github/workflows/build-macos.yml`. On success, GitHub Actions builds the all-in-one macOS DMG and attaches the DMG, SHA-256 file, and build information to a GitHub Release.
