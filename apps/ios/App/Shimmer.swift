import RecipeKit
import SwiftUI

extension View {
    /// Redacts the content to its shape and sweeps a highlight across it while it loads.
    func loadingPlaceholder() -> some View {
        redacted(reason: .placeholder).modifier(Shimmer()).accessibilityLabel("Loading")
    }
}

/// Fades the content's one copy as a band sweeps across, so overlapping shapes never draw twice.
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .mask {
                    GeometryReader { geometry in
                        LinearGradient(
                            stops: [.init(color: .black.opacity(0.55), location: 0.35), .init(color: .black, location: 0.5), .init(color: .black.opacity(0.55), location: 0.65)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 3)
                        .offset(x: sweeping ? 0 : -geometry.size.width * 2)
                    }
                }
                .onAppear { withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { sweeping = true } }
        }
    }
}

extension Recipe {
    /// Stand-in whose text gives a loading recipe page or row its shape.
    static let placeholder = Recipe(
        title: "A recipe title that's loading",
        summary: "A short description of the dish while it loads.",
        servings: 4, prepMinutes: 15, cookMinutes: 30,
        ingredients: ["An ingredient for the dish", "Another ingredient", "Something to season it", "Something else, chopped", "A little liquid"],
        steps: ["The first step of the recipe, which takes a line or two to describe.", "The second step, a little shorter.", "A third step that finishes the dish and serves it."],
        tags: ["Loading"]
    )
}

/// A recipe page that's still loading, laid out like the real one so it can fade into it without moving.
struct RecipeDetailSkeleton: View {
    var hasPhoto = true

    var body: some View {
        RecipeDetailView(recipe: .placeholder, previewSave: {}, previewImage: nil, reservesArtwork: hasPhoto)
            .loadingPlaceholder()
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

extension Animation {
    static let recipeArrives = Animation.smooth(duration: 0.4)
}

/// Recipe rows that are still loading.
struct RecipeRowsSkeleton: View {
    var count = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<count, id: \.self) { _ in RecipeRow(recipe: .placeholder) }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .loadingPlaceholder()
        .allowsHitTesting(false)
    }
}
