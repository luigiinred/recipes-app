import SwiftUI

/// A scene's own coordinate space: the character is drawn at `scale` and `origin` inside it.
private struct SceneSpace {
    var origin: CGPoint
    var scale: CGFloat
    var matrix: CGAffineTransform { mul(CGAffineTransform(translationX: origin.x, y: origin.y), CGAffineTransform(scaleX: scale, y: scale)) }
}

/// How a character's arms are drawn, needed to find where a hand ends up.
private enum Arms {
    static func baked(_ c: MascotCharacter, _ side: String) -> CGFloat {
        switch (c, side) {
        case (.tomato, "l"): 14
        case (.tomato, _): -14
        case (.potato, "l"): 10
        case (.potato, _): -10
        case (.lemon, "l"): 128
        case (.lemon, _): -128
        case (.chili, "l"): 150
        case (.chili, _): -72
        }
    }

    static func scale(_ c: MascotCharacter) -> CGFloat {
        switch c {
        case .tomato: 0.82
        case .potato: 0.78
        case .lemon: 0.8
        case .chili: 0.78
        }
    }

    /// The hand's centre in the arm's rest pose.
    static func hand(_ rig: SVGRig, _ c: MascotCharacter, _ side: String) -> CGPoint {
        let shoulder = rig.pivot(of: "arm-\(side)")
        let angle = baked(c, side) * .pi / 180
        let length = 60 * scale(c)
        return CGPoint(x: shoulder.x - length * sin(angle), y: shoulder.y + length * cos(angle))
    }
}

private func fillColor(_ hex: UInt32, _ alpha: Double = 1) -> GraphicsContext.Shading {
    .color(Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha))
}

private func lerp(_ a: CGPoint, _ b: CGPoint, _ u: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u) }

// MARK: - Stir fry

/// The character tossing veggies in a wok held in its right hand.
enum StirFryScene {
    private static let space = SceneSpace(origin: CGPoint(x: 12, y: 52), scale: 0.8)

    private typealias Item = (kind: String, launch: Double, flight: Double, height: CGFloat, drift: CGFloat, driftEnd: CGFloat, spin: Double)
    private static let items: [Item] = [
        ("carrot", 0.30, 0.56, 74, -14, 6, 1.5), ("broccoli", 0.31, 0.62, 92, 10, -8, -1.0),
        ("pepper", 0.32, 0.58, 62, 26, 14, 2.0), ("pea", 0.30, 0.50, 82, -26, -14, 0),
        ("mushroom", 0.33, 0.60, 68, 4, 22, -1.5), ("onion", 0.31, 0.54, 86, 20, -4, 1.0),
        ("pea", 0.32, 0.64, 56, -6, 8, 0), ("carrot", 0.34, 0.52, 78, 30, 20, -2.0),
    ]

    static func pose(_ c: MascotCharacter, _ t: Double, tossing: Bool) -> Pose {
        typealias M = Motion
        let baked = Double(Arms.baked(c, "r"))
        let rest = -90 - baked
        let sq = tossing ? M.keys(t, [(0, 0), (0.2, 1), (0.3, 0), (1, 0)]) : 0
        let st = tossing ? M.keys(t, [(0, 0), (0.26, 0), (0.32, 1), (0.5, 0), (1, 0)]) : 0
        let arm = tossing ? M.keys(t, [(0, 0), (0.2, 11), (0.3, -15), (0.42, -5), (0.6, 0), (1, 0)]) : 2 * M.sine(t)
        let tilt = tossing ? M.keys(t, [(0, 0), (0.2, 7), (0.3, -13), (0.45, -4), (0.65, 0), (1, 0)]) : 1.5 * M.sine(t, 1, 0.2)
        var p: Pose = [
            "arm-r": BonePose(rot: rest + arm),
            "wok": BonePose(rot: tilt),
            "arm-l": BonePose(rot: -10 * st + 8 * sq + (tossing ? 0 : 3 * M.sine(t, 1, 0.1))),
        ]
        let squash = (sx: 1 + 0.05 * sq - 0.025 * st, sy: 1 - 0.07 * sq + 0.05 * st + (tossing ? 0 : 0.012 * M.sine(t)))
        p["root"] = BonePose(dy: -7 * st, sx: squash.sx, sy: squash.sy, pivot: c.ground)
        switch c {
        case .chili:
            p["body"] = BonePose(rot: -2 * st + 1.5 * sq, skx: 4 * M.sine(t, 1, -0.2) - 5 * st)
            p["stem"] = BonePose(rot: 5 * M.sine(t, 1, -0.3))
        default:
            p["body"] = BonePose(rot: -2 * st + 1.5 * sq)
            p["leg-l"] = BonePose(sy: 1 - 0.08 * sq)
            p["leg-r"] = BonePose(sy: 1 - 0.08 * sq)
            if c == .tomato {
                p["hat"] = BonePose(rot: 6 * M.keys(t, [(0, 0), (0.3, 0), (0.38, -1), (0.6, 0.3), (1, 0)]) + 3 * sq)
                p["calyx"] = BonePose(rot: 5 * st)
            }
            if c == .lemon { p["leaf"] = BonePose(rot: 8 * M.sine(t, 1, -0.1)) }
        }
        return p
    }

