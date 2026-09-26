# YTDock

YTDock is a small macOS video/audio download manager built around **yt-dlp**, with a native macOS-style queue UI and an intentionally portable footprint.

> Current version: **1.0.0**  
> Free-distribution build: **ad-hoc signed, not Developer ID signed, not Apple notarized**.

## Features

- macOS queue UI with thumbnails, title/source metadata, progress, speed and ETA;
- paste multiple links at once, retry/cancel/remove, reveal completed files in Finder;
- MP4 / 4K / 1080p / 720p / audio-only presets;
- optional Safari / Chrome / Firefox cookies through yt-dlp;
- pinned yt-dlp, Deno, FFmpeg and ffprobe runtime dependencies;
- SHA-256 verification before dependencies are packaged;
- universal native launcher for Apple Silicon + Intel in the macOS build;
- no LaunchAgent, daemon, login item, privileged helper, telemetry or YTDock history database;
- deleting `YTDock.app` removes the application and its bundled engines; downloaded media remains in the folder chosen by the user.

## Repository layout

```text
YTDock/
├── .github/
│   ├── workflows/build-macos.yml
│   └── ISSUE_TEMPLATE/
├── Sources/                 # application source
│   ├── NativeLauncher.swift
│   └── app.js
├── Packaging/               # .app template, icon and entitlements
│   ├── YTDock.app/
│   ├── deno.entitlements.plist
│   └── 首次打开.txt
├── Scripts/                 # build / verification / GitHub automation
│   ├── build-macos.sh
│   ├── vendor-deps.sh
│   ├── verify-release.sh
│   ├── bootstrap-github.sh
│   └── publish-tag.sh
├── docs/
├── VERSION
├── DEPENDENCIES.lock
├── CHANGELOG.md
├── SECURITY.md
├── PRIVACY.md
└── THIRD_PARTY_NOTICES.md
```

## One-click GitHub setup

If you extracted this folder to:

```text
/Users/lazydog/Downloads/YTDock-1.0.0
```

then double-click **`setup-github.command`**, or run:

```zsh
cd /Users/lazydog/Downloads/YTDock-1.0.0
./setup-github.command
```

The helper signs you into GitHub with the official `gh` CLI, initializes Git, creates your repository, pushes `main`, creates `v1.0.0`, waits for GitHub Actions, and prints the final GitHub Release URL.

No Apple Developer membership or Apple credentials are required for this free publishing path. No GitHub token is stored in the repository.

See [`docs/PUBLISHING.md`](docs/PUBLISHING.md) for future releases.

## Local macOS build

Double-click **`build.command`**, or run:

```zsh
./Scripts/build-macos.sh
./Scripts/verify-release.sh
```

Output is written to `build/free/`.

## Gatekeeper

The free release path is not Apple-notarized. macOS may block the first launch on another Mac. Do **not** disable Gatekeeper globally. See [`docs/GATEKEEPER.md`](docs/GATEKEEPER.md) and [`SECURITY.md`](SECURITY.md).

## Privacy and third-party software

See [`PRIVACY.md`](PRIVACY.md), [`DEPENDENCIES.lock`](DEPENDENCIES.lock), and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## License

No project license has been selected yet. Publishing the source on GitHub does not by itself grant reuse rights. Choose a project license before inviting third-party redistribution or contributions that require one.


## Git commit identity

`setup-github.command` uses the currently authenticated GitHub username as the default Git commit name. If GitHub does not expose a public email address, it defaults to `<username>@users.noreply.github.com`. You can simply press Return to accept these defaults, or enter your preferred commit name/email. These values are stored only in this repository's local Git configuration.
