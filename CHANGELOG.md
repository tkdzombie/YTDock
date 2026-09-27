# Changelog

## 2.0.0 — Downloader public-content release

- Renamed the product and bundle to Downloader.
- Focused the app on public, directly accessible media.
- Removed browser-cookie and login-session handling from the UI and engine command line.
- Added resumable downloads, automatic retries, format fallbacks, and duration checks.
- Published an Apple Silicon arm64 artifact to keep the distribution focused.

## 1.2.2 — Release verification fix

- Fixed Swift 6 concurrency errors in `FileHandle.readabilityHandler` and `Process.terminationHandler`.
- Process callbacks now capture immutable references and marshal state updates back to `MainActor`.
- Cleans callback handlers if the downloader process cannot be launched.
- Keeps the native SwiftUI architecture and arm64 release workflow.


## 1.2.0 — Native application update

### Product layer

- Replaced the JXA/osascript application UI with a native SwiftUI macOS application.
- Added a first-class Downloader queue/state engine for metadata parsing, waiting, download, pause, resume, cancel, retry, completion, and failure states.
- Added drag-and-drop URL intake directly on the main window.
- Kept clipboard discovery and multi-URL paste with active-task duplicate protection.
- Added per-task quality snapshots so later setting changes do not silently alter existing queued jobs.
- Added session-only completion notifications with explicit opt-in.
- Added native Finder reveal and output-folder selection.

### Error experience

- Added Downloader-owned error translation for common cases including login/bot verification, unavailable formats, unsupported URLs, HTTP 403/429, unavailable videos, and missing FFmpeg.
- Preserved raw engine output in a separate diagnostics sheet with a one-click copy action.

### Architecture and release engineering

- Removed `Sources/app.js` and the native-to-osascript launcher bridge.
- `Sources/DownloaderApp.swift` is now the real CFBundle executable source.
- Release verification explicitly rejects accidental inclusion of the legacy JXA application layer.
- Kept architecture-specific Apple Silicon and Intel DMGs introduced in 1.1.
- Kept yt-dlp, Deno, and FFmpeg pinned and verified before packaging.
- ffprobe remains intentionally excluded because Downloader does not invoke it.

## 1.1.0 — Product & Size Update

- Added pause/resume, filters, completion notifications, per-task profiles, duplicate protection, richer progress details, and improved queue behavior.
- Replaced the 1.0 single universal DMG release with separate `arm64` and `x86_64` DMGs.
- Removed unused ffprobe from release packages.
- Added architecture/product authorship documentation and separate third-party notices.

## 1.0.0

- First GitHub-ready release with automated macOS builds and Releases.
