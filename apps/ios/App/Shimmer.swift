import RecipeKit
import SwiftUI

extension View {
    /// Redacts the content to its shape and sweeps a highlight across it while it loads.
    func loadingPlaceholder() -> some View {
        redacted(reason: .placeholder).modifier(Shimmer()).accessibilityLabel("Loading")
    }
}

private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: sweeping ? geometry.size.width * 1.25 : -geometry.size.width * 0.75)
                }
                .mask(content)
                .allowsHitTesting(false)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { sweeping = true }
            }
    }
}

extension Recipe {
    /// Stand-in whose text gives a loading recipe page or row its shape.
    static let placeholder = Recipe(
        title: "A recipe title that's loading",
        summary: "A short description of the dish while it loads.",
        servings: 4, prepMinutes: 15, cookMinutes: 30,
        ingredients: ["2 cups of an ingredient", "1 tablespoon of another", "A pinch of something", "3 of something else, chopped", "1 cup of a liquid"],
        steps: ["The first step of the recipe, which takes a line or two to describe.", "The second step, a little shorter.", "A third step that finishes the dish and serves it."],
        tags: ["Loading"]
    )
}

/// A recipe page that's still loading, laid out like the real one.
struct RecipeDetailSkeleton: View {
    var body: some View {
        RecipeDetailView(recipe: .placeholder, previewSave: {}, previewImage: nil)
            .loadingPlaceholder()
            .allowsHitTesting(false)
    }
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
