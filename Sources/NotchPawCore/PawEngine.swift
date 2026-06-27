import CoreGraphics
import Foundation

/// The animated state of the creature at one instant.
public struct PawState: Equatable, Sendable {
    /// Chain nodes from the pinned base (notch) to the tip.
    public var nodes: [CGPoint]
    /// Orientation of the paw head / tail tip (radians).
    public var tipRotation: CGFloat
    /// Squash scale applied on a catch (1 = normal).
    public var scale: CGFloat
    /// Along-axis stretch during a fast strike (1 = neutral).
    public var stretch: CGFloat
    /// How far the creature has emerged from the notch, 0 ... 1.
    public var emergence: CGFloat
    /// True on the frames the tip overlaps the cursor.
    public var caught: Bool

    public var tip: CGPoint { nodes.last ?? .zero }

    public init(nodeCount: Int, base: CGPoint) {
        nodes = Array(repeating: base, count: max(2, nodeCount))
        tipRotation = -.pi / 2
        scale = 1
        stretch = 1
        emergence = 0
        caught = false
    }
}

/// Pure simulation of a creature poking out of the notch. A Verlet rope (base
/// pinned at the notch, tip attracted to an animal-specific gesture target)
/// produces fluid follow-through for both paws (short chain) and tails (long
/// chain). Deterministic and AppKit-free so it can be unit-tested headlessly.
public struct PawEngine {
    public private(set) var state: PawState
    public var style: PawStyle {
        didSet { if style.behavior.segments != segCount { rebuild() } }
    }
    /// Anchor the limb extends from. Settable so the app can move it to the part
    /// of the notch nearest the cursor.
    public var shoulder: CGPoint

    private var prevNodes: [CGPoint]
    private var segCount: Int
    private var time: Double = 0
    private var emergence: Double = 0
    private var emergenceVel: Double = 0
    private var squish: Double = 0

    private static let squishDuration = 0.16

    public init(shoulder: CGPoint, style: PawStyle) {
        self.shoulder = shoulder
        self.style = style
        self.segCount = style.behavior.segments
        self.state = PawState(nodeCount: segCount, base: shoulder)
        self.prevNodes = state.nodes
    }

    public mutating func reset() {
        state = PawState(nodeCount: segCount, base: shoulder)
        prevNodes = state.nodes
        time = 0; emergence = 0; emergenceVel = 0; squish = 0
    }

    private mutating func rebuild() {
        segCount = style.behavior.segments
        state = PawState(nodeCount: segCount, base: shoulder)
        prevNodes = state.nodes
    }

