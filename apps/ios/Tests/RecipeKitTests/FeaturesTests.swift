import XCTest
@testable import RecipeKit

final class FeaturesTests: XCTestCase {
    func testIdeaIsARecipeWithNothingToCook() {
        XCTAssertTrue(Recipe(title: "Spaghetti", notes: "Use the good pasta").isIdea)
        XCTAssertFalse(Recipe(title: "Spaghetti", ingredients: ["1 lb spaghetti"]).isIdea)
        XCTAssertFalse(Recipe(title: "Spaghetti", steps: ["Boil the pasta."]).isIdea)
    }

    func testRecipesFittingACategory() {
        let chili = Recipe(title: "Black Bean Chili", ingredients: ["1 can beans", "2 tbsp chili powder"], tags: ["Dinner/Mains"])
        let minestrone = Recipe(title: "Minestrone Soup", ingredients: ["1 onion", "2 cups broth"])
        let cake = Recipe(title: "Lemon Cake", ingredients: ["2 cups flour", "1 lemon"])
        let lemonade = Recipe(title: "Pink Lemonade", ingredients: ["4 lemons", "1 cup sugar"], tags: ["Drink"])
        let library = [chili, minestrone, cake, lemonade]

        XCTAssertEqual(RecipeTags.recipes(fitting: "Soup", among: library).map(\.title), ["Black Bean Chili", "Minestrone Soup"])
        XCTAssertEqual(RecipeTags.recipes(fitting: "Dessert", among: library).map(\.title), ["Lemon Cake"])
        XCTAssertEqual(RecipeTags.recipes(fitting: "Lemons", among: library).map(\.title), ["Lemon Cake", "Pink Lemonade"])
        XCTAssertEqual(RecipeTags.recipes(fitting: "Dinner/Mains", among: library).map(\.title), [])
        XCTAssertEqual(RecipeTags.recipes(fitting: "Dinner", among: [chili]).map(\.title), [])
    }

    func testDurationDetector() {
        func seconds(_ text: String) -> [Int] { DurationDetector.find(in: text).map(\.seconds) }
        XCTAssertEqual(seconds("Simmer for 10 minutes."), [600])
        XCTAssertEqual(seconds("Bake 1 hour 30 minutes, then rest 5 min"), [5400, 300])
        XCTAssertEqual(seconds("Cook 15-20 mins"), [1200])
        XCTAssertEqual(seconds("Boil 1.5 hours"), [5400])
        XCTAssertEqual(seconds("Stir for 30 seconds"), [30])
        XCTAssertEqual(seconds("Add 2 cups flour"), [])
    }

    func testTextParserWithHeadings() {
        let text = """
        Lemon Ricotta Pancakes
        Serves 4
        Prep time: 10 minutes
        Cook time: 20 minutes
        Light and fluffy.
        INGREDIENTS
        • 1 cup ricotta
        • 2 eggs
        METHOD
        1. Whisk the ricotta and
        eggs until smooth.
        2. Cook on a hot pan for 3 minutes per side.
        """
        let recipe = RecipeTextParser.parse(text)
        XCTAssertEqual(recipe.title, "Lemon Ricotta Pancakes")
        XCTAssertEqual(recipe.servings, 4)
        XCTAssertEqual(recipe.prepMinutes, 10)
        XCTAssertEqual(recipe.cookMinutes, 20)
        XCTAssertEqual(recipe.summary, "Light and fluffy.")
        XCTAssertEqual(recipe.ingredients, ["1 cup ricotta", "2 eggs"])
        XCTAssertEqual(recipe.steps, ["Whisk the ricotta and eggs until smooth.", "Cook on a hot pan for 3 minutes per side."])
    }

    func testTextParserWithoutHeadings() {
        let recipe = RecipeTextParser.parse("Toast\n2 slices bread\n1 tbsp butter\nToast the bread and butter it.")
        XCTAssertEqual(recipe.ingredients, ["2 slices bread", "1 tbsp butter"])
        XCTAssertEqual(recipe.steps, ["Toast the bread and butter it."])
    }

    func testFeedParsesRSSAndAtom() throws {
        let rss = """
        <?xml version="1.0"?><rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"><channel><title>Cook Blog</title>
        <item><title>Soup &amp; Bread</title><link>https://example.com/soup</link><pubDate>Wed, 01 Oct 2026 10:00:00 +0000</pubDate>
        <description><![CDATA[<p>Warm <b>soup</b>.</p><img src="/soup.jpg">]]></description></item></channel></rss>
        """
        let parsedRSS = try FeedParser.parse(Data(rss.utf8), baseURL: URL(string: "https://example.com/feed"))
        XCTAssertEqual(parsedRSS.title, "Cook Blog")
        XCTAssertEqual(parsedRSS.entries.first?.title, "Soup & Bread")
        XCTAssertEqual(parsedRSS.entries.first?.summary, "Warm soup.")
        XCTAssertEqual(parsedRSS.entries.first?.imageURL?.absoluteString, "https://example.com/soup.jpg")
        XCTAssertNotNil(parsedRSS.entries.first?.published)

        let atom = """
        <feed xmlns="http://www.w3.org/2005/Atom"><title>Atom Eats</title>
        <entry><title>Tart</title><link rel="alternate" href="https://example.com/tart"/><updated>2026-10-01T10:00:00Z</updated><summary>Sweet.</summary></entry></feed>
        """
        let parsedAtom = try FeedParser.parse(Data(atom.utf8))
        XCTAssertEqual(parsedAtom.title, "Atom Eats")
        XCTAssertEqual(parsedAtom.entries.map(\.link.absoluteString), ["https://example.com/tart"])
        XCTAssertThrowsError(try FeedParser.parse(Data("<html></html>".utf8)))
    }

