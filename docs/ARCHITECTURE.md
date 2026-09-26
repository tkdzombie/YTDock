# YTDock architecture

YTDock is an application layer, not a fork of yt-dlp.

## YTDock-owned application layer

The repository implements the macOS product experience:

- Cocoa/JXA interface and task cards;
- URL ingestion and duplicate prevention;
- session queue state machine;
- metadata/thumbnail orchestration;
- per-task quality/cookie snapshots;
- pause/resume/cancel/remove behavior;
- progress/ETA/size parsing and native completion notifications;
- portable temp/cache lifecycle;
- native launcher, app bundle, DMG packaging, verification, and GitHub release automation.

## External runtime layer

YTDock invokes separate executables for specialist work:

- yt-dlp: site extraction and media transfer;
- Deno: JavaScript runtime required by supported extraction paths;
- FFmpeg: merging/transcoding/post-processing;

These programs are not renamed or represented as YTDock-authored code. Release builds pin their versions, verify upstream SHA-256 hashes, preserve license notices, and package them as runtime dependencies.

This separation is intentional: YTDock can evolve its own workflow, UI, state model, and packaging independently while using proven media engines underneath.
