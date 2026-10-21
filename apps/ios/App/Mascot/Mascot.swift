import SwiftUI

/// What a character is doing. Each is a looping animation of a rigged SVG in `Mascot/Rigs`.
enum MascotScene: String, CaseIterable {
    case idle, wave, hop, sour
    /// Tossing veggies in a wok, for anything that is loading.
    case stirFry
    /// Holding an empty wok.
    case emptyWok
    case bookPages, bookWrite

    /// Seconds per loop.
    var period: Double {
        switch self {
        case .idle, .emptyWok: 2
        case .wave: 1.8
        case .hop, .stirFry: 1.44
        case .sour: 1.6
        case .bookPages, .bookWrite: 1.92
        }
    }

    /// The point in the loop that reads best as a still.
    var stillPhase: Double {
        switch self {
        case .idle, .emptyWok: 0.25
        case .wave: 0.5
        case .hop: 0
        case .sour: 0.5
        case .stirFry: 0.33
        case .bookPages: 0.3
        case .bookWrite: 0.5
        }
    }

    /// The part of the artwork to fit in the view, in the art's own units.
    func rect(for character: MascotCharacter) -> CGRect {
        let bounds: CGRect
        switch character {
        case .tomato: bounds = CGRect(x: 67, y: 55, width: 266, height: 333)
        case .potato: bounds = CGRect(x: 86, y: 122, width: 228, height: 266)
        case .lemon: bounds = CGRect(x: 49, y: 62, width: 302, height: 326)
        case .chili: bounds = CGRect(x: 80, y: 66, width: 250, height: 321)
        }
        switch self {
        case .idle: return bounds.insetBy(dx: -10, dy: -10)
        case .wave: return bounds.insetBy(dx: -30, dy: -24)
        case .sour where character == .lemon: return bounds.insetBy(dx: -30, dy: -24)
        case .hop, .sour:
            var r = bounds.insetBy(dx: -24, dy: -8)
            r.origin.y -= 52
            r.size.height += 52
            return r
        case .stirFry, .emptyWok: return CGRect(x: 40, y: 45, width: 420, height: 320)
        case .bookPages, .bookWrite: return CGRect(x: 60, y: 70, width: 280, height: 320)
        }
    }
}

enum MascotCanvas {
    /// Draws one frame, fitted to `size`. `phase` is a position in the loop, 0 to 1.
    static func draw(_ scene: MascotScene, _ character: MascotCharacter, phase: Double, in context: inout GraphicsContext, size: CGSize) {
        let rect = scene.rect(for: character)
        let scale = min(size.width / rect.width, size.height / rect.height)
        context.translateBy(x: (size.width - rect.width * scale) / 2 - rect.minX * scale, y: (size.height - rect.height * scale) / 2 - rect.minY * scale)
        context.scaleBy(x: scale, y: scale)
        let t = phase - floor(phase)
        switch scene {
        case .idle, .wave, .hop, .sour:
            let frame: MascotFrame
            switch scene {
            case .wave: frame = MascotMotions.wave(character, t)
            case .hop: frame = MascotMotions.hop(character, t)
            case .sour: frame = MascotMotions.sour(character, t)
            default: frame = MascotMotions.idle(character, t)
            }
            SVGRig.named(character.rawValue).draw(in: &context, pose: frame.pose, visibility: frame.visible)
        case .stirFry: StirFryScene.draw(character, phase: t, tossing: true, in: &context, scale: scale)
        case .emptyWok: StirFryScene.draw(character, phase: t, tossing: false, in: &context, scale: scale)
        case .bookPages: BookScene.draw(character, phase: t, writing: false, in: &context)
        case .bookWrite: BookScene.draw(character, phase: t, writing: true, in: &context)
        }
    }
}

/// Picks who appears, so the same face isn't always the one doing the loading.
@MainActor
enum MascotCast {
    /// Tests and previews set this so screens always show the same character.
    static var deterministic = false
    private static var last: MascotCharacter?

    /// A random character, never the same twice in a row.
    static func next(fallback: MascotCharacter = .tomato) -> MascotCharacter {
        guard !deterministic else { return fallback }
        let pick = MascotCharacter.allCases.filter { $0 != last }.randomElement() ?? fallback
        last = pick
        return pick
    }
}

struct MascotView: View {
    var character: MascotCharacter
    var scene: MascotScene = .idle
    var height: CGFloat = 140
    /// Starts the loop part way through, so neighbours don't move in step.
    var phase: Double = 0
    /// Holds the loop at this position (0 to 1) for previews and snapshots.
    var frozenAt: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let rect = scene.rect(for: character)
        let still = frozenAt ?? (MascotCast.deterministic || reduceMotion ? scene.stillPhase : nil)
        Group {
            if let still {
                canvas(at: still)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    canvas(at: context.date.timeIntervalSinceReferenceDate / scene.period + phase)
                }
            }
        }
        .frame(width: height * rect.width / rect.height, height: height)
        .accessibilityHidden(true)
    }

    private func canvas(at phase: Double) -> some View {
        Canvas { context, size in
            MascotCanvas.draw(scene, character, phase: phase, in: &context, size: size)
        }
    }
}

/// A character tossing veggies in a wok, for anything that is loading. A different one each time it appears.
struct MascotLoader: View {
    var height: CGFloat = 160
    @State private var character: MascotCharacter
    var frozenAt: Double?

    init(height: CGFloat = 160, character: MascotCharacter? = nil, frozenAt: Double? = nil) {
        self.height = height
        self.frozenAt = frozenAt
        _character = State(initialValue: character ?? MascotCast.next())
    }

    var body: some View {
        MascotView(character: character, scene: .stirFry, height: height, frozenAt: frozenAt)
    }
}

/// Produce that sits around the illustrations as decoration.
enum Produce: String, CaseIterable {
    case basil, garlic, broccoli, carrot, peaPod, redPepper
}

struct ProduceView: View {
    let produce: Produce
    var height: CGFloat = 36
    var phase: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if MascotCast.deterministic || reduceMotion {
                canvas(at: 0.25)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                    canvas(at: context.date.timeIntervalSinceReferenceDate / 3 + phase)
                }
            }
        }
        .frame(width: height, height: height)
        .accessibilityHidden(true)
    }

    private func canvas(at phase: Double) -> some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.scaleBy(x: scale, y: scale)
            SVGRig.named(produce.rawValue).draw(in: &context, pose: ["sway": BonePose(rot: 4 * Motion.sine(phase))])
        }
    }
}
