import AppKit
import NotchPawCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: OverlayController?
    private let tracker = MouseTracker()
    private var currentStyle: PawStyle = .cat
    private let defaultsKey = "NotchPaw.style"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon, no app menu
        currentStyle = loadStyle()
        rebuildOverlay()

        tracker.onMove = { [weak self] p in self?.handleMove(p) }
        tracker.onContextClick = { [weak self] p in self?.handleContextClick(p) }
        tracker.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        NSLog("NotchPaw running (%@). Right-click the notch to switch paws or quit.",
              currentStyle.displayName)
    }

    func applicationWillTerminate(_ notification: Notification) {
        tracker.stop()
    }

    // MARK: - Overlay lifecycle

    private func notchScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }

    private func rebuildOverlay() {
        controller?.close()
        guard let screen = notchScreen() else { return }
        let c = OverlayController(screen: screen, style: currentStyle)
        c.show()
        controller = c
    }

    @objc private func screensChanged() {
        rebuildOverlay()
    }

    // MARK: - Mouse handling

    private func handleMove(_ p: CGPoint) {
        controller?.handleMouseMoved(globalPoint: p)
        // Best-effort hint that you can right-click here. The overlay is fully
        // click-through, so this can't block anything; the foreground app may
        // override the cursor, which is fine.
        if controller?.isInNotchHotZone(globalPoint: p) == true {
            NSCursor.contextualMenu.set()
        }
    }

    /// Right-click → open the picker, but only inside the notch hot zone. The
    /// global monitor does NOT consume the click, so it never blocks the app
    /// underneath.
    private func handleContextClick(_ p: CGPoint) {
        guard controller?.isInNotchHotZone(globalPoint: p) == true else { return }
        NSApp.activate(ignoringOtherApps: true)
        showPicker()
    }

    // MARK: - Picker (no status item; opened by right-clicking the notch)

    private func showPicker() {
        // `at` is in screen coordinates when `in:` is nil; the cursor is at the
        // notch, so the menu drops down right from there.
        buildMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "NotchPaw", action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.attributedTitle = NSAttributedString(string: "Choose your critter", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        menu.addItem(header)
        menu.addItem(.separator())

        let iconSize = NSSize(width: 34, height: 26)
        for style in PawStyle.allCases {
            let item = NSMenuItem(title: style.displayName, action: #selector(selectStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.attributedTitle = title(for: style)
            item.state = (style == currentStyle) ? .on : .off
            if let cg = PawRenderer.icon(for: style, size: CGSize(width: iconSize.width, height: iconSize.height)) {
                item.image = NSImage(cgImage: cg, size: iconSize)
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit NotchPaw", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    /// Two-line styled title: bold name over a smaller grey tagline.
    private func title(for style: PawStyle) -> NSAttributedString {
        let s = NSMutableAttributedString(string: style.displayName, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ])
        s.append(NSAttributedString(string: "\n" + style.tagline, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return s
    }

    @objc private func selectStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = PawStyle(rawValue: raw) else { return }
        currentStyle = style
        controller?.updateStyle(style)
        saveStyle(style)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Persistence

    private func loadStyle() -> PawStyle {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let s = PawStyle(rawValue: raw) { return s }
        return .cat
    }

    private func saveStyle(_ style: PawStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: defaultsKey)
    }
}
