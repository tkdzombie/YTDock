# Changelog

## 1.1.0 — Product & Size Update

### Product workflow

- Added active-download pause and resume using process suspension/resumption.
- The remove action now cancels an active task and removes it cleanly after termination.
- Added session queue filters: All, Active, Completed, Issues.
- Added per-task quality and browser-cookie profile snapshots so queued tasks are predictable.
- Progress details now include reported total size in addition to speed and ETA.
- Added native completion notifications.
- Kept queue/history state memory-only so deleting the app remains sufficient for YTDock-owned persistent data.

### Distribution

- Replaced the 1.0 single universal DMG release with separate `arm64` and `x86_64` DMGs.
- Deno, FFmpeg, and the native launcher are architecture-specific in each release.
- Increased DMG zlib compression level.
- GitHub Actions now builds both architectures independently and publishes both to one Release.
- Build metadata and checksums are emitted per architecture and combined for the GitHub Release.
- Changed the bundle identifier to `com.tkdzombie.ytdock` and added explicit project authorship metadata.

### Documentation

- Reframed YTDock as an independent macOS application rather than a generic "yt-dlp GUI".
- Added architecture/authorship documentation and a copyright notice while keeping third-party attribution explicit.

## 1.0.0

- First GitHub-ready public release workflow.
- Visual queue, thumbnails, progress, retry/cancel, cookies, format presets, portable bundle model.
- Pinned and verified yt-dlp, Deno and FFmpeg runtime dependencies.
- Automated free-distribution DMG build and GitHub Release publishing.
