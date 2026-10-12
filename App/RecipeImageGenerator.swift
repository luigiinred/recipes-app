import ImagePlayground
import RecipeKit
import SwiftUI

extension View {
    /// Presents Image Playground seeded with everything the recipe says about the dish.
    func recipeImageGenerator(isPresented: Binding<Bool>, recipe: Recipe, onImage: @escaping (Data) -> Void) -> some View {
        imagePlaygroundSheet(
            isPresented: isPresented,
            concepts: [.text(recipe.title), .extracted(from: RecipeImagePrompt.description(for: recipe), title: recipe.title)]
        ) { url in
            guard let data = try? Data(contentsOf: url), let jpeg = RecipeImageProcessing.jpegData(from: data) else { return }
            onImage(jpeg)
        }
    }
}
