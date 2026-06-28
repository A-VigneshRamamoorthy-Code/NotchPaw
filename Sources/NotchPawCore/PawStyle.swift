import Foundation

/// Plain RGBA colour (components in 0...1) so the core stays free of AppKit.
public struct RGBA: Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}

/// Colours used to render a creature.
public struct PawPalette: Equatable, Sendable {
    public var fur: RGBA
    public var pad: RGBA
    public var outline: RGBA
    /// Accent: inner-ear / claws / fox-tail tip / toe detail.
    public var accent: RGBA
    public init(fur: RGBA, pad: RGBA, outline: RGBA, accent: RGBA) {
        self.fur = fur; self.pad = pad; self.outline = outline; self.accent = accent
    }
}

/// What pokes out of the notch.
public enum Appendage: Equatable, Sendable { case paw, tail }

/// Behaviour parameters that give each animal its own personality. Most timing
/// values are tuned against the motion-design "Playful" archetype.
public struct PawBehavior: Equatable, Sendable {
    // Reach + chain (Verlet rope: base pinned at notch, tip chases the gesture).
    public var maxReach: Double          // full extension of the limb (pt)
    public var activationRadius: Double  // cursor proximity that wakes the creature
    public var segments: Int             // chain nodes incl. the pinned base
    public var tipStiffness: Double      // how hard the tip chases its target
    public var tipDamping: Double
    public var chainDamping: Double      // Verlet inertia (0.80 loose … 0.97 stiff)
    public var constraintIters: Int

    // Gesture loop (runs off a clock, so it animates even with a still cursor).
    public var cycle: Double             // seconds per gesture cycle
    public var taps: Int                 // strikes per cycle (cat 1, dog 2)
    public var reachBias: Double         // hover fraction of reach between strikes
    public var strikeSharp: Double       // overshoot of the strike (easeOutBack)
    public var anticipation: Double      // pull-back before a strike (fraction)
    public var perpAmp: Double           // continuous side-to-side sway (pt)
    public var perpCycles: Double        // sways per gesture cycle
    public var bobAmp: Double            // vertical hop (pt) — bunnies bounce
    public var idleSway: Double          // always-on micro sway so it's never frozen

    // Look.
    public var pawScale: Double
    public var catchRadius: Double

    public init(maxReach: Double, activationRadius: Double, segments: Int,
                tipStiffness: Double, tipDamping: Double, chainDamping: Double,
                constraintIters: Int, cycle: Double, taps: Int, reachBias: Double,
                strikeSharp: Double, anticipation: Double, perpAmp: Double,
                perpCycles: Double, bobAmp: Double, idleSway: Double,
                pawScale: Double, catchRadius: Double) {
        self.maxReach = maxReach; self.activationRadius = activationRadius
        self.segments = segments; self.tipStiffness = tipStiffness
        self.tipDamping = tipDamping; self.chainDamping = chainDamping
        self.constraintIters = constraintIters; self.cycle = cycle; self.taps = taps
        self.reachBias = reachBias; self.strikeSharp = strikeSharp
        self.anticipation = anticipation; self.perpAmp = perpAmp
        self.perpCycles = perpCycles; self.bobAmp = bobAmp; self.idleSway = idleSway
        self.pawScale = pawScale; self.catchRadius = catchRadius
    }
}

/// The selectable creature styles.
public enum PawStyle: String, CaseIterable, Sendable {
    case cat
    case blackCat = "black_cat"
    case dog, bunny, fox, bear
    case catTail = "cat_tail"
    case foxTail = "fox_tail"

    public var appendage: Appendage {
        switch self {
        case .catTail, .foxTail: return .tail
        default: return .paw
        }
    }

    public var displayName: String {
        switch self {
        case .cat: return "Cat"
        case .blackCat: return "Black cat"
        case .dog: return "Dog"
        case .bunny: return "Bunny"
        case .fox: return "Fox"
        case .bear: return "Bear"
        case .catTail: return "Cat tail"
        case .foxTail: return "Fox tail"
        }
    }

    public var emoji: String {
        switch self {
        case .cat: return "🐱"
        case .blackCat: return "🐈‍⬛"
        case .dog: return "🐶"
        case .bunny: return "🐰"
        case .fox: return "🦊"
        case .bear: return "🐻"
        case .catTail: return "🐈"
        case .foxTail: return "🦊"
        }
    }

    public var tagline: String {
        switch self {
        case .cat: return "Quick anticipatory bats."
        case .blackCat: return "Sleek, stealthy midnight swats."
        case .dog: return "Eager double-tap pawing."
        case .bunny: return "Bouncy little hops."
        case .fox: return "Sly creep, sudden pounce."
        case .bear: return "Slow, heavy arc swipes."
        case .catTail: return "A swishing, flicking tail."
        case .foxTail: return "A bushy white-tipped sway."
        }
    }

