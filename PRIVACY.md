# Downloader 2.0 Privacy

Downloader is designed as a local macOS download manager.

- Downloader does not include analytics or advertising SDKs.
- Downloader does not create its own user account system.
- Downloader does not maintain a persistent Downloader download-history database.
- The task queue, diagnostics, clipboard discovery state, and completion-notification toggle are session-only.
- Temporary runtime cache is stored under the system temporary directory for the running session.
- Downloaded media is written to the folder explicitly selected by the user.
- Downloader does not read browser cookies or login sessions.
- Downloader itself does not transmit telemetry to a Downloader server because no Downloader telemetry service exists.

Network requests are still made to the URLs/services required to resolve and download user-requested media, and bundled third-party tools perform those requests as part of their normal function.

Removing `Downloader.app` removes Downloader and its bundled runtime tools. Downloaded media is user data and is not deleted automatically.
