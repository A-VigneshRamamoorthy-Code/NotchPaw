import CoreGraphics
import Foundation

/// One sampled instant of an animal's gesture.
public struct GestureSample: Equatable, Sendable {
    /// World-space point the limb tip should chase.
    public var target: CGPoint
    /// Along-reach stretch (1 = neutral, >1 during a fast strike).
    public var stretch: Double
    /// Rotation bias: negative during anticipation pull-back, positive on strike.
    public var windup: Double
    public init(target: CGPoint, stretch: Double, windup: Double) {
        self.target = target; self.stretch = stretch; self.windup = windup
    }
}

/// Pure animal-gesture generator. Because everything is driven by `time` (not by
/// cursor movement), the creature keeps acting — batting, swaying, hopping — even
/// when the cursor is perfectly still. Follows the motion-design "Playful" recipe:
/// anticipation → strike (overshoot) → follow-through → brief pause, plus an
/// always-on ambient sway.
public enum Gesture {
    public static func sample(style: PawStyle, cursor: CGPoint, shoulder: CGPoint, time: Double) -> GestureSample {
        let b = style.behavior
        let dx = Double(cursor.x - shoulder.x)
        let dy = Double(cursor.y - shoulder.y)
        var dist = (dx * dx + dy * dy).squareRoot()
        let ux: Double, uy: Double
        if dist < 1 { ux = 0; uy = -1; dist = 1 } else { ux = dx / dist; uy = dy / dist }
        let reach = min(dist, b.maxReach)
        let perpx = -uy, perpy = ux

        let cyc = max(0.05, b.cycle)
        let phase = (time / cyc).truncatingRemainder(dividingBy: 1)
        let (strike, slope) = strikeWave(phase: phase, taps: b.taps,
                                         sharp: b.strikeSharp, antic: b.anticipation)

        // Reach toward (and a touch past) the cursor; hover at `reachBias` between.
        let alongFrac = b.reachBias + (1.0 - b.reachBias) * strike
        let along = reach * alongFrac

        // Continuous side-to-side sway + always-on idle sway (never frozen).
        let sway = b.perpAmp * sin(2 * .pi * phase * b.perpCycles)
                 + b.idleSway * sin(time * 2.2 + 1.3)

        // Vertical hop (world space) — bunnies bounce.
        let hop = b.bobAmp * hopWave(phase)

        let tx = Double(shoulder.x) + ux * along + perpx * sway
        let ty = Double(shoulder.y) + uy * along + perpy * sway + hop

        let stretch = 1 + min(0.3, max(0, slope) * 0.25)
        return GestureSample(target: CGPoint(x: tx, y: ty), stretch: stretch, windup: strike)
    }

    // MARK: - Strike waveform

    /// Returns the strike value and its slope at `phase`. The value runs roughly
    /// from `-antic` (pull-back) through `~1+overshoot` (strike) back to 0 (rest).
    static func strikeWave(phase: Double, taps: Int, sharp: Double, antic: Double) -> (value: Double, slope: Double) {
        let delta = 0.004
        let v = rawStrike(phase, taps: taps, sharp: sharp, antic: antic)
        let vNext = rawStrike((phase + delta).truncatingRemainder(dividingBy: 1),
                              taps: taps, sharp: sharp, antic: antic)
        return (v, (vNext - v) / delta)
    }

    private static func rawStrike(_ p: Double, taps: Int, sharp: Double, antic: Double) -> Double {
        if taps >= 2 {
            // Two quick strikes packed into the first 70% of the cycle, then rest.
            guard p < 0.7 else { return 0 }
            let local = ((p / 0.7) * 2).truncatingRemainder(dividingBy: 1)
            return singleStrike(local, sharp: sharp, antic: antic * 0.7)
        }
        return singleStrike(p, sharp: sharp, antic: antic)
    }

    private static func singleStrike(_ p: Double, sharp: Double, antic: Double) -> Double {
        if p < 0.12 { return -antic * easeInQuad(p / 0.12) }            // anticipation
        if p < 0.34 { return mix(-antic, 1, easeOutBack((p - 0.12) / 0.22, sharp)) } // strike
        if p < 0.62 { return mix(1, 0, easeInOutQuad((p - 0.34) / 0.28)) }            // follow-through
        return 0                                                                     // pause
    }

    private static func hopWave(_ p: Double) -> Double {
        // Quick up, soft down — a bouncy hop with a little airtime.
        let up = sin(.pi * min(1, p / 0.45))
        return max(0, up)
    }

    // MARK: - Easing

    static func easeInQuad(_ t: Double) -> Double { t * t }

    static func easeInOutQuad(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    /// Overshooting ease-out. `s` controls the overshoot magnitude.
    static func easeOutBack(_ t: Double, _ s: Double) -> Double {
        let c1 = s
        let c3 = c1 + 1
        let u = t - 1
        return 1 + c3 * (u * u * u) + c1 * (u * u)
    }

    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}
