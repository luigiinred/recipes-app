import XCTest
@testable import RecipeKit

final class RecipeImporterTests: XCTestCase {
    func testParsesGraphRecipe() throws {
        let html = """
        <html><head><script type="application/ld+json">
        {"@context":"https://schema.org","@graph":[{"@type":"WebSite","name":"Site"},
        {"@type":["Recipe"],"name":"Best Pancakes &amp; Syrup","description":"Fluffy.",
         "prepTime":"PT10M","cookTime":"PT1H15M","recipeYield":["4","4 servings"],
         "recipeIngredient":["1 cup flour","1 egg"],"keywords":"breakfast, easy","recipeCategory":"Breakfast",
         "recipeInstructions":[{"@type":"HowToSection","itemListElement":[{"@type":"HowToStep","text":"Mix."}]},
                               {"@type":"HowToStep","text":"Cook &amp; flip."}]}]}
        </script></head></html>
        """
        let recipe = try RecipeImporter.recipe(fromHTML: html, sourceURL: URL(string: "https://example.com/p"))
        XCTAssertEqual(recipe.title, "Best Pancakes & Syrup")
        XCTAssertEqual(recipe.prepMinutes, 10)
        XCTAssertEqual(recipe.cookMinutes, 75)
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.ingredients, ["1 cup flour", "1 egg"])
        XCTAssertEqual(recipe.steps, ["Mix.", "Cook & flip."])
        XCTAssertEqual(recipe.tags, ["Vegetarian", "Breakfast"])
        XCTAssertEqual(recipe.sourceURL, "https://example.com/p")
    }

    func testThrowsWithoutRecipe() {
        XCTAssertThrowsError(try RecipeImporter.recipe(fromHTML: "<html></html>", sourceURL: nil))
    }
}
