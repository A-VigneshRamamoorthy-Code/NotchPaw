import CoreGraphics
import Foundation

/// Draws a creature (arm + paw, or a tail) along the engine's chain into a
/// Core Graphics context. CoreGraphics-only so it renders both on screen and
/// into offscreen bitmaps for previews/tests. Expects a bottom-left origin.
public enum PawRenderer {
    public static func draw(in ctx: CGContext, state: PawState, style: PawStyle, shoulder: CGPoint) {
        let em = Double(state.emergence)
        guard em > 0.004 else { return }
        switch style.appendage {
        case .paw:  drawPawCreature(in: ctx, state: state, style: style)
        case .tail: drawTailCreature(in: ctx, state: state, style: style)
        }
    }

    /// Padded bounding box of the chain — lets the view invalidate just the
    /// dirty region.
    public static func bounds(of state: PawState, style: PawStyle) -> CGRect {
        var minX = Double.greatestFiniteMagnitude, minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        for n in state.nodes {
            minX = min(minX, Double(n.x)); maxX = max(maxX, Double(n.x))
            minY = min(minY, Double(n.y)); maxY = max(maxY, Double(n.y))
        }
        let pad = 44.0 * style.behavior.pawScale + 14
        return CGRect(x: minX - pad, y: minY - pad,
                      width: (maxX - minX) + pad * 2, height: (maxY - minY) + pad * 2)
    }

    // MARK: - Paw creature

    private static func drawPawCreature(in ctx: CGContext, state: PawState, style: PawStyle) {
        let pal = style.palette
        let em = Double(state.emergence)
        let dense = smooth(state.nodes, samplesPerSeg: 5)
        let s = style.behavior.pawScale

        // Arm: a gently tapered fur limb with a dark outline.
        let w = linearWidths(dense.count, baseW: 26 * s, tipW: 18 * s)
        fillRibbon(ctx, points: dense, widths: w.map { $0 + 3 }, color: pal.outline.cg(em * 0.6))
        fillRibbon(ctx, points: dense, widths: w, color: pal.fur.cg(em))

        // Paw head at the tip (cached image — rigid, only rotates/scales).
        let st = max(0.7, Double(state.stretch))
        let tip = state.tip
        ctx.saveGState()
        ctx.translateBy(x: tip.x, y: tip.y)
        ctx.rotate(by: state.tipRotation)
        ctx.scaleBy(x: CGFloat(s) * state.scale * CGFloat(st.squareRoot()),
                    y: CGFloat(s) * state.scale / CGFloat(st.squareRoot()))
        if let img = headImage(for: style) {
            ctx.setAlpha(CGFloat(em))
            let half = headImgPt / 2
            ctx.draw(img, in: CGRect(x: -half, y: -half, width: headImgPt, height: headImgPt))
            ctx.setAlpha(1)
        } else {
            drawPawHead(ctx, style: style, alpha: em)
        }
        ctx.restoreGState()
    }

    // Paw heads are rigid, so rasterise each once and reuse it every frame.
    private static var headCache: [String: CGImage] = [:]
    private static let headImgPt: CGFloat = 130
    private static let headImgScale: CGFloat = 2

