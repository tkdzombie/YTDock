# Gatekeeper note for the free build

YTDock's free distribution path uses ad-hoc code signing. It does not carry a Developer ID identity and is not Apple notarized.

On another Mac, Gatekeeper can therefore block the first launch. Do not disable Gatekeeper globally. Use Apple's normal per-app flow in **System Settings > Privacy & Security** after attempting to open YTDock once.

A future Developer ID + notarized build can use the same app layout, but requires Apple Developer Program credentials that are not part of this repository.
