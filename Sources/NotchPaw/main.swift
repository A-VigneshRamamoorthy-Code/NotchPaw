import AppKit

let app = NSApplication.shared

// Hidden preview modes: render PNGs and exit (headless visual verification, no
// window server needed).  --render = static pose per style; --contact = an
// animation contact-sheet per style.
if let idx = CommandLine.arguments.firstIndex(of: "--render") {
    let outDir = CommandLine.arguments.indices.contains(idx + 1)
        ? CommandLine.arguments[idx + 1] : NSTemporaryDirectory() + "notchpaw-preview"
    PreviewRenderer.renderAll(to: outDir)
    exit(0)
}
if let idx = CommandLine.arguments.firstIndex(of: "--contact") {
    let outDir = CommandLine.arguments.indices.contains(idx + 1)
        ? CommandLine.arguments[idx + 1] : NSTemporaryDirectory() + "notchpaw-contact"
    PreviewRenderer.renderContact(to: outDir)
    exit(0)
}
if let idx = CommandLine.arguments.firstIndex(of: "--icons") {
    let outDir = CommandLine.arguments.indices.contains(idx + 1)
        ? CommandLine.arguments[idx + 1] : NSTemporaryDirectory() + "notchpaw-icons"
    PreviewRenderer.renderIcons(to: outDir)
    exit(0)
}
if let idx = CommandLine.arguments.firstIndex(of: "--appicon") {
    let outPath = CommandLine.arguments.indices.contains(idx + 1)
        ? CommandLine.arguments[idx + 1] : NSTemporaryDirectory() + "NotchPawIcon.png"
    let ok = PreviewRenderer.renderAppIcon(to: outPath)
    exit(ok ? 0 : 1)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
