import XCTest
@testable import RecipeKit

final class RecipeCleanupTests: XCTestCase {
    func testTidyRecipeHasNothingToSuggest() async {
        let recipe = Recipe(title: "Toast", ingredients: ["2 slices bread", "1 tbsp butter"], steps: ["Toast the bread.", "Butter it."]).standardized()
        let cleanup = await RecipeCleanup.suggest(for: recipe)
        XCTAssertTrue(cleanup.isEmpty, cleanup.summary)
    }

    func testMessyIngredientsAreTidied() async {
        let recipe = Recipe(title: "Toast", ingredients: ["• 0.5 cup milk", "2 Tablespoons butter"], steps: ["Toast the bread."])
        let cleanup = await RecipeCleanup.suggest(for: recipe)
        XCTAssertEqual(cleanup.recipe.ingredients, ["1/2 cup milk", "2 tbsp butter"])
        XCTAssertEqual(cleanup.summary, "Tidy 2 ingredients.")
    }

    func testFingerprintFollowsContent() {
        let recipe = Recipe(title: "Toast", ingredients: ["1 slice bread"], steps: ["Toast it."])
        var changed = recipe
        XCTAssertEqual(recipe.cleanupFingerprint, changed.cleanupFingerprint)
        changed.steps = ["Toast it well."]
        XCTAssertNotEqual(recipe.cleanupFingerprint, changed.cleanupFingerprint)
    }
}