    func testCollections() {
        let a = Recipe(title: "A", tags: ["soup"], isFavorite: true)
        let b = Recipe(title: "B", wantToCook: true)
        let all = [a, b]
        XCTAssertEqual(RecipeCollection.favorites.filter(all), [a])
        XCTAssertEqual(RecipeCollection.wantToCook.filter(all), [b])
        XCTAssertEqual(RecipeCollection.uncategorized.filter(all), [b])
        XCTAssertEqual(RecipeCollection.category("Soup").filter(all), [a])
    }

    func testPrintHTMLEscapes() {
        let html = RecipePrint.html(for: Recipe(title: "Mac & <Cheese>", ingredients: ["1 cup milk"], steps: ["Stir."]))
        XCTAssertTrue(html.contains("Mac &amp; &lt;Cheese&gt;"))
        XCTAssertTrue(html.contains("<li>1 cup milk</li>"))
    }
}

final class CategoryTreeTests: XCTestCase {
    func testBuildsNestedTreeWithImpliedParents() {
        let tree = CategoryTree.build(from: ["Dinner/Pasta", "Dinner/Mains/Curry", "Breakfast", "dinner/Soup"])
        XCTAssertEqual(tree.map(\.name), ["Breakfast", "Dinner"])
        XCTAssertEqual(tree[1].children.map(\.name), ["Mains", "Pasta", "Soup"])
        XCTAssertEqual(tree[1].children[0].children.map(\.path), ["Dinner/Mains/Curry"])
    }

    func testTagsFromCommaSeparatedInput() {
        XCTAssertEqual(CategoryTree.tags(from: " Dinner / Pasta, ,Soup,"), ["Dinner/Pasta", "Soup"])
    }

    func testCategoryFilterIncludesDescendants() {
        let pasta = Recipe(title: "Pasta", tags: ["Dinner/Pasta"])
        let soup = Recipe(title: "Soup", tags: ["Lunch"])
        let all = [pasta, soup]
        XCTAssertEqual(RecipeCollection.category("Dinner").filter(all), [pasta])
        XCTAssertEqual(RecipeCollection.category("dinner/pasta").filter(all), [pasta])
        XCTAssertEqual(RecipeCollection.category("Din").filter(all), [])
        XCTAssertEqual(RecipeCollection.category("Dinner/Pasta").title, "Pasta")
        XCTAssertEqual(CategoryTree.displayName("Dinner / Pasta"), "Dinner › Pasta")
    }
}

final class RecipeImagePromptTests: XCTestCase {
    func testDescriptionCapturesTheDish() {
        let recipe = Recipe(
            title: "Shakshuka", summary: "Eggs poached in a spiced tomato sauce.",
            ingredients: ["2 tbsp olive oil", "1 onion, diced", "1 red bell pepper, sliced", "1 can (400g) crushed tomatoes", "4 eggs", "Salt", "Fresh parsley, to serve"],
            steps: ["Soften the onion in the oil.", "Simmer the tomatoes for 10 minutes.", "Crack in the eggs and cover. Scatter with parsley and serve from the pan."],
            tags: ["Breakfast", "YouTube"]
        )
        let text = RecipePrompt.text(recipe)
        XCTAssertTrue(text.hasPrefix("Shakshuka. Eggs poached in a spiced tomato sauce."))
        XCTAssertTrue(text.contains("Made with onion, red bell pepper, crushed tomatoes, eggs, fresh parsley."))
        XCTAssertFalse(text.contains("olive oil"))
        XCTAssertTrue(text.contains("simmered"))
        XCTAssertTrue(text.contains("Presented: Scatter with parsley and serve from the pan."))
        XCTAssertTrue(text.hasSuffix("Category: Breakfast."))
    }

    func testMinimalRecipeStillDescribes() {
        XCTAssertEqual(RecipeImagePrompt.description(for: Recipe(title: "Toast")), "Toast.")
    }
}

private enum RecipePrompt {
    static func text(_ recipe: Recipe) -> String { RecipeImagePrompt.description(for: recipe) }
}

final class MealChoiceTests: XCTestCase {
    func testAutomaticFollowsTheClock() {
        XCTAssertEqual(Meal.fitting(hour: 8), .breakfast)
        XCTAssertEqual(Meal.fitting(hour: 12), .lunch)
        XCTAssertEqual(Meal.fitting(hour: 16), .snack)
        XCTAssertEqual(Meal.fitting(hour: 19), .dinner)
        XCTAssertEqual(Meal.fitting(hour: 23), .snack)
        XCTAssertEqual(Meal.fitting(hour: 2), .snack)
    }

    func testFixedChoicesIgnoreTheClock() {
        let evening = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 20))!
        XCTAssertEqual(MealChoice.automatic.resolved(at: evening), .dinner)
        XCTAssertEqual(MealChoice.breakfast.resolved(at: evening), .breakfast)
        XCTAssertEqual(MealChoice.lunch.resolved(at: evening), .lunch)
    }
}