    private static func attachment(_ rig: SVGRig, _ c: MascotCharacter) -> CGAffineTransform {
        let hand = Arms.hand(rig, c, "r")
        return mul(CGAffineTransform(translationX: hand.x, y: hand.y), CGAffineTransform(rotationAngle: (90 + Arms.baked(c, "r")) * .pi / 180))
    }

    /// Where the wok's opening is, in scene coordinates.
    private static func mouth(_ rig: SVGRig, _ c: MascotCharacter, _ t: Double, tossing: Bool) -> CGPoint {
        let p = pose(c, t, tossing: tossing)
        var m = mul(space.matrix, rig.matrix(of: "arm-r", pose: p))
        m = mul(m, attachment(rig, c))
        m = mul(m, (p["wok"] ?? BonePose()).matrix(pivot: .zero))
        return CGPoint(x: 133, y: -8).applying(m)
    }

    static func draw(_ c: MascotCharacter, phase t: Double, tossing: Bool, in ctx: inout GraphicsContext, scale: CGFloat) {
        let rig = SVGRig.named(c.rawValue)
        let wok = SVGRig.named(tossing ? "wok" : "wok-empty")
        var p = pose(c, t, tossing: tossing)
        let happy = tossing && t >= 0.28 && t < 0.7
        let blink = Motion.blink(t, at: 0.9, width: 0.04)
        p["eye-l"] = BonePose(sy: blink)
        p["eye-r"] = BonePose(sy: blink)

        if tossing { steam(rig, c, t, in: &ctx, scale: scale) }
        var layer = ctx
        layer.concatenate(space.matrix)
        let held = SVGRig.Attachment(rig: wok, base: attachment(rig, c), pose: p)
        rig.draw(in: &layer, pose: p, visibility: ["eyes-open": !happy, "eyes-happy": happy], attachments: ["arm-r": held])
        guard tossing else { return }

        for item in items {
            let u = ((t - item.launch).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) / item.flight
            guard u < 1 else { continue }
            let from = mouth(rig, c, item.launch, tossing: true)
            let landing = (item.launch + item.flight).truncatingRemainder(dividingBy: 1)
            let to = mouth(rig, c, landing, tossing: true)
            let x = from.x + item.drift + (to.x + item.driftEnd - from.x - item.drift) * u
            let y = from.y + (to.y - from.y) * u - item.height * 4 * u * (1 - u)
            let opacity = min(1, (1 - u) * 6, u * 12 + 0.4)
            var m = CGAffineTransform(translationX: x, y: y)
            m = mul(m, CGAffineTransform(rotationAngle: item.spin * 2 * .pi * u))
            m = mul(m, CGAffineTransform(scaleX: 0.85, y: 0.85))
            var piece = ctx
            piece.concatenate(m)
            SVGRig.named("veg-\(item.kind)").draw(in: &piece, pose: [:], opacity: opacity)
        }
    }

