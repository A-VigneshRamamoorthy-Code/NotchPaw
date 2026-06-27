import CoreGraphics
import Foundation
import NotchPawCore

// Minimal test harness — Command Line Tools ship no XCTest, so we run plain
// assertions and exit non-zero on failure.

var failures = 0
var checks = 0

func check(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("  ✗ FAIL: \(message)  (\(file):\(line))")
    }
}

func approx(_ a: Double, _ b: Double, _ tol: Double = 0.5) -> Bool { abs(a - b) <= tol }
func group(_ name: String, _ body: () -> Void) { print("• \(name)"); body() }

let shoulder = CGPoint(x: 360, y: 800)

func runEngine(_ engine: inout PawEngine, cursor: CGPoint, engaged: Bool, seconds: Double) {
    let dt = 1.0 / 60.0
    var t = 0.0
    while t < seconds { engine.update(cursor: cursor, engaged: engaged, dt: dt); t += dt }
}

func tipDistance(_ engine: PawEngine) -> Double {
    let tip = engine.state.tip
    return hypot(Double(tip.x) - Double(engine.shoulder.x), Double(tip.y) - Double(engine.shoulder.y))
}

group("Spring") {
    let spring = Spring(stiffness: 200, damping: 20)
    var p = 0.0, v = 0.0
    for _ in 0..<600 { (p, v) = spring.step(position: p, velocity: v, target: 100, dt: 1.0 / 60.0) }
    check(approx(p, 100), "spring converges (p=\(p))")
    var p2 = 0.0, v2 = 0.0
    let stiff = Spring(stiffness: 300, damping: 12)
    for _ in 0..<200 { (p2, v2) = stiff.step(position: p2, velocity: v2, target: 50, dt: 0.25) }
    check(!p2.isNaN && abs(p2) < 1000, "spring stable with large dt (p=\(p2))")
}

group("NotchGeometry") {
    let screen = CGRect(x: 0, y: 0, width: 1280, height: 832)
    let auxL = CGRect(x: 0, y: 800, width: 540, height: 32)
    let auxR = CGRect(x: 740, y: 800, width: 540, height: 32)
    let g = NotchGeometry.compute(screenFrame: screen, safeAreaTop: 32, auxLeft: auxL, auxRight: auxR)
    check(g.hasNotch, "detects notch between aux areas")
    check(approx(Double(g.notchRect.width), 200, 0.01), "notch width")
    check(approx(Double(g.shoulder.x), 640, 0.01), "shoulder centred")
    let f = NotchGeometry.compute(screenFrame: screen, safeAreaTop: 0, auxLeft: nil, auxRight: nil)
    check(!f.hasNotch, "fallback reports no hardware notch")
}

group("Gesture") {
    // Same cursor, two different times → different target ⇒ it animates while still.
    let cursor = CGPoint(x: 420, y: 660)
    let a = Gesture.sample(style: .cat, cursor: cursor, shoulder: shoulder, time: 0.10)
    let b = Gesture.sample(style: .cat, cursor: cursor, shoulder: shoulder, time: 0.45)
    let moved = hypot(Double(a.target.x - b.target.x), Double(a.target.y - b.target.y))
    check(moved > 8, "gesture target moves over time with a still cursor (Δ=\(moved))")
    for style in PawStyle.allCases {
        let s = Gesture.sample(style: style, cursor: cursor, shoulder: shoulder, time: 0.3)
        check(!s.target.x.isNaN && !s.target.y.isNaN, "\(style.rawValue) target finite")
        check(s.stretch >= 1 && s.stretch < 2, "\(style.rawValue) stretch sane (\(s.stretch))")
    }
    // Anticipation: windup is negative (pull-back) early in the cycle.
    let antic = Gesture.sample(style: .cat, cursor: cursor, shoulder: shoulder, time: 0.78 * 0.06)
    check(antic.windup < 0, "anticipation pulls back before the strike (\(antic.windup))")
}

