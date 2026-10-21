import RecipeKit
import SwiftUI

struct RecipeImageView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    let recipe: Recipe

    @State private var loaded: CGImage?

    var body: some View {
        let image = library.cachedThumbnail(for: recipe.id) ?? loaded
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.22), accent.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(Theme.accent.opacity(0.45))
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .task(id: library.imageStamps[recipe.id]) {
            loaded = await library.loadThumbnail(for: recipe.id)
        }
        .accessibilityHidden(true)
    }
}
