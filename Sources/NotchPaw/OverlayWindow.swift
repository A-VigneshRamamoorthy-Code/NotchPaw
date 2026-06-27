import AppKit

/// A transparent, click-through panel that floats above the menu bar so the paw
/// can be drawn around the notch. It never accepts mouse events, so it can
/// never interfere with the user's real interactions.
final class OverlayWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        // Sit just above the menu bar so we can draw around the notch.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // The window receives events, but PawView.hitTest only claims the small
        // notch zone — everywhere else stays click-through.
        ignoresMouseEvents = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