    private static func headImage(for style: PawStyle) -> CGImage? {
        if let img = headCache[style.rawValue] { return img }
        let px = Int(headImgPt * headImgScale)
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: headImgScale, y: headImgScale)
        ctx.translateBy(x: headImgPt / 2, y: headImgPt / 2)
        drawPawHead(ctx, style: style, alpha: 1)
        let img = ctx.makeImage()
        headCache[style.rawValue] = img
        return img
    }

    // MARK: - Menu thumbnail icons

    private static var iconCache: [String: CGImage] = [:]

    /// A small representative icon for a style: a paw print for paws, a little
    /// swooshing tail for tails. Cached. `size` is in points; rendered at `scale`.
    public static func icon(for style: PawStyle, size: CGSize, scale: CGFloat = 2) -> CGImage? {
        let key = "\(style.rawValue)-\(Int(size.width))x\(Int(size.height))"
        if let img = iconCache[key] { return img }
        let px = Int(size.width * scale), py = Int(size.height * scale)
        guard px > 0, py > 0,
              let ctx = CGContext(data: nil, width: px, height: py, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)

        switch style.appendage {
        case .paw:
            ctx.saveGState()
            ctx.translateBy(x: size.width / 2, y: size.height * 0.44)
            let fit = min(size.width, size.height) / 116.0   // head extent ≈ ±55
            ctx.scaleBy(x: fit, y: fit)
            ctx.rotate(by: .pi / 2)                          // toes up → reads as a paw print
            drawPawHead(ctx, style: style, alpha: 1)
            ctx.restoreGState()
        case .tail:
            let w = Double(size.width), h = Double(size.height)
            let pts = [CGPoint(x: w * 0.52, y: h * 0.08),
                       CGPoint(x: w * 0.52, y: h * 0.40),
                       CGPoint(x: w * 0.40, y: h * 0.66),
                       CGPoint(x: w * 0.62, y: h * 0.92)]
            let dense = smooth(pts, samplesPerSeg: 10)
            let bushy = (style == .foxTail)
            let s = min(w, h) / 24.0
            let widths = linearWidths(dense.count, baseW: (bushy ? 11 : 8) * s, tipW: (bushy ? 6 : 3) * s)
            fillRibbon(ctx, points: dense, widths: widths, color: style.palette.fur.cg(1))
            if bushy {
                let k = max(2, dense.count * 30 / 100)
                fillRibbon(ctx, points: Array(dense.suffix(k)),
                           widths: Array(widths.suffix(k)), color: style.palette.accent.cg(1))
            }
        }

        let img = ctx.makeImage()
        iconCache[key] = img
        return img
    }

    // MARK: - App icon (cat paw)

    /// Renders the NotchPaw application icon: a cute cat paw print on a soft
    /// rounded-square gradient. `pt` is the icon edge length in points.
    public static func appIcon(pt: CGFloat = 1024, scale: CGFloat = 1) -> CGImage? {
        let px = Int(pt * scale)
        guard px > 0,
              let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        let n = Double(pt)

        // Rounded-square plate with a soft top-to-bottom gradient (macOS-style
        // padding so the system squircle mask never clips the art).
        let margin = n * 0.085
        let plate = CGRect(x: margin, y: margin, width: n - margin * 2, height: n - margin * 2)
        let radius = plate.width * 0.225
        let platePath = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.addPath(platePath); ctx.clip()
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let top = CGColor(srgbRed: 0.40, green: 0.46, blue: 0.98, alpha: 1)     // indigo
        let bottom = CGColor(srgbRed: 0.62, green: 0.38, blue: 0.93, alpha: 1)  // violet
        if let grad = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: plate.maxY),
                                   end: CGPoint(x: 0, y: plate.minY), options: [])
        }
        // Soft top sheen.
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10))
        ctx.fillEllipse(in: CGRect(x: plate.minX - plate.width * 0.1, y: plate.midY,
                                   width: plate.width * 1.2, height: plate.height * 0.8))
        ctx.restoreGState()

        // Centred cat paw print (white pads, pink beans, soft drop shadow).
        ctx.saveGState()
        ctx.translateBy(x: n / 2, y: n * 0.47)
        let s = n / 1024.0
        ctx.setShadow(offset: CGSize(width: 0, height: -n * 0.012), blur: n * 0.03,
                      color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28))
        drawCatPawPrint(ctx, scale: s)
        ctx.restoreGState()

        return ctx.makeImage()
    }

    /// A classic cat paw print centred at the origin (palm + 4 toe beans).
    /// Local units are in icon points (designed for a 1024 icon), scaled by `s`.
    private static func drawCatPawPrint(_ ctx: CGContext, scale s: Double) {
        let white = CGColor(srgbRed: 0.99, green: 0.98, blue: 1.0, alpha: 1)
        let bean = CGColor(srgbRed: 1.0, green: 0.59, blue: 0.71, alpha: 1)

        // Toe beans: four ellipses fanned above the palm. (x, y, w, h)
        let toes: [(Double, Double, Double, Double)] = [
            (-205, 70, 150, 185),
            (-72, 165, 168, 205),
            (95, 165, 168, 205),
            (225, 70, 150, 185),
        ]
        // Palm pad.
        let palm = CGRect(x: -210 * s, y: -260 * s, width: 420 * s, height: 360 * s)

        // 1) White base shapes (carry the shared drop shadow).
        ctx.setFillColor(white)
        let palmPath = CGPath(roundedRect: palm, cornerWidth: 150 * s, cornerHeight: 140 * s, transform: nil)
        ctx.addPath(palmPath); ctx.fillPath()
        for t in toes {
            ctx.fillEllipse(in: CGRect(x: t.0 * s - t.2 * s / 2, y: t.1 * s - t.3 * s / 2,
                                       width: t.2 * s, height: t.3 * s))
        }

        // 2) Pink bean accents (no shadow), nested inside each pad.
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setFillColor(bean)
        let palmBean = palm.insetBy(dx: palm.width * 0.16, dy: palm.height * 0.18)
        ctx.fillEllipse(in: palmBean)
        for t in toes {
            let bw = t.2 * 0.56, bh = t.3 * 0.56
            ctx.fillEllipse(in: CGRect(x: t.0 * s - bw * s / 2, y: (t.1 + 2) * s - bh * s / 2,
                                       width: bw * s, height: bh * s))
        }
        ctx.restoreGState()
    }

    private static func drawPawHead(_ ctx: CGContext, style: PawStyle, alpha: Double) {
        let pal = style.palette
        let fur = pal.fur.cg(alpha)
        let outline = pal.outline.cg(alpha * 0.6)
        let pad = pal.pad.cg(alpha)
        let claw = pal.accent.cg(alpha)
        let shape = PawShape.of(style)

        // Palm blob.
        let palm = CGRect(x: -shape.palmW * 0.5 - 6, y: -shape.palmH * 0.5,
                          width: shape.palmW, height: shape.palmH)
        let palmPath = CGPath(roundedRect: palm, cornerWidth: shape.palmH * 0.45,
                              cornerHeight: shape.palmH * 0.45, transform: nil)
        ctx.setFillColor(fur); ctx.addPath(palmPath); ctx.fillPath()

        let toePts = shape.toePoints()
        for p in toePts {
            ctx.setFillColor(fur)
            ctx.fillEllipse(in: CGRect(x: p.x - shape.toeR, y: p.y - shape.toeR,
                                       width: shape.toeR * 2, height: shape.toeR * 2))
        }

        // Claws (small triangles beyond the toes).
        if shape.clawLen > 0 {
            ctx.setFillColor(claw)
            for p in toePts {
                let a = atan2(p.y, p.x + 0.0001)
                let tipP = CGPoint(x: p.x + cos(a) * (shape.toeR + shape.clawLen),
                                   y: p.y + sin(a) * (shape.toeR + shape.clawLen))
                let nrm = CGPoint(x: -sin(a), y: cos(a))
                ctx.beginPath()
                ctx.move(to: CGPoint(x: p.x + nrm.x * shape.toeR * 0.5, y: p.y + nrm.y * shape.toeR * 0.5))
                ctx.addLine(to: CGPoint(x: p.x - nrm.x * shape.toeR * 0.5, y: p.y - nrm.y * shape.toeR * 0.5))
                ctx.addLine(to: tipP)
                ctx.closePath(); ctx.fillPath()
            }
        }

        // Outline pass.
        ctx.setLineWidth(2); ctx.setStrokeColor(outline)
        ctx.addPath(palmPath); ctx.strokePath()
        for p in toePts {
            ctx.strokeEllipse(in: CGRect(x: p.x - shape.toeR, y: p.y - shape.toeR,
                                         width: shape.toeR * 2, height: shape.toeR * 2))
        }

        // Beans: toe beans + main pad.
        ctx.setFillColor(pad)
        for p in toePts {
            let br = shape.toeR * 0.5
            ctx.fillEllipse(in: CGRect(x: p.x * 0.78 - br, y: p.y * 0.78 - br, width: br * 2, height: br * 2))
        }
        let mp = shape.toeR * 0.95
        ctx.fillEllipse(in: CGRect(x: -2, y: -mp, width: mp * 1.9, height: mp * 2))
    }

    // MARK: - Tail creature

    private static func drawTailCreature(in ctx: CGContext, state: PawState, style: PawStyle) {
        let pal = style.palette
        let em = Double(state.emergence)
        let dense = smooth(state.nodes, samplesPerSeg: 6)
        let s = style.behavior.pawScale
        let bushy = (style == .foxTail)

        let widths = linearWidths(dense.count, baseW: (bushy ? 34 : 24) * s, tipW: (bushy ? 12 : 6) * s)
        fillRibbon(ctx, points: dense, widths: widths.map { $0 + 3 }, color: pal.outline.cg(em * 0.6))
        fillRibbon(ctx, points: dense, widths: widths, color: pal.fur.cg(em))

        // Fox tail: white-tipped last ~26% (same widths so it reads as fur, not a blob).
        if bushy {
            let k = max(2, dense.count * 26 / 100)
            let tipPts = Array(dense.suffix(k))
            let tipW = Array(widths.suffix(k))
            fillRibbon(ctx, points: tipPts, widths: tipW, color: pal.accent.cg(em))
        }
    }

    // MARK: - Ribbon + smoothing

    private static func linearWidths(_ n: Int, baseW: Double, tipW: Double) -> [Double] {
        guard n > 1 else { return [baseW] }
        return (0..<n).map { baseW + (tipW - baseW) * Double($0) / Double(n - 1) }
    }

    /// Fill a ribbon whose half-thickness at each point comes from `widths`.
    private static func fillRibbon(_ ctx: CGContext, points: [CGPoint], widths: [Double], color: CGColor) {
        let n = points.count
        guard n >= 2, widths.count == n else { return }
        var left = [CGPoint](), right = [CGPoint]()
        left.reserveCapacity(n); right.reserveCapacity(n)
        for i in 0..<n {
            let prev = points[max(0, i - 1)]
            let next = points[min(n - 1, i + 1)]
            var tx = Double(next.x - prev.x), ty = Double(next.y - prev.y)
            let tl = max(1e-4, (tx * tx + ty * ty).squareRoot())
            tx /= tl; ty /= tl
            let nx = -ty, ny = tx
            let w = widths[i] * 0.5
            left.append(CGPoint(x: Double(points[i].x) + nx * w, y: Double(points[i].y) + ny * w))
            right.append(CGPoint(x: Double(points[i].x) - nx * w, y: Double(points[i].y) - ny * w))
        }
        ctx.beginPath()
        addSmoothBoundary(ctx, left, startsPath: true)
        let tip = points[n - 1]
        ctx.addArc(center: tip, radius: max(0.5, widths[n - 1] * 0.5),
                   startAngle: 0, endAngle: .pi, clockwise: false)
        addSmoothBoundary(ctx, Array(right.reversed()), startsPath: false)
        ctx.closePath()
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    /// Append a smooth boundary through `pts` using the midpoint quadratic
    /// technique (curve passes through segment midpoints with the original
    /// vertices as control points) — no facets even with few points.
    private static func addSmoothBoundary(_ ctx: CGContext, _ pts: [CGPoint], startsPath: Bool) {
        guard let first = pts.first else { return }
        if startsPath { ctx.move(to: first) } else { ctx.addLine(to: first) }
        if pts.count < 3 {
            for p in pts.dropFirst() { ctx.addLine(to: p) }
            return
        }
        for i in 1..<(pts.count - 1) {
            let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) * 0.5,
                              y: (pts[i].y + pts[i + 1].y) * 0.5)
            ctx.addQuadCurve(to: mid, control: pts[i])
        }
        ctx.addLine(to: pts[pts.count - 1])
    }

    private static func smooth(_ pts: [CGPoint], samplesPerSeg: Int) -> [CGPoint] {
        guard pts.count >= 3 else { return pts }
        let n = pts.count
        var out = [CGPoint]()
        out.reserveCapacity(n * samplesPerSeg)
        for i in 0..<(n - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(n - 1, i + 2)]
            for sIdx in 0..<samplesPerSeg {
                let t = Double(sIdx) / Double(samplesPerSeg)
                out.append(catmull(p0, p1, p2, p3, t))
            }
        }
        out.append(pts[n - 1])
        return out
    }

    private static func catmull(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: Double) -> CGPoint {
        let t2 = t * t, t3 = t2 * t
        func c(_ a: CGFloat, _ b: CGFloat, _ cc: CGFloat, _ d: CGFloat) -> CGFloat {
            CGFloat(0.5 * (2 * Double(b) + (Double(cc) - Double(a)) * t
                + (2 * Double(a) - 5 * Double(b) + 4 * Double(cc) - Double(d)) * t2
                + (-Double(a) + 3 * Double(b) - 3 * Double(cc) + Double(d)) * t3))
        }
        return CGPoint(x: c(p0.x, p1.x, p2.x, p3.x), y: c(p0.y, p1.y, p2.y, p3.y))
    }
}

