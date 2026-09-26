# Changelog

## 1.2.2 — Release Verification Fix

- Fixed a false-negative release verification on GitHub macOS runners.
- Replaced the `strings | grep -q` executable smoke test that could trigger `strings: failed to flush output` under `set -o pipefail`.
- The smoke check now scans the executable directly with `grep -a -F -q`, avoiding a producer/consumer pipe and its SIGPIPE behavior.
- Architecture checking now captures `file` output before matching, removing another unnecessary verification pipeline.
- No application feature or runtime-engine behavior changed from 1.2.1.

## 1.2.1 — Swift Concurrency Build Fix

- Fixed Swift 6 concurrency errors in `FileHandle.readabilityHandler` and `Process.terminationHandler`.
- Process callbacks now capture immutable references and marshal state updates back to `MainActor`.
- Cleans callback handlers if the downloader process cannot be launched.
- Keeps the 1.2 native SwiftUI architecture and split arm64/x86_64 release model unchanged.


## 1.2.0 — Native Application Update

### Product layer

- Replaced the JXA/osascript application UI with a native SwiftUI macOS application.
- Added a first-class YTDock queue/state engine for metadata parsing, waiting, download, pause, resume, cancel, retry, completion, and failure states.
- Added drag-and-drop URL intake directly on the main window.
- Kept clipboard discovery and multi-URL paste with active-task duplicate protection.
- Added per-task quality and browser-cookie snapshots so later setting changes do not silently alter existing queued jobs.
- Added session-only completion notifications with explicit opt-in.
- Added native Finder reveal and output-folder selection.

### Error experience

- Added YTDock-owned error translation for common cases including login/bot verification, unavailable formats, unsupported URLs, HTTP 403/429, unavailable videos, and missing FFmpeg.
- Preserved raw engine output in a separate diagnostics sheet with a one-click copy action.

### Architecture and release engineering

- Removed `Sources/app.js` and the native-to-osascript launcher bridge.
- `Sources/YTDockApp.swift` is now the real CFBundle executable source.
- Release verification explicitly rejects accidental inclusion of the legacy JXA application layer.
- Kept architecture-specific Apple Silicon and Intel DMGs introduced in 1.1.
- Kept yt-dlp, Deno, and FFmpeg pinned and verified before packaging.
- ffprobe remains intentionally excluded because YTDock does not invoke it.

## 1.1.0 — Product & Size Update

- Added pause/resume, filters, completion notifications, per-task profiles, duplicate protection, richer progress details, and improved queue behavior.
- Replaced the 1.0 single universal DMG release with separate `arm64` and `x86_64` DMGs.
- Removed unused ffprobe from release packages.
- Added architecture/product authorship documentation and separate third-party notices.

## 1.0.0

- First GitHub-ready release with automated macOS builds and Releases.
