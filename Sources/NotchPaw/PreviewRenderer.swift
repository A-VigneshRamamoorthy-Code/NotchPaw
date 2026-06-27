import CoreGraphics
import Foundation
import ImageIO
import NotchPawCore
import UniformTypeIdentifiers

/// Renders paw/tail art and animation frames to PNGs for headless visual
/// verification. `--render <dir>` = one pose per style; `--contact <dir>` =
/// an animation contact-sheet per style. Needs no window server.
enum PreviewRenderer {
    // One representative pose per style.
    static func renderAll(to dir: String) {
        ensureDir(dir)
        let size = CGSize(width: 240, height: 240)
        // Base anchored above the top edge (clipped flush). Cursor CLOSE to the
        // notch to verify the limb stays short instead of coiling.
        let shoulder = CGPoint(x: size.width / 2, y: size.height + 16)
        let cursor = CGPoint(x: size.width / 2 + 34, y: size.height - 58)
        for style in PawStyle.allCases {
            var engine = PawEngine(shoulder: shoulder, style: style)
            step(&engine, cursor: cursor, seconds: 1.05)
            guard let ctx = makeContext(size: size) else { continue }
            drawScene(ctx, size: size, shoulder: shoulder, cursor: cursor, engine: engine, style: style)
            save(ctx, to: dir, name: style.rawValue)
        }
    }

    // Animation contact sheet: a grid of frames sampled over ~2 seconds.
    static func renderContact(to dir: String) {
        ensureDir(dir)
        let cols = 6, rows = 2
        let cell = CGSize(width: 210, height: 196)
        let shoulder = CGPoint(x: cell.width / 2, y: cell.height + 16)
        let cursor = CGPoint(x: cell.width / 2 + 78, y: cell.height - 150)
        let frames = cols * rows
        let stepsPerFrame = 11   // ~0.18s between captured frames

        for style in PawStyle.allCases {
            let sheet = CGSize(width: cell.width * CGFloat(cols), height: cell.height * CGFloat(rows))
            guard let ctx = makeContext(size: sheet) else { continue }
            var engine = PawEngine(shoulder: shoulder, style: style)
            // brief warmup so it has emerged
            step(&engine, cursor: cursor, seconds: 0.25)
            for f in 0..<frames {
                let col = f % cols, row = f / cols
                let ox = CGFloat(col) * cell.width
                let oy = sheet.height - CGFloat(row + 1) * cell.height
                ctx.saveGState()
                ctx.translateBy(x: ox, y: oy)
                drawScene(ctx, size: cell, shoulder: shoulder, cursor: cursor, engine: engine, style: style)
                ctx.restoreGState()
                for _ in 0..<stepsPerFrame { engine.update(cursor: cursor, engaged: true, dt: 1.0 / 60.0) }
            }
            save(ctx, to: dir, name: "live-\(style.rawValue)")
        }
    }

    // Menu thumbnail icons on a light + dark split background.
    static func renderIcons(to dir: String) {
        ensureDir(dir)
        for style in PawStyle.allCases {
            let size = CGSize(width: 96, height: 64)
            guard let ctx = makeContext(size: size) else { continue }
            ctx.setFillColor(CGColor(srgbRed: 0.9, green: 0.9, blue: 0.92, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
            ctx.setFillColor(CGColor(srgbRed: 0.16, green: 0.16, blue: 0.18, alpha: 1))
            ctx.fill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height))
            if let icon = PawRenderer.icon(for: style, size: CGSize(width: 60, height: 48), scale: 3) {
                ctx.draw(icon, in: CGRect(x: (96 - 60) / 2, y: (64 - 48) / 2, width: 60, height: 48))
            }
            save(ctx, to: dir, name: "icon-\(style.rawValue)")
        }
    }

    // The 1024px application icon (cat paw) as a standalone PNG.
    static func renderAppIcon(to path: String) -> Bool {
        guard let img = PawRenderer.appIcon(pt: 1024, scale: 1) else { return false }
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(dest, img, nil)
        let ok = CGImageDestinationFinalize(dest)
        if ok { FileHandle.standardOutput.write("rendered \(url.path)\n".data(using: .utf8)!) }
        return ok
    }

    // MARK: - Helpers

    private static func step(_ engine: inout PawEngine, cursor: CGPoint, seconds: Double) {
        var t = 0.0
        while t < seconds { engine.update(cursor: cursor, engaged: true, dt: 1.0 / 60.0); t += 1.0 / 60.0 }
    }

    private static func drawScene(_ ctx: CGContext, size: CGSize, shoulder: CGPoint,
                                  cursor: CGPoint, engine: PawEngine, style: PawStyle) {
        ctx.saveGState()
        ctx.clip(to: CGRect(origin: .zero, size: size))   // emulate the top-edge clip
        ctx.setFillColor(CGColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        // The creature — its base above the top is clipped flush.
        PawRenderer.draw(in: ctx, state: engine.state, style: style, shoulder: shoulder)
        // Notch nub hanging from the top centre (the limb passes behind it).
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        let notch = CGPath(roundedRect: CGRect(x: size.width / 2 - 70, y: size.height - 20, width: 140, height: 28),
                           cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.addPath(notch); ctx.fillPath()
        // Cursor marker.
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
        ctx.fillEllipse(in: CGRect(x: cursor.x - 3, y: cursor.y - 3, width: 6, height: 6))
        ctx.restoreGState()
    }

    private static func ensureDir(_ dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    private static func makeContext(size: CGSize) -> CGContext? {
        CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                  bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private static func save(_ ctx: CGContext, to dir: String, name: String) {
        guard let image = ctx.makeImage() else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        FileHandle.standardOutput.write("rendered \(url.path)\n".data(using: .utf8)!)
    }
}
