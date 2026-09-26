# Third-party software notices

YTDock is an independent project and is not affiliated with Downie, yt-dlp, Deno, FFmpeg, Apple, YouTube, or other supported websites.

YTDock 1.1 release builds bundle these runtime components:

- **yt-dlp 2026.08.19** — upstream: `yt-dlp/yt-dlp`. The yt-dlp repository is published under the Unlicense; its standalone release binary also contains third-party components subject to their own terms. Refer to the upstream release/build notices for the exact bundled-license set.
- **Deno 2.9.7** — upstream: `denoland/deno`, MIT-licensed project; bundled/runtime dependencies retain their respective licenses.
- **FFmpeg 6.1.1 static build** — asset sourced from `eugeneware/ffmpeg-static` release `b6.1.1`. FFmpeg and enabled libraries are subject to FFmpeg/LGPL/GPL and component-specific license terms. The build script preserves the upstream architecture-specific license file in the app bundle.

YTDock 1.1 does not bundle ffprobe because the application does not invoke it.

The build scripts preserve upstream version pins and SHA-256 checksums. Third-party components remain the work of their respective authors and are distributed under their respective licenses.