    @discardableResult
    public mutating func update(cursor: CGPoint, engaged: Bool, dt: Double) -> PawState {
        let b = style.behavior
        let h = min(max(dt, 0), 1.0 / 30.0)
        time += h
        squish = max(0, squish - h)

        // --- Emergence (critically damped pop in/out of the notch) ---
        let emTarget: Double = engaged ? 1 : 0
        let emForce = 130.0 * (emTarget - emergence) - 22.0 * emergenceVel
        emergenceVel += emForce * h
        emergence = min(1, max(0, emergence + emergenceVel * h))
        state.emergence = CGFloat(emergence)

        // --- Gesture target (keeps moving even if the cursor is still) ---
        let g = Gesture.sample(style: style, cursor: cursor, shoulder: shoulder, time: time)
        let tipTarget = CGPoint(x: lerp(Double(shoulder.x), Double(g.target.x), emergence),
                                y: lerp(Double(shoulder.y), Double(g.target.y), emergence))
        state.stretch = CGFloat(1 + (g.stretch - 1) * emergence)

        // Segment rest length: paws use full reach (the arm may bend); tails are
        // sized to the actual reach so they extend & swish instead of bunching.
        // Segment rest length: scaled to the actual reach so the limb is SHORT
        // when the cursor is near the notch (instead of coiling) and only
        // extends to maxReach when the cursor is far.
        let cursorDist = hypot(Double(cursor.x - shoulder.x), Double(cursor.y - shoulder.y))
        let totalLen = style.appendage == .tail
            ? min(b.maxReach, max(110, cursorDist))
            : min(b.maxReach, max(46, cursorDist))
        let segLen = (totalLen / Double(segCount - 1)) * emergence
        let gravity = (style.appendage == .tail ? 90.0 : 60.0) * emergence

        // --- Verlet integrate the free nodes (base is pinned in constraints) ---
        var nodes = state.nodes
        nodes[0] = shoulder
        for i in 1..<segCount {
            let temp = nodes[i]
            var nx = Double(nodes[i].x), ny = Double(nodes[i].y)
            let vx = nx - Double(prevNodes[i].x)
            let vy = ny - Double(prevNodes[i].y)
            if i == segCount - 1 {
                // Tip: spring-damper toward the gesture target.
                let damp = max(0.0, 1.0 - b.tipDamping * h)
                let ax = b.tipStiffness * (Double(tipTarget.x) - nx)
                let ay = b.tipStiffness * (Double(tipTarget.y) - ny)
                nx += vx * damp + ax * h * h
                ny += vy * damp + ay * h * h - gravity * 0.3 * h * h
            } else {
                // Intermediate: trailing rope inertia + a little droop.
                nx += vx * b.chainDamping
                ny += vy * b.chainDamping - gravity * h * h
            }
            nodes[i] = CGPoint(x: nx, y: ny)
            prevNodes[i] = temp
        }

        // --- Distance constraints (Verlet rope). Move both nodes apart, except
        // the pinned base, so the tip's pull propagates and the chain extends. ---
        for _ in 0..<max(1, b.constraintIters) {
            nodes[0] = shoulder
            for i in 1..<segCount {
                var dx = Double(nodes[i].x - nodes[i - 1].x)
                var dy = Double(nodes[i].y - nodes[i - 1].y)
                var d = (dx * dx + dy * dy).squareRoot()
                if d < 1e-3 { dx = 0; dy = -1; d = 1 }   // seed a direction when collapsed
                let diff = (d - segLen) / d
                if i - 1 == 0 {
                    nodes[i] = CGPoint(x: Double(nodes[i].x) - dx * diff,
                                       y: Double(nodes[i].y) - dy * diff)
                } else {
                    let hx = dx * 0.5 * diff, hy = dy * 0.5 * diff
                    nodes[i - 1] = CGPoint(x: Double(nodes[i - 1].x) + hx,
                                           y: Double(nodes[i - 1].y) + hy)
                    nodes[i] = CGPoint(x: Double(nodes[i].x) - hx,
                                       y: Double(nodes[i].y) - hy)
                }
            }
            nodes[0] = shoulder
        }
        state.nodes = nodes

        // --- Derived pose ---
        let tip = nodes[segCount - 1]
        let prev = nodes[segCount - 2]
        state.tipRotation = CGFloat(atan2(Double(tip.y - prev.y), Double(tip.x - prev.x)))

        // Catch detection → squish.
        let cdx = Double(cursor.x - tip.x), cdy = Double(cursor.y - tip.y)
        let curDist = (cdx * cdx + cdy * cdy).squareRoot()
        if engaged && emergence > 0.5 && curDist < b.catchRadius {
            state.caught = true
            if squish <= 0 { squish = PawEngine.squishDuration }
        } else {
            state.caught = false
        }
        let squishAmt = squish > 0 ? sin((1 - squish / PawEngine.squishDuration) * .pi) : 0
        state.scale = CGFloat(1 - 0.30 * squishAmt)

        return state
    }

    /// True when fully tucked away and motionless — the renderer can stop the
    /// display link to drop CPU usage to zero.
    public var isAtRest: Bool {
        guard emergence < 0.02, squish <= 0 else { return false }
        let tip = state.nodes[segCount - 1]
        let d = hypot(Double(tip.x - shoulder.x), Double(tip.y - shoulder.y))
        return d < 2 && abs(emergenceVel) < 0.05
    }
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
