# Third-party software notices

YTDock is an independent project and is not affiliated with Downie, yt-dlp, Deno, FFmpeg, Apple, YouTube, or other supported websites.

Runtime components used by YTDock:

- **yt-dlp 2026.08.19** — upstream: `yt-dlp/yt-dlp`. yt-dlp's repository is published under the Unlicense; its standalone release binary also contains third-party components subject to their own terms. Refer to the upstream release/build notices for the exact bundled-license set.
- **Deno 2.9.7** — upstream: `denoland/deno`, MIT-licensed project; bundled/runtime dependencies retain their respective licenses.
- **FFmpeg / FFprobe 6.1.1 static builds** — assets sourced from `eugeneware/ffmpeg-static` release `b6.1.1`. FFmpeg and the enabled libraries are subject to FFmpeg/LGPL/GPL and component-specific license terms. The macOS build script downloads the upstream architecture-specific LICENSE files into the app's `Contents/Resources/Licenses` directory when these binaries are packaged.

The build scripts preserve upstream version pins and SHA-256 checksums. Users and redistributors are responsible for complying with the relevant third-party licenses and the terms of the websites from which they download media.
