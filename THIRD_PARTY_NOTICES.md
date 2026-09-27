# Third-party notices

Downloader 2.0 release builds bundle runtime components that are separate projects from Downloader:

- **yt-dlp 2026.08.19** — extraction/download engine. Release assets and included third-party code remain subject to yt-dlp's upstream license and bundled third-party notices.
- **Deno 2.9.7** — JavaScript runtime used by supported extractor workflows; distributed under Deno's upstream license.
- **FFmpeg 6.1.1 static build** — asset sourced from the pinned `eugeneware/ffmpeg-static` release. FFmpeg and enabled libraries remain subject to FFmpeg/LGPL/GPL and component-specific license terms. The architecture-specific upstream license file is preserved in the release bundle.

Downloader does not claim authorship of these components. The build process additionally embeds the upstream license/notice files that it retrieves during dependency vendoring.

Downloader does not bundle ffprobe because the application does not invoke it.
