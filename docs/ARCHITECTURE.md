# YTDock architecture

YTDock 1.2 separates **product behavior** from **runtime engines**.

## YTDock-owned application layer

`Sources/YTDockApp.swift` is a native SwiftUI macOS application. It owns:

- window/UI layout and task cards;
- URL extraction, multi-link intake, clipboard discovery, and drag/drop;
- duplicate protection;
- per-task quality/cookie configuration snapshots;
- queue scheduling and state transitions;
- process lifecycle management;
- pause/resume/cancel/retry behavior;
- progress parsing and final-output tracking;
- human-readable error interpretation;
- session diagnostics;
- Finder integration and optional completion notifications.

The application currently schedules one engine process at a time. This is deliberate: predictable sequential processing makes pause/cancel semantics and site rate limits easier to reason about. Concurrency can be added later as a YTDock scheduler feature without changing the engine interface.

## Engine adapter

YTDock invokes bundled executables as subprocesses:

```text
YTDock Core
   ├── metadata request ──> yt-dlp ──> JSON metadata
   └── download request ─> yt-dlp ──> progress/output markers
                               ├── Deno (extractor JavaScript runtime)
                               └── FFmpeg (merge/post-processing when needed)
```

The engine boundary is intentionally narrow. yt-dlp does not own YTDock's queue UI/state model, and YTDock does not claim authorship of yt-dlp, Deno, or FFmpeg.

## Persistence model

YTDock intentionally keeps its task queue in memory. It does not create a YTDock history database or install background helpers. Temporary runtime/cache material is placed in the system temporary directory for the session. Downloaded user media is written only to the folder selected by the user.

This keeps uninstall behavior simple: remove `YTDock.app` to remove the application and its bundled runtime tools. User-downloaded media remains user data.

## Release layout

```text
YTDock.app
└── Contents/
    ├── MacOS/
    │   └── YTDock                 # native SwiftUI Mach-O
    └── Resources/
        ├── Tools/
        │   ├── yt-dlp
        │   ├── deno
        │   └── ffmpeg
        ├── DEPENDENCIES.lock
        ├── SECURITY.md
        ├── PRIVACY.md
        └── THIRD_PARTY_NOTICES.md
```

Apple Silicon and Intel are packaged into separate DMGs so large Deno/FFmpeg runtime binaries are not duplicated for users who only need one architecture.
