import AppKit
import QuartzCore
import NotchPawCore

/// Draws the creature via the engine each frame. The display link runs **only
/// while the creature is active**; when it tucks away the link pauses, dropping
/// CPU to ~0. Only the creature's bounding box is invalidated each frame.
final class PawView: NSView {
    var engine: PawEngine
    var style: PawStyle {
        didSet { engine.style = style }
    }
    /// Cursor in this view's coordinate space.
    var target: CGPoint = .zero
    /// Whether the cursor is within the activation radius.
    var engaged: Bool = false

    /// Horizontal span of the notch (view coords) the shoulder may slide along.
    var notchMinX: CGFloat
    var notchMaxX: CGFloat
    /// Y of the notch's bottom edge (view coords).
    var shoulderY: CGFloat

    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var lastDirty: CGRect = .null
    private var shoulderX: CGFloat

    init(frame: NSRect, notchMinX: CGFloat, notchMaxX: CGFloat, shoulderY: CGFloat, style: PawStyle) {
        self.style = style
        self.notchMinX = notchMinX
        self.notchMaxX = notchMaxX
        self.shoulderY = shoulderY
        self.shoulderX = (notchMinX + notchMaxX) / 2
        self.engine = PawEngine(shoulder: CGPoint(x: shoulderX, y: shoulderY), style: style)
        super.init(frame: frame)
        clipsToBounds = true   // clip the limb base flush at the top edge
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { false }
    override var isOpaque: Bool { false }

    // The overlay window has `ignoresMouseEvents = true`, so this view never
    // receives or blocks mouse events — clicks always pass through to whatever
    // is underneath (apps, menu-bar items), even while the paw is animating.
    // The picker is opened from a non-consuming global monitor in AppDelegate.

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, link == nil {
            let l = displayLink(target: self, selector: #selector(tick(_:)))
            // Cap the frame rate: 30fps is smooth for a notch toy and roughly
            // halves active CPU vs 60fps.
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
            l.add(to: .main, forMode: .common)
            l.isPaused = true
            link = l
        }
    }

    /// Wake the display link so the creature starts animating.
    func resume() {
        guard let link else { return }
        if link.isPaused {
            lastTime = 0
            link.isPaused = false
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = lastTime > 0 ? now - lastTime : 1.0 / 60.0
        lastTime = now

        // Anchor the shoulder to the part of the notch nearest the cursor (eased).
        let desired = min(max(target.x, notchMinX), notchMaxX)
        shoulderX += (desired - shoulderX) * min(1, CGFloat(dt) * 12)
        engine.shoulder = CGPoint(x: shoulderX, y: shoulderY)

        let state = engine.update(cursor: target, engaged: engaged, dt: dt)
        let current = PawRenderer.bounds(of: state, style: style)
        setNeedsDisplay(current.union(lastDirty))
        lastDirty = current

        if !engaged && engine.isAtRest {
            link.isPaused = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)
        PawRenderer.draw(in: ctx, state: engine.state, style: style, shoulder: engine.shoulder)
    }
}
