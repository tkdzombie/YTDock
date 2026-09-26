# YTDock

A focused macOS video and audio download manager designed around a clean queue workflow, predictable downloads, and a portable footprint.

**YTDock is the application.** Its queue model, macOS interface, task state management, pause/resume behavior, build system, packaging, security checks, and release automation live in this repository. For extraction and media processing, YTDock integrates established third-party engines such as yt-dlp, Deno, and FFmpeg under their respective licenses.

> Current version: **1.1.0**  
> Free distribution: **ad-hoc signed; not Developer ID signed or Apple notarized**.

## Why YTDock

YTDock turns command-line download tooling into a macOS-first workflow:

- add one or many URLs to a visual queue;
- parse title, source, duration, and thumbnail before downloading;
- pause and resume the active transfer without rebuilding the queue;
- filter the current session by active, completed, or problem tasks;
- keep each queued task's selected quality and cookie profile predictable;
- see progress, transfer speed, total size, ETA, errors, and completion state;
- receive a native completion notification and reveal output in Finder;
- use 4K / 1080p / 720p / MP4 / audio-only presets without memorizing CLI flags;
- keep YTDock portable: no LaunchAgent, daemon, login item, privileged helper, telemetry, or YTDock history database.

The session queue is intentionally memory-only. Closing YTDock clears queue state and temporary thumbnails/logs; downloaded media remains in the folder chosen by the user.

## Smaller 1.1 downloads

YTDock 1.0 shipped one universal DMG that carried both Apple Silicon and Intel copies of large runtime components. 1.1 publishes two release assets instead:

- `YTDock-1.1.0-arm64.dmg` — Apple Silicon (M1/M2/M3/M4 and later)
- `YTDock-1.1.0-x86_64.dmg` — Intel Macs

The app launcher, Deno and FFmpeg are architecture-specific in each DMG. This avoids bundling a second unused architecture and substantially reduces download size compared with the 1.0 universal package. The official yt-dlp macOS standalone binary is kept intact.

## Architecture

```text
YTDock.app
├── NativeLauncher.swift        # native Mach-O entry point
├── app.js                      # YTDock macOS UI + queue/orchestration layer
└── Resources/Tools/
    ├── yt-dlp                  # extraction/download engine
    ├── deno                    # JS runtime used by supported extractors
    ├── ffmpeg                  # media merge/post-processing
```

Third-party engines remain third-party software. YTDock does not claim authorship of them; the product contribution is the macOS application and orchestration around them. See `THIRD_PARTY_NOTICES.md` and `docs/ARCHITECTURE.md`.

## GitHub release workflow

For an existing repository, update `VERSION`, commit/push, then run:

```zsh
./publish.command
```

A `v1.1.0` tag triggers GitHub Actions. The workflow builds and verifies both architectures separately, then publishes both DMGs plus SHA-256 and build metadata to one GitHub Release.

## Local macOS build

Build the current Mac architecture:

```zsh
./build.command
```

Or choose explicitly:

```zsh
./Scripts/build-macos.sh arm64
./Scripts/verify-release.sh arm64

./Scripts/build-macos.sh x86_64
./Scripts/verify-release.sh x86_64
```

Outputs are written under `build/free/<architecture>/`.

## Security and privacy

Runtime versions and upstream release hashes are pinned in `DEPENDENCIES.lock`. Release builds verify downloaded runtime assets before packaging. YTDock does not globally disable Gatekeeper and does not install persistent background components.

See `SECURITY.md`, `PRIVACY.md`, and `docs/GATEKEEPER.md`.

## Project authorship

YTDock application code, product design, packaging, and release automation are maintained by **tkdzombie**. Third-party components are credited separately and keep their own copyright/license terms.

No open-source license for YTDock's own source has been selected yet. Public source visibility does not transfer authorship of the YTDock project or the third-party components it bundles.
