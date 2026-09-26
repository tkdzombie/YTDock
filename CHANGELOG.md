# Changelog

## 1.0.0

- Refined native macOS-style queue UI with light/dark system colors and SF Symbols.
- Multi-link queue with metadata parsing, thumbnails, progress, speed, ETA, cancel, retry, remove and Finder reveal.
- Quality presets for MP4, 4K, 1080p, 720p and audio-only downloads.
- Optional Safari, Chrome and Firefox cookie access through yt-dlp.
- Added pinned Deno runtime for modern yt-dlp JavaScript extraction support.
- Added pinned FFmpeg/ffprobe runtime so high-quality split video/audio streams can be merged without Homebrew.
- Added SHA-256 verification before first-run fallback components are used.
- Disabled yt-dlp cache and redirected Deno cache/logs/thumbnails to temporary storage.
- Added About/Security diagnostics, privacy statement, dependency lock and third-party notices.
- Added zero-membership macOS release pipeline: universal Swift launcher, vendored dependencies, ad-hoc signing, DMG, checksums and GitHub Actions/Release automation.
- Added repository bootstrap/publishing helpers for one-command GitHub creation, tag publishing, Actions build watching and automatic GitHub Release assets.
- No background agent, daemon, login item, privileged helper or persistent YTDock Application Support directory.
