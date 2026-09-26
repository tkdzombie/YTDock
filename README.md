# YTDock

A native macOS video and audio download manager focused on a clean queue workflow, understandable errors, privacy, and a portable install.

> Current version: **1.2.1**  
> Distribution: **ad-hoc signed; not Developer ID signed or Apple notarized**.

## What YTDock contributes

YTDock is not a fork of yt-dlp and does not claim authorship of third-party download/media engines. The application layer in this repository is YTDock's own product work:

- native SwiftUI interface and macOS interaction model;
- URL intake, duplicate protection, drag-and-drop, clipboard detection, and per-task profiles;
- queue scheduling and task state machine;
- pause/resume/cancel/retry orchestration;
- progress, speed, size, ETA, thumbnails, Finder reveal, and optional completion notifications;
- friendly error translation for common login, format, HTTP, and availability failures;
- privacy/portability model with no YTDock background daemon or history database;
- reproducible dependency pinning, SHA-256 verification, architecture-specific packaging, and GitHub release automation.

For extraction and media processing, YTDock invokes bundled copies of **yt-dlp**, **Deno**, and **FFmpeg** under their respective licenses. Think of these as runtime engines behind the YTDock application, not the YTDock UI or product layer.

## Highlights in 1.2

- **Native SwiftUI application** — the previous JXA/osascript UI layer has been removed.
- **YTDock Core queue state machine** — parsing, waiting, downloading, paused, completed, failed, and cancelled are managed by the app.
- **Human-readable failures** — common engine errors are translated into actions a normal user can understand.
- **Drag links directly into the window** in addition to paste/clipboard intake.
- **Session-only completion notifications** — opt in from the main window; no persistent preference database is created by YTDock.
- **Per-task snapshots** — quality and browser-cookie choices are locked when each URL enters the queue.
- **Architecture-specific releases** — separate Apple Silicon and Intel DMGs avoid carrying a second Deno/FFmpeg architecture.

## Download workflow

```text
Paste / drag URLs
       ↓
YTDock URL intake + duplicate protection
       ↓
Metadata parsing
       ↓
Native task cards
       ↓
YTDock queue scheduler
       ↓
yt-dlp engine
       ↓
FFmpeg merge/post-processing when required
       ↓
Finder / completion notification
```

The queue is intentionally session-only. Closing YTDock clears queue state and temporary runtime cache. Downloaded media remains in the folder selected by the user.

## Release assets

GitHub Releases publish two DMGs:

- `YTDock-1.2.1-arm64.dmg` — Apple Silicon
- `YTDock-1.2.1-x86_64.dmg` — Intel Macs

Both are self-contained: the release build vendors yt-dlp, Deno, and FFmpeg before packaging.

## Build locally on macOS

```zsh
./build.command
```

Or explicitly:

```zsh
./Scripts/build-macos.sh arm64
./Scripts/verify-release.sh arm64

./Scripts/build-macos.sh x86_64
./Scripts/verify-release.sh x86_64
```

Outputs are written under `build/free/<architecture>/`.

## Publish a release

`VERSION` is the single source of truth. After committing and pushing your changes:

```zsh
./publish.command
```

A matching Git tag such as `v1.2.1` triggers GitHub Actions. The workflow builds both architectures, verifies them, creates combined SHA-256 checksums, and publishes one GitHub Release.

## Security and privacy

Runtime versions and upstream hashes are pinned in `DEPENDENCIES.lock`. Release builds verify downloaded runtime assets before they are placed in the app bundle. YTDock does not globally disable Gatekeeper and does not install LaunchAgents, daemons, privileged helpers, or a YTDock Application Support history database.

The free release is still **not Apple-trusted distribution**: without Developer ID and notarization, Gatekeeper may require Apple's normal per-app first-open approval flow.

See `SECURITY.md`, `PRIVACY.md`, `docs/ARCHITECTURE.md`, and `docs/GATEKEEPER.md`.

## Project authorship

YTDock application code, original UI/product design, orchestration, packaging, documentation, and release automation are maintained by **tkdzombie**. Third-party runtime software remains credited separately in `THIRD_PARTY_NOTICES.md` and the license files embedded in release builds.

YTDock's own source does not currently declare a general-purpose open-source license. Public visibility of the repository does not transfer authorship or erase third-party license obligations.
