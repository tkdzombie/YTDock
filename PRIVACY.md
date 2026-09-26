# YTDock 1.1 Privacy

YTDock is designed to keep its own persistent footprint minimal.

- No account system, telemetry, analytics, advertising SDK, crash-upload service, or tracking identifier is included.
- The download queue and entered URLs are session-only and are not written to a YTDock history database.
- yt-dlp cache is disabled with `--no-cache-dir`.
- Deno runtime cache is redirected to a per-process system temporary directory and removed when YTDock exits normally.
- Temporary thumbnails and diagnostic logs are stored in the system temporary directory and removed on normal exit.
- Browser cookies are read only when the user explicitly selects a browser in the UI. YTDock does not copy them into its own persistent store.
- Downloaded media is saved to the folder selected by the user and is intentionally not deleted when YTDock is removed.
- No LaunchAgent, daemon, privileged helper, kernel/system extension, login item, or YTDock Application Support directory is installed.

Deleting `YTDock.app` removes the application and its bundled runtime engines. macOS itself may retain normal operating-system metadata such as recent-item or Gatekeeper exception records.
