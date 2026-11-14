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

final class RecipeCleanupChoicesTests: XCTestCase {
    func testEachChangeCanBeAcceptedOnItsOwn() async {
        let recipe = Recipe(
            title: "Salad",
            ingredients: ["• 0.5 cup olive oil", "1 lettuce", "DRESSING:", "2 Tablespoons vinegar"],
            steps: ["Wash the lettuce.", "  whisk   the dressing  "],
            notes: ""
        )
        let cleanup = await RecipeCleanup.suggest(for: recipe)
        XCTAssertEqual(Set(cleanup.changes.map(\.kind)), [.ingredient(0), .ingredient(3), .sections, .step(1)])

        let onlyFirst = cleanup.applying([.ingredient(0)])
        XCTAssertEqual(onlyFirst.ingredients, ["1/2 cup olive oil", "1 lettuce", "DRESSING:", "2 Tablespoons vinegar"])
        XCTAssertTrue(onlyFirst.ingredientSections.isEmpty)
        XCTAssertEqual(onlyFirst.steps, recipe.steps)

        let sections = cleanup.applying([.sections])
        XCTAssertEqual(sections.ingredients, ["• 0.5 cup olive oil", "1 lettuce", "2 Tablespoons vinegar"])
        XCTAssertEqual(sections.ingredientSections, [IngredientSection(title: "Dressing", start: 2)])

        XCTAssertEqual(cleanup.recipe.ingredients, ["1/2 cup olive oil", "1 lettuce", "2 tbsp vinegar"])
        XCTAssertEqual(cleanup.recipe.steps.last, "Whisk the dressing.")
        XCTAssertEqual(cleanup.applying([]), recipe)
    }

    func testASplitStepKeepsItsTimeOnTheFirstPart() async {
        var recipe = Recipe(title: "Stew", steps: ["Prep. 1. Brown the beef. 2. Add the onions. 3. Simmer for an hour.", "Serve."])
        recipe.stepTimestamps = [30, 90]
        let cleanup = await RecipeCleanup.suggest(for: recipe)
        let applied = cleanup.applying(Set(cleanup.changes.map(\.kind)))
        XCTAssertEqual(applied.steps.count, 4)
        XCTAssertEqual(applied.stepTimestamps, [30, nil, nil, 90])
        XCTAssertEqual(applied.notes, "Prep.")
    }

    func testWordDiff() {
        XCTAssertEqual(WordDiff.pieces(from: "2 Tablespoons butter", to: "2 tbsp butter"),
                       [.same("2"), .removed("Tablespoons"), .added("tbsp"), .same("butter")])
    }
}