group("PawEngine chain") {
    let hidden = PawEngine(shoulder: shoulder, style: .cat)
    check(Double(hidden.state.emergence) == 0, "starts hidden")
    check(hidden.isAtRest, "starts at rest")
    check(hidden.state.nodes.count == 4, "cat has a 4-node chain")

    var emerged = PawEngine(shoulder: shoulder, style: .cat)
    runEngine(&emerged, cursor: CGPoint(x: 420, y: 660), engaged: true, seconds: 1.5)
    check(Double(emerged.state.emergence) > 0.9, "emerges when engaged")
    check(tipDistance(emerged) > 20, "limb extends out of the notch (\(tipDistance(emerged)))")

    runEngine(&emerged, cursor: CGPoint(x: 420, y: 660), engaged: false, seconds: 3.0)
    check(Double(emerged.state.emergence) < 0.05, "retracts when disengaged")
    check(emerged.isAtRest, "returns to rest")
    check(tipDistance(emerged) < 6, "tip tucks back to the notch (\(tipDistance(emerged)))")

    for style in PawStyle.allCases {
        var e = PawEngine(shoulder: shoulder, style: style)
        for tgt in [CGPoint(x: 900, y: 500), CGPoint(x: 60, y: 700), CGPoint(x: 360, y: 560)] {
            runEngine(&e, cursor: tgt, engaged: true, seconds: 0.7)
        }
        let d = tipDistance(e)
        check(d <= style.behavior.maxReach + 6, "\(style.rawValue) within reach (\(d) / \(style.behavior.maxReach))")
        check(!e.state.tip.x.isNaN, "\(style.rawValue) tip finite")
        let expected = style.behavior.segments
        check(e.state.nodes.count == expected, "\(style.rawValue) has \(expected) nodes")
    }

    // Continuous motion: with a still cursor the tip keeps moving between frames.
    var live = PawEngine(shoulder: shoulder, style: .cat)
    runEngine(&live, cursor: CGPoint(x: 420, y: 660), engaged: true, seconds: 0.6)
    let t1 = live.state.tip
    live.update(cursor: CGPoint(x: 420, y: 660), engaged: true, dt: 1.0 / 60.0)
    runEngine(&live, cursor: CGPoint(x: 420, y: 660), engaged: true, seconds: 0.12)
    let t2 = live.state.tip
    check(hypot(Double(t1.x - t2.x), Double(t1.y - t2.y)) > 1.5, "tip keeps moving when cursor is still")

    // Dynamic shoulder: moving the anchor moves the base of the chain.
    var moving = PawEngine(shoulder: shoulder, style: .cat)
    runEngine(&moving, cursor: CGPoint(x: 420, y: 660), engaged: true, seconds: 0.5)
    moving.shoulder = CGPoint(x: 300, y: 800)
    moving.update(cursor: CGPoint(x: 420, y: 660), engaged: true, dt: 1.0 / 60.0)
    check(approx(Double(moving.state.nodes[0].x), 300, 0.5), "base node follows the shoulder")

    // Huge dt cannot explode.
    var huge = PawEngine(shoulder: shoulder, style: .fox)
    huge.update(cursor: CGPoint(x: 900, y: 400), engaged: true, dt: 5.0)
    check(tipDistance(huge) <= huge.style.behavior.maxReach + 6 && !huge.state.tip.x.isNaN, "huge dt safe")

    // Switching style at runtime rebuilds the chain (paw 4 ↔ tail 8 nodes).
    var sw = PawEngine(shoulder: shoulder, style: .cat)
    runEngine(&sw, cursor: CGPoint(x: 420, y: 660), engaged: true, seconds: 0.5)
    sw.style = .foxTail
    check(sw.state.nodes.count == 8, "switching to a tail grows the chain to 8 nodes")
    sw.update(cursor: CGPoint(x: 420, y: 660), engaged: true, dt: 1.0 / 60.0)
    check(!sw.state.tip.x.isNaN, "no crash / NaN after switching style")
    sw.style = .bunny
    check(sw.state.nodes.count == 4, "switching back to a paw shrinks the chain")
}

group("PawStyle") {
    for style in PawStyle.allCases {
        let b = style.behavior
        check(b.maxReach > 0, "\(style.rawValue) maxReach > 0")
        check(b.activationRadius >= b.maxReach, "\(style.rawValue) activation >= reach")
        check(b.segments >= 2, "\(style.rawValue) has a chain")
        check(b.catchRadius > 0, "\(style.rawValue) catchRadius > 0")
        check(!style.displayName.isEmpty && !style.emoji.isEmpty, "\(style.rawValue) has labels")
        check(PawStyle(rawValue: style.rawValue) == style, "\(style.rawValue) round-trips")
    }
    check(PawStyle.cat.appendage == .paw, "cat is a paw")
    check(PawStyle.catTail.appendage == .tail, "cat tail is a tail")
    check(PawStyle.allCases.count == 7, "seven styles")
}

group("PawRenderer icons") {
    for style in PawStyle.allCases {
        let img = PawRenderer.icon(for: style, size: CGSize(width: 34, height: 26))
        check(img != nil, "\(style.rawValue) icon renders")
        if let img { check(img.width > 0 && img.height > 0, "\(style.rawValue) icon has pixels") }
    }
    let app = PawRenderer.appIcon(pt: 256, scale: 1)
    check(app != nil, "cat-paw app icon renders")
    if let app { check(app.width == 256 && app.height == 256, "app icon is 256px") }
}

print("\n\(checks - failures)/\(checks) checks passed.")
if failures > 0 { print("❌ \(failures) failure(s)."); exit(1) }
print("✅ All checks passed.")
exit(0)
