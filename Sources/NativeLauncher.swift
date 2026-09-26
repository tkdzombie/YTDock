import Foundation

// Minimal native CFBundleExecutable. The free build compiles this as a universal
// Mach-O and ad-hoc signs it. A future Developer ID build can sign the exact same
// bundle layout without changing application behavior.
let fm = FileManager.default
guard let resources = Bundle.main.resourceURL else {
    fputs("YTDock: unable to locate app resources\n", stderr)
    exit(70)
}
let script = resources.appendingPathComponent("app.js")
guard fm.fileExists(atPath: script.path) else {
    fputs("YTDock: app.js is missing\n", stderr)
    exit(70)
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
p.arguments = ["-l", "JavaScript", script.path, resources.path]
do {
    try p.run()
    p.waitUntilExit()
    exit(p.terminationStatus)
} catch {
    fputs("YTDock: failed to launch UI: \(error)\n", stderr)
    exit(71)
}