/// Per-animal paw-head geometry (local space, toes toward +x).
private struct PawShape {
    var palmW: Double, palmH: Double
    var toeCount: Int, toeFanR: Double, toeR: Double, toeSpreadDeg: Double
    var clawLen: Double

    func toePoints() -> [CGPoint] {
        guard toeCount > 0 else { return [] }
        var pts = [CGPoint]()
        for i in 0..<toeCount {
            let f = toeCount == 1 ? 0.5 : Double(i) / Double(toeCount - 1)
            let deg = -toeSpreadDeg / 2 + toeSpreadDeg * f
            let a = deg * .pi / 180
            pts.append(CGPoint(x: 6 + cos(a) * toeFanR, y: sin(a) * toeFanR))
        }
        return pts
    }

    static func of(_ style: PawStyle) -> PawShape {
        switch style {
        case .cat, .catTail:
            return PawShape(palmW: 34, palmH: 36, toeCount: 4, toeFanR: 19, toeR: 8,
                            toeSpreadDeg: 116, clawLen: 0)
        case .blackCat:
            // Same cat geometry, but with the claws unsheathed (amber accent).
            return PawShape(palmW: 34, palmH: 36, toeCount: 4, toeFanR: 19, toeR: 8,
                            toeSpreadDeg: 116, clawLen: 4.5)
        case .dog:
            return PawShape(palmW: 40, palmH: 40, toeCount: 4, toeFanR: 22, toeR: 9.5,
                            toeSpreadDeg: 120, clawLen: 5)
        case .bunny:
            return PawShape(palmW: 30, palmH: 38, toeCount: 3, toeFanR: 16, toeR: 7.5,
                            toeSpreadDeg: 80, clawLen: 0)
        case .fox, .foxTail:
            return PawShape(palmW: 30, palmH: 32, toeCount: 4, toeFanR: 19, toeR: 7,
                            toeSpreadDeg: 100, clawLen: 6)
        case .bear:
            return PawShape(palmW: 46, palmH: 44, toeCount: 5, toeFanR: 26, toeR: 9,
                            toeSpreadDeg: 132, clawLen: 9)
        }
    }
}

extension RGBA {
    /// Convert to a Core Graphics colour, multiplying alpha by `alpha`.
    public func cg(_ alpha: Double = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a * alpha)
    }
}