    private static func steam(_ rig: SVGRig, _ c: MascotCharacter, _ t: Double, in ctx: inout GraphicsContext, scale: CGFloat) {
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 2.4 * scale))
            for k in 0..<5 {
                let u = (t + Double(k) / 5).truncatingRemainder(dividingBy: 1)
                let anchor = mouth(rig, c, (t - u + 1).truncatingRemainder(dividingBy: 1), tossing: true)
                let r = CGFloat(9 + 15 * u)
                let drift = 10 * sin(2 * .pi * (0.8 * u + 0.37 * Double(k)))
                let x = anchor.x + CGFloat(k - 2) * 6 + CGFloat(drift)
                let y = anchor.y - 38 - CGFloat(90 * u)
                let opacity = Motion.smooth(min(1, u / 0.35)) * pow(1 - u, 1.2) * 0.85
                let puff = Path { path in
                    for (dx, dy, rr) in [(CGFloat(0), CGFloat(0), r), (r * 0.8, r * 0.25, r * 0.75), (-r * 0.7, r * 0.3, r * 0.6)] {
                        path.addEllipse(in: CGRect(x: x + dx - rr, y: y + dy - rr, width: 2 * rr, height: 2 * rr))
                    }
                }
                layer.fill(puff.offsetBy(dx: 1.5, dy: 2.5), with: fillColor(0xE3D9C6, opacity * 0.8))
                layer.fill(puff, with: fillColor(0xFFFFFF, opacity))
            }
        }
    }
}

// MARK: - Books

/// The character behind an open book, turning its pages or writing in it with a quill.
enum BookScene {
    private static let space = SceneSpace(origin: CGPoint(x: 40, y: 52), scale: 0.8)
    private static let spine: CGFloat = 200, half: CGFloat = 74, depth: CGFloat = 56, lift: CGFloat = 40
    private static let ruledRows: [CGFloat] = [0.2, 0.38, 0.56, 0.74]

    // MARK: Kinematics

    private static func shoulder(_ rig: SVGRig, _ p: Pose, _ side: String) -> CGPoint {
        rig.pivot(of: "arm-\(side)").applying(mul(space.matrix, rig.matrix(of: "body", pose: p)))
    }

    private static func hand(_ rig: SVGRig, _ c: MascotCharacter, _ p: Pose, _ side: String) -> CGPoint {
        Arms.hand(rig, c, side).applying(mul(space.matrix, rig.matrix(of: "arm-\(side)", pose: p)))
    }

    /// Turns the arm until its hand points at `target`. An arm can't stretch, so it points rather than reaches.
    private static func aim(_ rig: SVGRig, _ c: MascotCharacter, _ p: inout Pose, _ side: String, at target: CGPoint) {
        let key = "arm-\(side)"
        var arm = BonePose()
        p[key] = arm
        for _ in 0..<4 {
            let s = shoulder(rig, p, side), h = hand(rig, c, p, side)
            var turn = (atan2(target.y - s.y, target.x - s.x) - atan2(h.y - s.y, h.x - s.x)) * 180 / .pi
            turn = (turn + 180).truncatingRemainder(dividingBy: 360) - 180
            if turn < -180 { turn += 360 }
            arm.rot += Double(turn)
            p[key] = arm
        }
    }

    private static func basePose(_ c: MascotCharacter, _ t: Double, lean: Double) -> Pose {
        typealias M = Motion
        var p: Pose = ["root": BonePose(), "body": BonePose(rot: lean + 0.8 * M.sine(t), sx: 1 - 0.008 * M.sine(t), sy: 1 + 0.018 * M.sine(t))]
        switch c {
        case .chili:
            p["root"] = BonePose(pivot: c.ground)
            p["body"] = BonePose(rot: lean, skx: 3 * M.sine(t, 1, -0.2))
            p["stem"] = BonePose(rot: 3 * M.sine(t, 1, -0.25))
        case .tomato:
            p["hat"] = BonePose(rot: 1.5 * M.sine(t, 1, -0.15))
            p["calyx"] = BonePose(rot: 2 * M.sine(t, 1, -0.2))
        case .lemon: p["leaf"] = BonePose(rot: 4 * M.sine(t, 1, -0.15))
        case .potato: break
        }
        return p
    }

    /// The book's back edge sits just below the shoulders so hands reach the pages.
    private static func backEdge(_ rig: SVGRig) -> CGFloat {
        max(280, max(shoulder(rig, [:], "l").y, shoulder(rig, [:], "r").y) + 28)
    }

