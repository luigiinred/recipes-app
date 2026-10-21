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

    func testParsesCDATAWrappedRecipe() throws {
        let html = """
        <script type="application/ld+json">
        // <![CDATA[
        {"@context":"https://schema.org","@type":"Recipe","name":"Wrapped Soup",
         "recipeIngredient":["1 cup broth","1 tsp salt"],
         "recipeInstructions":[{"@type":"HowToStep","text":"Simmer."}]}
        // ]]>
        </script>
        """
        let recipe = try RecipeImporter.recipe(fromHTML: html, sourceURL: nil)
        XCTAssertEqual(recipe.title, "Wrapped Soup")
        XCTAssertEqual(recipe.ingredients, ["1 cup broth", "1 tsp salt"])
        XCTAssertEqual(recipe.steps, ["Simmer."])
    }

    func testParsesObjectSerializedLists() throws {
        let html = """
        <script type="application/ld+json">
        {"@context":"https://schema.org","@type":"Recipe","name":"Dict Recipe",
         "recipeIngredient":{"0":"1 cup flour","1":"2 eggs"},
         "recipeInstructions":{"0":"Whisk.","1":"Cook."}}
        </script>
        """
        let recipe = try RecipeImporter.recipe(fromHTML: html, sourceURL: nil)
        XCTAssertEqual(recipe.ingredients, ["1 cup flour", "2 eggs"])
        XCTAssertEqual(recipe.steps, ["Whisk.", "Cook."])
    }

    func testPageTextKeepsTheWordsAndDropsMarkup() {
        let html = """
        <html><head><title>Best Soup &amp; Stew | Kitchen</title><style>p { color: red }</style></head>
        <body><nav>Home Menu</nav><script>var x = "ignore";</script>
        <h1>Best Soup</h1><ul><li>2 cups stock</li><li>1 onion</li></ul>
        <p>Simmer   for 20 minutes.</p><!-- comment --></body></html>
        """
        XCTAssertEqual(RecipeImporter.pageTitle(fromHTML: html), "Best Soup & Stew | Kitchen")
        XCTAssertEqual(
            RecipeImporter.visibleText(fromHTML: html),
            "Best Soup\n2 cups stock\n1 onion\nSimmer for 20 minutes."
        )
    }
}
