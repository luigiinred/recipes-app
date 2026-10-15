import RecipeKit
import SwiftUI

struct StepImageView: View {
    @EnvironmentObject private var library: RecipeLibrary
    let id: UUID

    @State private var loaded: CGImage?

    var body: some View {
        Group {
            if let image = library.cachedStepImage(for: id) ?? loaded {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.1)).aspectRatio(16 / 10, contentMode: .fit)
            }
        }
        .task(id: library.stepImageStamps[id]) {
            loaded = await library.loadStepImage(for: id)
        }
        .accessibilityHidden(true)
    }
}