    // MARK: Page turning

    private static func corner(_ yb: CGFloat, _ phi: Double) -> CGPoint {
        let a = phi * .pi / 180
        return CGPoint(x: spine + (half - 6) * CGFloat(cos(a)), y: yb - lift * CGFloat(sin(a)))
    }

    private static func turning(_ rig: SVGRig, _ c: MascotCharacter, _ t: Double, _ yb: CGFloat) -> (Pose, Double) {
        typealias M = Motion
        var p = basePose(c, t, lean: 1.5 * M.keys(t, [(0, 0), (0.3, 1), (0.7, 0), (1, 0)]))
        let phi = M.keys(t, [(0, 0), (0.14, 0), (0.5, 62), (0.6, 70), (0.8, 180), (1, 180)])
        let rest = CGPoint(x: spine + half - 12, y: yb + 16)
        let hold = CGFloat(M.keys(t, [(0, 0), (0.1, 1), (0.54, 1), (0.62, 0), (0.9, 0), (1, 0)]))
        let grabbed = corner(yb, min(phi, 62))
        var target = lerp(rest, CGPoint(x: grabbed.x, y: grabbed.y - 2), hold)
        if t >= 0.54 { target = lerp(corner(yb, 62), rest, CGFloat(M.smooth(min(1, (t - 0.54) / 0.26)))) }
        aim(rig, c, &p, "r", at: target)
        aim(rig, c, &p, "l", at: CGPoint(x: spine - half + 18, y: yb + 18 + 1.5 * CGFloat(M.sine(t))))
        return (p, phi)
    }

    // MARK: Writing

    private static let rowStart = 0.05, rowStep = 0.2, rowLength = 0.165
    private static let tipOffset = CGPoint(x: -30, y: 26)

    private static func page(_ yb: CGFloat, right: Bool, _ u: CGFloat, _ v: CGFloat) -> CGPoint {
        let sign: CGFloat = right ? 1 : -1
        let top = lerp(CGPoint(x: spine, y: yb), CGPoint(x: spine + sign * (half - 6), y: yb), u)
        let bottom = lerp(CGPoint(x: spine, y: yb + depth), CGPoint(x: spine + sign * half, y: yb + depth), u)
        return lerp(top, bottom, v)
    }

    private static func lineEnds(_ yb: CGFloat) -> [(CGPoint, CGPoint)] {
        ruledRows.map { (page(yb, right: true, 0.17, $0), page(yb, right: true, 0.8, $0)) }
    }

    /// Where the nib is and whether it is touching the paper.
    private static func nib(_ t: Double, _ yb: CGFloat) -> (CGPoint, Bool) {
        let rows = lineEnds(yb)
        for (k, row) in rows.enumerated() {
            let start = rowStart + rowStep * Double(k)
            if t >= start && t <= start + rowLength {
                let q = (t - start) / rowLength
                let at = lerp(row.0, row.1, CGFloat(q))
                return (CGPoint(x: at.x, y: at.y - 3 * abs(CGFloat(sin(2 * .pi * q * 7)))), (q * 3).truncatingRemainder(dividingBy: 1) < 0.8)
            }
            if k < 3, t >= start + rowLength, t < start + rowStep {
                return (lerp(row.1, rows[k + 1].0, CGFloat(Motion.smooth((t - start - rowLength) / (rowStep - rowLength)))), false)
            }
        }
        let end = rowStart + rowStep * 3 + rowLength
        if t >= end { return (lerp(rows[3].1, rows[0].0, CGFloat(Motion.smooth(min(1, (t - end) / 0.09)))), false) }
        return (rows[0].0, false)
    }

    private static func writing(_ rig: SVGRig, _ c: MascotCharacter, _ t: Double, _ yb: CGFloat) -> (Pose, CGPoint, CGPoint) {
        var p = basePose(c, t, lean: 2 * Motion.keys(t, [(0, 0), (0.1, 1), (0.8, 1), (0.95, 0), (1, 0)]))
        let tip = nib(t, yb).0
        aim(rig, c, &p, "r", at: CGPoint(x: tip.x - tipOffset.x, y: tip.y - tipOffset.y))
        aim(rig, c, &p, "l", at: CGPoint(x: spine - half + 18, y: yb + 20))
        return (p, tip, hand(rig, c, p, "r"))
    }

