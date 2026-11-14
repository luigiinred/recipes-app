#if os(iOS)
import RecipeKit
import SwiftUI
import Testing
import UIKit
@testable import Recipes

@MainActor
struct ImportPreviewLayoutTests {
    @Test func wideRecipePhotoStaysWithinTheScreen() {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000)).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1000))
        }
        let recipe = Recipe(title: "Pasta", ingredients: ["1 cup flour"], steps: ["Mix."])
        let host = UIHostingController(rootView: RecipePreviewContent(recipe: recipe, imageData: photo))
        let size = host.sizeThatFits(in: CGSize(width: 390, height: 2000))
        #expect(size.width <= 390)
    }
}
#endif
