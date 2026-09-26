# What makes YTDock a product

YTDock intentionally uses mature third-party runtime engines instead of reimplementing site extraction and media codecs from scratch. That does not make the YTDock application a fork of those engines.

The product boundary is:

```text
User experience / macOS integration / queue behavior / error UX / packaging
                         = YTDock

URL extraction / site-specific download implementation
                         = yt-dlp

Extractor JavaScript runtime
                         = Deno

Media merge and post-processing
                         = FFmpeg
```

This separation lets YTDock focus engineering effort where a macOS user benefits directly: predictable workflows, understandable task state, safe packaging, a native interface, and recovery from common failures.

The engine adapter is deliberately narrow. Future YTDock releases can change scheduling, add new product capabilities, or support a different engine without redefining the rest of the application.

Project authorship and third-party authorship are documented separately in `COPYRIGHT.md` and `THIRD_PARTY_NOTICES.md`.