    // MARK: Drawing

    static func draw(_ c: MascotCharacter, phase t: Double, writing isWriting: Bool, in ctx: inout GraphicsContext) {
        let rig = SVGRig.named(c.rawValue)
        let yb = backEdge(rig)
        var pose: Pose
        var phi = 0.0
        var tip = CGPoint.zero, hold = CGPoint.zero
        let happy: Bool
        if isWriting {
            (pose, tip, hold) = writing(rig, c, t, yb)
            happy = t > 0.82
        } else {
            (pose, phi) = turning(rig, c, t, yb)
            happy = t > 0.5 && t < 0.85
        }
        let blink = Motion.blink(t, at: 0.9, width: 0.04)
        pose["eye-l"] = BonePose(sy: blink)
        pose["eye-r"] = BonePose(sy: blink)
        let faces = ["eyes-open": !happy, "eyes-happy": happy]

        var layer = ctx
        layer.concatenate(space.matrix)
        rig.draw(in: &layer, pose: pose, visibility: faces)

        drawBook(in: &ctx, yb: yb)
        if isWriting {
            let inkTill = min(t, rowStart + rowStep * 3 + rowLength)
            let fade = 1 - Motion.smooth(max(0, (t - 0.9) / 0.1))
            ink(in: &ctx, yb: yb, until: inkTill, opacity: fade)
        } else {
            flipping(in: &ctx, yb: yb, angle: phi)
        }
        var arms = ctx
        arms.concatenate(space.matrix)
        rig.drawBone("arm-l", in: &arms, pose: pose, visibility: faces)
        rig.drawBone("arm-r", in: &arms, pose: pose, visibility: faces)
        if isWriting { quill(in: &ctx, tip: tip, hand: hold) }
    }

    private static func quad(_ points: [CGPoint]) -> Path {
        Path { p in
            p.move(to: points[0])
            points.dropFirst().forEach { p.addLine(to: $0) }
            p.closeSubpath()
        }
    }

