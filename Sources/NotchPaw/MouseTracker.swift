import AppKit

/// Watches global + local mouse movement (event-driven, no polling) and reports
/// the cursor location in global screen coordinates. Mouse monitors do not
/// require any special permission.
final class MouseTracker {
    var onMove: ((CGPoint) -> Void)?

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
    }

    func stop() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
    }

    deinit { stop() }
}
