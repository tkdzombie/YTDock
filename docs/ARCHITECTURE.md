# Downloader architecture

Downloader 2.0 separates **product behavior** from **runtime engines**.

## Downloader-owned application layer

`Sources/DownloaderApp.swift` is a native SwiftUI macOS application. It owns:

- window/UI layout and task cards;
- URL extraction, multi-link intake, clipboard discovery, and drag/drop;
- duplicate protection;
- per-task quality configuration snapshots;
- queue scheduling and state transitions;
- process lifecycle management;
- pause/resume/cancel/retry behavior;
- progress parsing and final-output tracking;
- human-readable error interpretation;
- session diagnostics;
- Finder integration and optional completion notifications.

The application currently schedules one engine process at a time. This is deliberate: predictable sequential processing makes pause/cancel semantics and site rate limits easier to reason about. Concurrency can be added later as a Downloader scheduler feature without changing the engine interface.

## Engine adapter

Downloader invokes bundled executables as subprocesses:

```text
Downloader Core
   ├── metadata request ──> yt-dlp ──> JSON metadata
   └── download request ─> yt-dlp ──> progress/output markers
                               ├── Deno (extractor JavaScript runtime)
                               └── FFmpeg (merge/post-processing when needed)
```

The engine boundary is intentionally narrow. yt-dlp does not own Downloader's queue UI/state model, and Downloader does not claim authorship of yt-dlp, Deno, or FFmpeg.

## Persistence model

Downloader intentionally keeps its task queue in memory. It does not create a Downloader history database or install background helpers. Temporary runtime/cache material is placed in the system temporary directory for the session. Downloaded user media is written only to the folder selected by the user.

This keeps uninstall behavior simple: remove `Downloader.app` to remove the application and its bundled runtime tools. User-downloaded media remains user data.

## Release layout

```text
Downloader.app
└── Contents/
    ├── MacOS/
    │   └── Downloader                 # native SwiftUI Mach-O
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

The current public workflow packages Apple Silicon (arm64) only, so users do not download an unused Intel runtime.
