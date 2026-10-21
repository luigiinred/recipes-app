import SwiftUI

enum MascotCharacter: String, CaseIterable {
    case tomato, potato, lemon, chili

    /// Where the feet or the tip rest, the point squashing is done about.
    var ground: CGPoint { self == .chili ? CGPoint(x: 104, y: 376) : CGPoint(x: 200, y: 382) }
}

/// Everything needed to draw one frame: bone poses and which face parts show.
struct MascotFrame {
    var pose: Pose = [:]
    var visible: [String: Bool] = [:]
}

/// Easing, keyframes and waves shared by every animation. Time is a fraction of a loop, 0 to 1.
enum Motion {
    static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    /// Keyframes `(time, value)` with eased steps between them, looping.
    static func keys(_ t: Double, _ keys: [(Double, Double)]) -> Double {
        let t = t - floor(t)
        for (a, b) in zip(keys, keys.dropFirst()) where a.0 <= t && t <= b.0 {
            let u = b.0 == a.0 ? 0 : (t - a.0) / (b.0 - a.0)
            return a.1 + (b.1 - a.1) * smooth(u)
        }
        return keys.last?.1 ?? 0
    }

    static func sine(_ t: Double, _ cycles: Double = 1, _ phase: Double = 0) -> Double { sin(2 * .pi * (t * cycles + phase)) }

    /// Vertical eye scale: 1 open, dipping briefly to nearly closed around `at`.
    static func blink(_ t: Double, at: Double = 0.62, width: Double = 0.07) -> Double {
        let d = abs((t - at + 0.5).truncatingRemainder(dividingBy: 1) - 0.5)
        return d < width ? max(0.08, min(1, d / width)) : 1
    }
}

extension MascotFrame {
    /// Blinks both eyes; call after the rest of the pose is set.
    mutating func blink(_ t: Double, at: Double = 0.62, width: Double = 0.07) {
        let s = Motion.blink(t, at: at, width: width)
        pose["eye-l"] = BonePose(sy: s)
        pose["eye-r"] = BonePose(sy: s)
    }
}

/// The simple loops: a character on its own.
enum MascotMotions {
    static func idle(_ c: MascotCharacter, _ t: Double) -> MascotFrame {
        typealias M = Motion
        var f = MascotFrame()
        f.pose["body"] = BonePose(sx: 1 - 0.012 * M.sine(t), sy: 1 + 0.026 * M.sine(t))
        f.pose["arm-l"] = BonePose(rot: 4 * M.sine(t, 1, 0.15))
        f.pose["arm-r"] = BonePose(rot: -4 * M.sine(t, 1, 0.15))
        switch c {
        case .tomato:
            f.pose["hat"] = BonePose(dy: -1.5 * M.sine(t, 1, -0.1), rot: 2.2 * M.sine(t, 1, -0.12))
            f.pose["calyx"] = BonePose(rot: 3 * M.sine(t, 1, -0.2))
        case .lemon:
            f.pose["leaf"] = BonePose(rot: 5 * M.sine(t, 1, -0.15))
        case .chili:
            f.pose["root"] = BonePose(rot: 1.5 * M.sine(t), sx: 1 - 0.01 * M.sine(t), sy: 1 + 0.02 * M.sine(t), pivot: c.ground)
            f.pose["body"] = BonePose(skx: 5 * M.sine(t, 1, -0.2))
            f.pose["stem"] = BonePose(rot: 4 * M.sine(t, 1, -0.25))
        case .potato: break
        }
        f.blink(t)
        return f
    }

    static func wave(_ c: MascotCharacter, _ t: Double) -> MascotFrame {
        typealias M = Motion
        var f = MascotFrame()
        let lift = M.keys(t, [(0, 0), (0.14, 1), (0.86, 1), (1, 0)])
        let w = M.sine(t, 3)
        let breathe = BonePose(sx: 1 - 0.012 * M.sine(t), sy: 1 + 0.026 * M.sine(t))
        switch c {
        case .tomato, .potato:
            f.pose["arm-r"] = BonePose(rot: -126 * lift + 22 * w * lift)
            f.pose["arm-l"] = BonePose(rot: 3 * M.sine(t))
            var body = breathe
            body.rot = c == .tomato ? -3 * lift + w * lift : -2.5 * lift
            f.pose["body"] = body
            if c == .tomato {
                f.pose["hat"] = BonePose(rot: -3 * lift * M.sine(t, 3, -0.1))
                f.pose["calyx"] = BonePose(rot: 2 * M.sine(t, 3, -0.2))
            }
        case .lemon:
            f.pose["arm-l"] = BonePose(rot: -14 * lift + 12 * w * lift)
            f.pose["arm-r"] = BonePose(rot: 14 * lift - 12 * w * lift)
            var body = breathe
            body.rot = 3 * M.sine(t, 3) * lift
            f.pose["body"] = body
            f.pose["leaf"] = BonePose(rot: 6 * M.sine(t, 3, -0.2))
        case .chili:
            f.pose["arm-l"] = BonePose(rot: 38 * w * lift)
            f.pose["arm-r"] = BonePose(rot: -22 * M.sine(t, 3, 0.25) * lift)
            f.pose["root"] = BonePose(rot: 3 * M.sine(t, 3, 0.1) * lift, pivot: c.ground)
            f.pose["body"] = BonePose(skx: 7 * M.sine(t, 3, -0.25))
            f.pose["stem"] = BonePose(rot: 9 * M.sine(t, 3, -0.3))
        }
        f.blink(t)
        f.visible = ["eyes-open": lift < 0.5, "eyes-happy": lift >= 0.5]
        return f
    }

