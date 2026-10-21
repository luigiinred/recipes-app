import SwiftUI

/// The tomato chef and friends, cut from the sprite sheets in `Design/Mascot`.
enum Mascot: String, CaseIterable {
    case tomatoWave, tomatoTablet, tomatoSpoon, tomatoLaptop, tomatoHug, tomatoBooks, tomatoGroceries
    case lemon, chili, potato
    case wokEmpty, wokVeg, burnerOrange, burnerBlue, steamPuff, steamWisp
    case broccoli, spinach, carrot, redPepper, mushroom, onion, peaPod, garlic, tomato, tomatoSlice, basil, yellowPepper, sparkle
}

struct MascotView: View {
    let mascot: Mascot
    var height: CGFloat = 140

    var body: some View {
        Image(mascot.rawValue)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// The tomato tossing veggies in its wok, for anything that is loading.
struct TomatoWokLoader: View {
    var height: CGFloat = 160
    /// Holds one frame (0 to 4) for previews and snapshots.
    var frame: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let step = 0.14
    /// Pan out, toss, steam, and back down.
    private static let sequence = [0, 1, 2, 3, 4, 4, 3, 2, 1]

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.step)) { context in
            Image("tomatoWok\(shown(at: context.date))")
                .resizable()
                .scaledToFit()
                .frame(height: height)
        }
        .accessibilityHidden(true)
    }

    private func shown(at date: Date) -> Int {
        if let frame { return min(max(frame, 0), 4) }
        if reduceMotion { return 2 }
        let tick = Int((date.timeIntervalSinceReferenceDate / Self.step).rounded(.down))
        return Self.sequence[((tick % Self.sequence.count) + Self.sequence.count) % Self.sequence.count]
    }
}

/// A few ingredients drifting around a mascot, as decoration.
struct IngredientScatter: View {
    let items: [Mascot]
    var size: CGFloat = 44

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.self) { MascotView(mascot: $0, height: size) }
        }
    }
}