    public var behavior: PawBehavior {
        switch self {
        case .cat:
            return PawBehavior(maxReach: 150, activationRadius: 185, segments: 4,
                               tipStiffness: 320, tipDamping: 22, chainDamping: 0.80,
                               constraintIters: 3, cycle: 0.78, taps: 1, reachBias: 0.6,
                               strikeSharp: 1.7, anticipation: 0.34, perpAmp: 16,
                               perpCycles: 1, bobAmp: 0, idleSway: 5,
                               pawScale: 0.72, catchRadius: 24)
        case .blackCat:
            // Like the cat, but a longer creep and a sharper, snappier pounce.
            return PawBehavior(maxReach: 154, activationRadius: 190, segments: 4,
                               tipStiffness: 340, tipDamping: 21, chainDamping: 0.80,
                               constraintIters: 3, cycle: 0.84, taps: 1, reachBias: 0.55,
                               strikeSharp: 1.95, anticipation: 0.42, perpAmp: 14,
                               perpCycles: 1, bobAmp: 0, idleSway: 5,
                               pawScale: 0.74, catchRadius: 24)
        case .dog:
            return PawBehavior(maxReach: 140, activationRadius: 195, segments: 4,
                               tipStiffness: 230, tipDamping: 15, chainDamping: 0.79,
                               constraintIters: 3, cycle: 0.96, taps: 2, reachBias: 0.62,
                               strikeSharp: 1.5, anticipation: 0.22, perpAmp: 26,
                               perpCycles: 2, bobAmp: 8, idleSway: 7,
                               pawScale: 0.8, catchRadius: 28)
        case .bunny:
            return PawBehavior(maxReach: 138, activationRadius: 178, segments: 4,
                               tipStiffness: 280, tipDamping: 17, chainDamping: 0.80,
                               constraintIters: 3, cycle: 0.6, taps: 1, reachBias: 0.62,
                               strikeSharp: 1.6, anticipation: 0.18, perpAmp: 8,
                               perpCycles: 1, bobAmp: 30, idleSway: 4,
                               pawScale: 0.66, catchRadius: 22)
        case .fox:
            return PawBehavior(maxReach: 158, activationRadius: 215, segments: 4,
                               tipStiffness: 300, tipDamping: 20, chainDamping: 0.82,
                               constraintIters: 3, cycle: 1.5, taps: 1, reachBias: 0.5,
                               strikeSharp: 2.2, anticipation: 0.5, perpAmp: 18,
                               perpCycles: 1, bobAmp: 0, idleSway: 6,
                               pawScale: 0.74, catchRadius: 24)
        case .bear:
            return PawBehavior(maxReach: 132, activationRadius: 170, segments: 4,
                               tipStiffness: 150, tipDamping: 24, chainDamping: 0.86,
                               constraintIters: 4, cycle: 1.7, taps: 1, reachBias: 0.62,
                               strikeSharp: 1.2, anticipation: 0.28, perpAmp: 30,
                               perpCycles: 1, bobAmp: 0, idleSway: 6,
                               pawScale: 0.96, catchRadius: 32)
        case .catTail:
            return PawBehavior(maxReach: 168, activationRadius: 195, segments: 8,
                               tipStiffness: 180, tipDamping: 14, chainDamping: 0.92,
                               constraintIters: 4, cycle: 1.6, taps: 1, reachBias: 0.95,
                               strikeSharp: 1.4, anticipation: 0.2, perpAmp: 52,
                               perpCycles: 1.5, bobAmp: 0, idleSway: 16,
                               pawScale: 0.7, catchRadius: 26)
        case .foxTail:
            return PawBehavior(maxReach: 176, activationRadius: 205, segments: 8,
                               tipStiffness: 150, tipDamping: 15, chainDamping: 0.93,
                               constraintIters: 4, cycle: 2.0, taps: 1, reachBias: 0.95,
                               strikeSharp: 1.3, anticipation: 0.2, perpAmp: 60,
                               perpCycles: 1.25, bobAmp: 0, idleSway: 18,
                               pawScale: 0.9, catchRadius: 28)
        }
    }

    public var palette: PawPalette {
        switch self {
        case .cat, .catTail:
            return PawPalette(fur: RGBA(0.55, 0.55, 0.60), pad: RGBA(1.0, 0.62, 0.72),
                              outline: RGBA(0.17, 0.17, 0.19), accent: RGBA(0.38, 0.38, 0.43))
        case .blackCat:
            // Inky-black fur, dark slate toe beans, warm amber claws/nails.
            return PawPalette(fur: RGBA(0.12, 0.12, 0.14), pad: RGBA(0.34, 0.32, 0.32),
                              outline: RGBA(0.02, 0.02, 0.03), accent: RGBA(0.86, 0.59, 0.31))
        case .dog:
            return PawPalette(fur: RGBA(0.76, 0.55, 0.32), pad: RGBA(0.30, 0.22, 0.20),
                              outline: RGBA(0.22, 0.15, 0.11), accent: RGBA(0.94, 0.88, 0.78))
        case .bunny:
            return PawPalette(fur: RGBA(0.97, 0.97, 0.99), pad: RGBA(1.0, 0.72, 0.79),
                              outline: RGBA(0.74, 0.74, 0.80), accent: RGBA(1.0, 0.80, 0.85))
        case .fox, .foxTail:
            return PawPalette(fur: RGBA(0.92, 0.45, 0.16), pad: RGBA(0.16, 0.12, 0.12),
                              outline: RGBA(0.32, 0.13, 0.05), accent: RGBA(0.98, 0.97, 0.95))
        case .bear:
            return PawPalette(fur: RGBA(0.36, 0.24, 0.17), pad: RGBA(0.55, 0.40, 0.28),
                              outline: RGBA(0.13, 0.08, 0.06), accent: RGBA(0.20, 0.14, 0.10))
        }
    }
}