    static func hop(_ c: MascotCharacter, _ t: Double) -> MascotFrame {
        typealias M = Motion
        var f = MascotFrame()
        let (lift, k, air) = hopCurve(t)
        let amount = k < 0 ? 0.09 : 0.07
        let squash = (sx: 1 - amount * 0.7 * k, sy: 1 + amount * k)
        if c == .chili {
            f.pose["root"] = BonePose(dy: -lift, sx: squash.sx, sy: squash.sy, pivot: c.ground)
            f.pose["stem"] = BonePose(rot: -10 * k + 8 * air)
            f.pose["body"] = BonePose(rot: -3 * air, skx: -9 * air + 5 * k)
            f.pose["arm-l"] = BonePose(rot: -30 * air + 6 * k)
            f.pose["arm-r"] = BonePose(rot: 30 * air - 6 * k)
        } else {
            f.pose["root"] = BonePose(dy: -lift, sx: squash.sx, sy: squash.sy, pivot: c.ground)
            f.pose["body"] = BonePose(sx: 1 - 0.02 * k)
            f.pose["leg-l"] = BonePose(rot: -16 * air - 10 * k)
            f.pose["leg-r"] = BonePose(rot: 16 * air + 10 * k)
            let up = 60 * air + 18 * k
            f.pose["arm-l"] = BonePose(rot: c == .lemon ? up * 0.6 : -up)
            f.pose["arm-r"] = BonePose(rot: c == .lemon ? -up * 0.6 : up)
            if c == .tomato {
                f.pose["hat"] = BonePose(rot: -6 * air + 3 * k)
                f.pose["calyx"] = BonePose(rot: 8 * air)
            }
            if c == .lemon { f.pose["leaf"] = BonePose(rot: -14 * air + 8 * k) }
        }
        let squint = air == 0 && k <= -0.85 ? 0.3 : 1
        f.pose["eye-l"] = BonePose(sy: squint)
        f.pose["eye-r"] = BonePose(sy: squint)
        f.visible = c == .lemon ? ["eyes-open": false, "eyes-happy": true] : ["eyes-open": air < 0.5, "eyes-happy": air >= 0.5]
        return f
    }

    /// Lift in points, squash (-1) to stretch (+1), and 1 while airborne.
    private static func hopCurve(_ t: Double) -> (Double, Double, Double) {
        let s = Motion.smooth
        if t < 0.22 { return (0, -s(t / 0.22), 0) }
        if t < 0.30 { return (0, -1 + 2 * s((t - 0.22) / 0.08), 0) }
        if t < 0.68 { let u = (t - 0.30) / 0.38; return (44 * sin(.pi * u), 1 - 0.6 * s(u), 1) }
        if t < 0.78 { let u = (t - 0.68) / 0.10; return (0, -1.1 * s(u) + 0.4 * (1 - s(u)), 0) }
        let u = (t - 0.78) / 0.22
        return (0, -1.1 * (1 - s(u)) * (1 - u), 0)
    }

    /// The lemon biting something sour. Only the lemon has the face for it.
    static func sour(_ c: MascotCharacter, _ t: Double) -> MascotFrame {
        guard c == .lemon else { return hop(c, t) }
        typealias M = Motion
        var f = MascotFrame()
        let env = M.keys(t, [(0, 0), (0.2, 0), (0.28, 1), (0.74, 1), (0.86, 0), (1, 0)])
        let shake = env * M.sine(t, 9)
        f.pose["root"] = BonePose(dx: 2.2 * shake)
        f.pose["body"] = BonePose(rot: 2.5 * env * M.sine(t, 9, 0.25), sx: 1 - 0.08 * env, sy: 1 - 0.06 * env + 0.01 * M.sine(t, 18) * env)
        f.pose["leaf"] = BonePose(rot: 10 * shake)
        f.pose["arm-l"] = BonePose(rot: -118 * env + 4 * shake)
        f.pose["arm-r"] = BonePose(rot: 118 * env - 4 * shake)
        f.pose["leg-l"] = BonePose(rot: 2 * shake)
        f.pose["leg-r"] = BonePose(rot: -2 * shake)
        let on = t >= 0.24 && t < 0.8
        let wide = t >= 0.12 && t < 0.24
        f.visible = ["eyes-open": wide, "eyes-happy": !on && !wide, "eyes-sour": on, "brows": on, "mouth-open": !on, "mouth-sour": on]
        return f
    }
}
