import RecipeKit
import Testing
@testable import Recipes

@Suite("Siri and Shortcuts entity")
@MainActor
struct IntentEntityTests {
    @Test("a recipe entity carries what Siri needs to find it")
    func entityMirrorsRecipe() {
        let recipe = SampleData.videoRecipe
        let entity = RecipeEntity(recipe)
        #expect(entity.id == recipe.id)
        #expect(entity.title == recipe.title)
        #expect(entity.categories == recipe.tags)
        #expect(entity.attributeSet.title == recipe.title)
    }
}
