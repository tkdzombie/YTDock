# YTDock 1.2 Privacy

YTDock is designed as a local macOS download manager.

- YTDock does not include analytics or advertising SDKs.
- YTDock does not create its own user account system.
- YTDock does not maintain a persistent YTDock download-history database.
- The task queue, diagnostics, clipboard discovery state, and completion-notification toggle are session-only.
- Temporary runtime cache is stored under the system temporary directory for the running session.
- Downloaded media is written to the folder explicitly selected by the user.
- Browser cookies are requested from yt-dlp only when the user chooses Safari, Chrome, or Firefox for a task. Selecting “不使用” does not request browser cookies.
- YTDock itself does not transmit telemetry to a YTDock server because no YTDock telemetry service exists.

Network requests are still made to the URLs/services required to resolve and download user-requested media, and bundled third-party tools perform those requests as part of their normal function.

Removing `YTDock.app` removes YTDock and its bundled runtime tools. Downloaded media is user data and is not deleted automatically.
