import AppKit
import NotchPawCore

/// Owns the overlay window + paw view and maps the global cursor into the
/// creature's coordinate space.
final class OverlayController {
    let window: OverlayWindow
    let pawView: PawView
    private(set) var geometry: NotchGeometry
    private var style: PawStyle
    private let notchMinX: CGFloat
    private let notchMaxX: CGFloat
    private let shoulderY: CGFloat
    private let activationRefY: CGFloat

    init(screen: NSScreen, style: PawStyle) {
        self.style = style
        let geo = OverlayController.computeGeometry(for: screen)
        self.geometry = geo
        let frame = OverlayController.windowFrame(for: screen, geometry: geo)
        self.window = OverlayWindow(contentRect: frame)

        // Notch span the shoulder may slide along (view coords), slightly inset.
        let inset: CGFloat = 14
        var minX = geo.notchRect.minX - frame.minX + inset
        var maxX = geo.notchRect.maxX - frame.minX - inset
        if maxX - minX < 30 {  // tiny / no notch → small central span
            let mid = geo.shoulder.x - frame.minX
            minX = mid - 40; maxX = mid + 40
        }
        self.notchMinX = minX
        self.notchMaxX = maxX
        // Anchor the limb base just ABOVE the visible top edge so it is always
        // clipped to a flush horizontal line where it crosses the edge, on both
        // sides, no matter how the arm tilts.
        self.shoulderY = frame.height + 16
        // Engagement is still judged from the notch line the user actually sees.
        self.activationRefY = geo.shoulder.y - frame.minY

        // The interactive notch zone: the notch cutout + a little below it. This
        // is the ONLY place the overlay claims clicks (everything else is
        // click-through), so it never blocks normal interaction.
        let zoneTop = frame.height
        let zoneBottom = (geo.shoulder.y - frame.minY) - 8
        let zone = CGRect(x: minX - 10, y: zoneBottom,
                          width: (maxX - minX) + 20, height: zoneTop - zoneBottom)

        self.pawView = PawView(frame: NSRect(origin: .zero, size: frame.size),
                               notchMinX: minX, notchMaxX: maxX, shoulderY: shoulderY,
                               notchZone: zone, style: style)
        window.contentView = pawView
    }

    func show() { window.orderFrontRegardless() }
    func close() { window.orderOut(nil); window.close() }

    func updateStyle(_ newStyle: PawStyle) {
        style = newStyle
        pawView.style = newStyle
    }

    /// Map a global cursor position into the view and update engagement.
    func handleMouseMoved(globalPoint p: CGPoint) {
        let frame = window.frame
        let v = CGPoint(x: p.x - frame.minX, y: p.y - frame.minY)
        // Distance to the nearest point of the notch span (where the arm emerges).
        let clampedX = min(max(v.x, notchMinX), notchMaxX)
        let d = hypot(v.x - clampedX, v.y - activationRefY)
        let engaged = d < CGFloat(style.behavior.activationRadius)
        pawView.target = v
        pawView.engaged = engaged
        if engaged { pawView.resume() }
    }

    static func computeGeometry(for screen: NSScreen) -> NotchGeometry {
        NotchGeometry.compute(screenFrame: screen.frame,
                              safeAreaTop: screen.safeAreaInsets.top,
                              auxLeft: screen.auxiliaryTopLeftArea,
                              auxRight: screen.auxiliaryTopRightArea)
    }

    static func windowFrame(for screen: NSScreen, geometry: NotchGeometry) -> NSRect {
        // Wide enough that the shoulder can slide across the notch and still reach
        // out fully on either side; tall enough for the longest tail. Dirty-rect
        // drawing keeps the larger size cheap.
        let f = screen.frame
        let width = min(f.width, geometry.notchRect.width + 560)
        let height: CGFloat = 340
        var x = geometry.shoulder.x - width / 2
        x = max(f.minX, min(x, f.maxX - width))
        let y = f.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
