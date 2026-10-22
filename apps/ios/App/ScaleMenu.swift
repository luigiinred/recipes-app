import SwiftUI

/// Chooses how many times to make a recipe; ingredient amounts and servings follow.
struct ScaleMenu: View {
    @Binding var scale: Double

    static let choices: [(value: Double, title: String)] = [
        (0.5, "½×"), (1, "1×"), (1.5, "1½×"), (2, "2×"), (3, "3×"), (4, "4×"),
    ]

    private var title: String { Self.choices.first { $0.value == scale }?.title ?? "\(scale.formatted())×" }

    var body: some View {
        Menu {
            Picker("Scale", selection: $scale) {
                ForEach(Self.choices, id: \.value) { Text($0.title).tag($0.value) }
            }
        } label: {
            Label("Scale \(title)", systemImage: "slider.horizontal.3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(scale == 1 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.accent))
        }
        .accessibilityLabel("Scale recipe")
        .accessibilityValue(title)
    }
}
