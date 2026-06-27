import AppKit

/// Watches global + local mouse movement and right-clicks (event-driven, no
/// polling) and reports them in global screen coordinates. Global monitors
/// OBSERVE events without consuming them, so they never block the underlying
/// app. Mouse monitors do not require any special permission.
final class MouseTracker {
    var onMove: ((CGPoint) -> Void)?
    /// Fired on a right-click (or ctrl-click). Does not consume the event.
    var onContextClick: ((CGPoint) -> Void)?

    private var monitors: [Any] = []

    func start() {
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: moveMask, handler: { [weak self] _ in
            self?.onMove?(NSEvent.mouseLocation)
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: moveMask, handler: { [weak self] e in
            self?.onMove?(NSEvent.mouseLocation)
            return e
        }) { monitors.append(m) }

        let clickMask: NSEvent.EventTypeMask = [.rightMouseUp]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: clickMask, handler: { [weak self] _ in
            self?.onContextClick?(NSEvent.mouseLocation)
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: clickMask, handler: { [weak self] e in
            self?.onContextClick?(NSEvent.mouseLocation)
            return e
        }) { monitors.append(m) }
    }

    func stop() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
    }

    deinit { stop() }
}