    private static func ruledLines(_ ctx: inout GraphicsContext, _ at: (CGFloat, CGFloat) -> CGPoint, rows: [CGFloat]) {
        for v in rows {
            var line = Path()
            line.move(to: at(0.14, v))
            line.addLine(to: at(0.86, v))
            ctx.stroke(line, with: fillColor(0xCDBE9F), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private static func drawBook(in ctx: inout GraphicsContext, yb: CGFloat) {
        let yf = yb + depth
        ctx.fill(Path(ellipseIn: CGRect(x: spine - half - 16, y: yf + 7, width: 2 * (half + 16), height: 14)), with: fillColor(0x3A2410, 0.14))
        let cover = quad([CGPoint(x: spine - half - 8, y: yb - 2), CGPoint(x: spine + half + 8, y: yb - 2),
                          CGPoint(x: spine + half + 12, y: yf + 10), CGPoint(x: spine - half - 12, y: yf + 10)])
        ctx.fill(cover, with: fillColor(0x9B3B2A))
        ctx.stroke(cover, with: fillColor(0x5E1F14), style: StrokeStyle(lineWidth: 3.5, lineJoin: .round))
        for i in 0..<3 {
            var edge = Path()
            edge.move(to: CGPoint(x: spine - half + 2, y: yf + 3 + CGFloat(i) * 2.5))
            edge.addLine(to: CGPoint(x: spine + half - 2, y: yf + 3 + CGFloat(i) * 2.5))
            ctx.stroke(edge, with: fillColor(0xE9DCC0), lineWidth: 1.6)
        }
        for right in [false, true] {
            let sign: CGFloat = right ? 1 : -1
            let shape = quad([CGPoint(x: spine, y: yb), CGPoint(x: spine + sign * (half - 6), y: yb),
                              CGPoint(x: spine + sign * half, y: yf), CGPoint(x: spine, y: yf)])
            let paper = Gradient(colors: [Color(.sRGB, red: 1, green: 0.98, blue: 0.93), Color(.sRGB, red: 0.92, green: 0.87, blue: 0.76)])
            ctx.fill(shape, with: .linearGradient(paper, startPoint: CGPoint(x: spine + sign * half, y: yb), endPoint: CGPoint(x: spine, y: yb)))
            ctx.stroke(shape, with: fillColor(0xB88252), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            ruledLines(&ctx, { page(yb, right: right, $0, $1) }, rows: ruledRows)
        }
    }

    private static func flipping(in ctx: inout GraphicsContext, yb: CGFloat, angle phi: Double) {
        guard phi > 0.5, phi < 179.5 else { return }
        let a = phi * .pi / 180, yf = yb + depth
        let sinA = CGFloat(sin(a)), cosA = CGFloat(cos(a))
        let st = CGPoint(x: spine, y: yb), sb = CGPoint(x: spine, y: yf)
        let ot = CGPoint(x: spine + (half - 6) * cosA, y: yb - lift * sinA)
        let ob = CGPoint(x: spine + half * cosA, y: yf - lift * 0.55 * sinA)
        let bulge = 16 * sinA
        let mt = lerp(st, ot, 0.5), mb = lerp(sb, ob, 0.5)
        let outline = Path { p in
            p.move(to: st)
            p.addQuadCurve(to: ot, control: CGPoint(x: mt.x, y: mt.y - bulge))
            p.addLine(to: ob)
            p.addQuadCurve(to: sb, control: CGPoint(x: mb.x, y: mb.y - bulge))
            p.closeSubpath()
        }
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 2))
            layer.fill(outline.offsetBy(dx: 3, dy: 5), with: fillColor(0x3A2410, 0.12))
        }
        let shade = 255 - 38 * Double(sinA)
        ctx.fill(outline, with: .color(Color(.sRGB, red: shade / 255, green: (shade - 4) / 255, blue: (shade - 18) / 255)))
        ctx.stroke(outline, with: fillColor(0xB88252), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        ruledLines(&ctx, { u, v in lerp(lerp(st, ot, u), lerp(sb, ob, u), v) }, rows: [0.22, 0.4, 0.58, 0.76])
    }

    private static func ink(in ctx: inout GraphicsContext, yb: CGFloat, until: Double, opacity: Double) {
        guard opacity > 0 else { return }
        var path = Path()
        var drawing = false
        let steps = 360
        for i in 0...Int(until * Double(steps)) {
            let (point, down) = nib(Double(i) / Double(steps), yb)
            if down {
                if drawing { path.addLine(to: point) } else { path.move(to: point) }
            }
            drawing = down
        }
        ctx.stroke(path, with: fillColor(0x25256B, opacity), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
    }

    /// The nib stays on the line; the shaft runs from it through the hand.
    private static func quill(in ctx: inout GraphicsContext, tip: CGPoint, hand: CGPoint) {
        var dx = hand.x - tip.x, dy = hand.y - tip.y
        let length = max(1, hypot(dx, dy))
        dx /= length; dy /= length
        let base = CGPoint(x: tip.x + dx * 32, y: tip.y + dy * 32), end = CGPoint(x: tip.x + dx * 92, y: tip.y + dy * 92)
        let nx = -dy, ny = dx
        let vane = Path { p in
            p.move(to: base)
            p.addCurve(to: end, control1: CGPoint(x: base.x + nx * 14 + dx * 12, y: base.y + ny * 14 + dy * 12), control2: CGPoint(x: end.x + nx * 18, y: end.y + ny * 18))
            p.addCurve(to: base, control1: CGPoint(x: end.x - nx * 6, y: end.y - ny * 6), control2: CGPoint(x: base.x - nx * 4, y: base.y - ny * 4))
            p.closeSubpath()
        }
        var shaft = Path()
        shaft.move(to: tip)
        shaft.addLine(to: end)
        ctx.stroke(shaft, with: fillColor(0x4A3A28), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        ctx.fill(vane, with: fillColor(0xFBF6EC))
        ctx.stroke(vane, with: fillColor(0x8C7A5B), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 2.2, y: tip.y - 2.2, width: 4.4, height: 4.4)), with: fillColor(0x1F1F55))
    }
}
