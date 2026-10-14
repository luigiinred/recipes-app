import XCTest
@testable import RecipeKit

final class StandardsTests: XCTestCase {
    func testIngredientParsingAndStandardForm() {
        let cases: [(String, String, IngredientUnit?, String, String)] = [
            ("2 Tablespoons butter", "2", .tablespoon, "butter", "2 tbsp butter"),
            ("1 tablespoon olive oil", "1", .tablespoon, "olive oil", "1 tbsp olive oil"),
            ("500g black beans, dried", "500", .gram, "black beans, dried", "500 g black beans, dried"),
            ("1½ cup milk", "1 1/2", .cup, "milk", "1 1/2 cups milk"),
            ("½ cups flour", "1/2", .cup, "flour", "1/2 cup flour"),
            ("2 cloves of garlic, minced", "2", .clove, "garlic, minced", "2 cloves garlic, minced"),
            ("4 bell peppers", "4", nil, "bell peppers", "4 bell peppers"),
            ("2-3 lbs. chicken thighs", "2-3", .pound, "chicken thighs", "2-3 lb chicken thighs"),
            ("8 fl oz water", "8", .fluidOunce, "water", "8 fl oz water"),
            ("Salt to taste", "", nil, "Salt to taste", "Salt to taste"),
            ("2 cups", "", nil, "2 cups", "2 cups"),
        ]
        for (input, quantity, unit, item, text) in cases {
            let ingredient = Ingredient(parsing: input)
            XCTAssertEqual(ingredient.quantity, quantity, input)
            XCTAssertEqual(ingredient.unit, unit, input)
            XCTAssertEqual(ingredient.item, item, input)
            XCTAssertEqual(ingredient.text, text, input)
            XCTAssertEqual(Ingredient(parsing: ingredient.text).text, text, "idempotent: \(input)")
        }
    }

    func testIngredientPartsForDisplay() {
        let garlic = Ingredient(parsing: "3 Cloves garlic, minced")
        XCTAssertEqual(garlic.amount, "3 cloves")
        XCTAssertEqual(garlic.name, "garlic")
        XCTAssertEqual(garlic.preparation, "minced")
        let beans = Ingredient(parsing: "500g black beans, dried")
        XCTAssertEqual(beans.amount, "500 g")
        XCTAssertEqual(beans.name, "black beans")
        XCTAssertEqual(beans.preparation, "dried")
        let salt = Ingredient(parsing: "Salt to taste")
        XCTAssertEqual(salt.amount, "")
        XCTAssertEqual(salt.name, "Salt to taste")
        XCTAssertEqual(salt.preparation, "")
    }

    func testUnitWithoutQuantityReadsAsOne() {
        XCTAssertEqual(Ingredient(quantity: "", unit: .pinch, item: "salt").text, "1 pinch salt")
    }

    func testStepCleanup() {
        XCTAssertEqual(RecipeStandards.standardStep("  Step 2:  whisk   the eggs "), "Whisk the eggs.")
        XCTAssertEqual(RecipeStandards.standardStep("3) Bake for 20 minutes!"), "Bake for 20 minutes!")
        XCTAssertEqual(RecipeStandards.standardStep("• simmer"), "Simmer.")
        XCTAssertEqual(RecipeStandards.standardStep("   "), "")
    }

    func testStandardizedIsIdempotentAndKeepsTimestampsAligned() {
        let recipe = Recipe(
            title: "  Soup  ", ingredients: ["2 Tablespoons butter", "", "1 onion"], steps: ["1. chop", "", "simmer"],
            stepTimestamps: [5, 10, 15], tags: ["vegetarian", "Dinner/Soup", "Vegetarian"]
        )
        let once = recipe.standardized()
        XCTAssertEqual(once.title, "Soup")
        XCTAssertEqual(once.ingredients, ["2 tbsp butter", "1 onion"])
        XCTAssertEqual(once.steps, ["Chop.", "Simmer."])
        XCTAssertEqual(once.stepTimestamps, [5, 15])
        XCTAssertEqual(once.tags, ["Vegetarian", "Dinner/Soup"])
        XCTAssertEqual(once.standardized(), once)
    }

    func testTagSuggestionsAreGeneric() {
        let salmon = RecipeTags.suggest(
            title: "Lemon Garlic Salmon", ingredients: ["2 salmon fillets", "1 lemon", "3 cloves garlic", "2 tbsp butter"],
            sourceTerms: ["Main Course", "lemon", "garlic", "salmon", "easy", "quick dinner", "healthy"]
        )
        XCTAssertEqual(salmon, ["Fish", "Dinner"])

        let veg = RecipeTags.suggest(title: "Chickpea Curry", ingredients: ["2 cans chickpeas", "1 can coconut milk", "200 g spinach"], sourceTerms: ["Dinner"])
        XCTAssertEqual(veg, ["Beans", "Vegan", "Vegetarian", "Dinner"])

        let chicken = RecipeTags.suggest(title: "Chicken Noodle Soup", ingredients: ["1 chicken", "200 g noodles", "1 l chicken stock"])
        XCTAssertEqual(chicken, ["Chicken", "Soup"])

        let pancakes = RecipeTags.suggest(title: "Lemon Ricotta Pancakes", ingredients: ["1 cup ricotta", "3 eggs", "1/2 cup flour"])
        XCTAssertEqual(pancakes, ["Vegetarian", "Breakfast"])
    }

    func testImportedTitlesLoseTheSiteName() {
        XCTAssertEqual(RecipeStandards.importedTitle("Amazing White Chocolate Chip Cookies | Preppy Kitchen"), "Amazing White Chocolate Chip Cookies")
        XCTAssertEqual(RecipeStandards.importedTitle("The Best Chewy Chocolate Chip Cookies Recipe by Tasty"), "The Best Chewy Chocolate Chip Cookies")
        XCTAssertEqual(RecipeStandards.importedTitle("Gordon Ramsay Demonstrates Eggs | Season 8 Ep. 5 | MASTERCHEF"), "Gordon Ramsay Demonstrates Eggs")
        XCTAssertEqual(RecipeStandards.importedTitle("Mac and Cheese"), "Mac and Cheese")
    }

    func testSaveStandardizesIngredients() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let saved = try RecipeStore(directory: directory).save(Recipe(title: "Toast", ingredients: ["2 SLICES sourdough bread"], steps: ["toast it"], tags: ["breakfast"]))
        XCTAssertEqual(saved.ingredients, ["2 slices sourdough bread"])
        XCTAssertEqual(saved.steps, ["Toast it."])
        XCTAssertEqual(saved.tags, ["Breakfast"])
    }
}

final class StepImageTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testImportSavesStepImagesAndDeleteRemovesThem() throws {
        let library = Library(root: root)
        let photo = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let result = ImportResult(
            recipe: Recipe(title: "Bread", steps: ["Mix", "Rest", "Bake"]),
            stepImageData: [photo, nil, photo]
        )
        let saved = try library.add(result)
        XCTAssertEqual(saved.steps, ["Mix.", "Rest.", "Bake."])
        XCTAssertEqual(saved.stepImages.count, 3)
        XCTAssertNil(saved.stepImages[1])
        let first = try XCTUnwrap(saved.stepImage(forStep: 0))
        XCTAssertEqual(library.stepImages.data(for: first), photo)

        let export = try library.export()
        XCTAssertEqual(export.stepImages.count, 2)
        let decoded = try RecipeCoding.makeDecoder().decode(LibraryExport.self, from: try export.jsonData())
        XCTAssertEqual(decoded.stepImages[first.uuidString.lowercased()], photo)

        try library.deleteRecipe(saved)
        XCTAssertNil(library.stepImages.data(for: first))
    }

    func testDroppingAnEmptyStepKeepsImagesAligned() {
        let a = UUID(), c = UUID()
        let recipe = Recipe(title: "R", steps: ["One", " ", "Three"], stepImages: [a, UUID(), c]).standardized()
        XCTAssertEqual(recipe.steps, ["One.", "Three."])
        XCTAssertEqual(recipe.stepImages, [a, c])
    }

    func testOldRecipeFilesDecodeWithoutStepImages() throws {
        let json = #"{"title":"Old","steps":["Stir."]}"#
        let recipe = try RecipeCoding.makeDecoder().decode(Recipe.self, from: Data(json.utf8))
        XCTAssertTrue(recipe.stepImages.isEmpty)
        XCTAssertNil(recipe.stepImage(forStep: 0))
    }

    func testWebPageStepImagesFollowTheSteps() {
        let html = """
        <script type="application/ld+json">{"@type":"Recipe","name":"Bread","recipeInstructions":[
        {"@type":"HowToStep","text":"Mix.","image":"https://example.com/1.jpg"},
        {"@type":"HowToStep","text":"Bake."}]}</script>
        """
        XCTAssertEqual(RecipeImporter.stepImageURLs(fromHTML: html), ["https://example.com/1.jpg", nil])
        XCTAssertEqual(RecipeImporter.stepImageURLs(fromHTML: "<html></html>"), [])
    }
}

final class RatingAndQueueTests: XCTestCase {
    func testTopRatedAndQueueCollections() {
        let early = Date(timeIntervalSince1970: 1_000), late = Date(timeIntervalSince1970: 2_000)
        let a = Recipe(title: "A", rating: 5)
        let b = Recipe(title: "B", rating: 4)
        let c = Recipe(title: "C", rating: 3)
        let q1 = Recipe(title: "Q1", wantToCook: true, queuedAt: late)
        let q2 = Recipe(title: "Q2", wantToCook: true, queuedAt: early)
        let all = [c, b, a, q1, q2]
        XCTAssertEqual(RecipeCollection.topRated.filter(all).map(\.title), ["A", "B"])
        XCTAssertEqual(RecipeCollection.wantToCook.filter(all).map(\.title), ["Q2", "Q1"])
        XCTAssertEqual(RecipeCollection.smart(for: .favorites), [.recent, .favorites, .uncategorized])
        XCTAssertEqual(RecipeCollection.smart(for: .stars), [.recent, .topRated, .uncategorized])
    }

    func testSavingKeepsRatingValidAndQueueDateOnlyWhileQueued() {
        XCTAssertEqual(Recipe(title: "R", rating: 4).standardized().rating, 4)
        XCTAssertNil(Recipe(title: "R", rating: 9).standardized().rating)
        XCTAssertNil(Recipe(title: "R", rating: 0).standardized().rating)
        XCTAssertNil(Recipe(title: "R", wantToCook: false, queuedAt: Date()).standardized().queuedAt)
        XCTAssertNotNil(Recipe(title: "R", wantToCook: true, queuedAt: Date()).standardized().queuedAt)
    }

    func testOldFilesDecodeWithoutRatingOrQueueDate() throws {
        let recipe = try RecipeCoding.makeDecoder().decode(Recipe.self, from: Data(#"{"title":"Old","wantToCook":true}"#.utf8))
        XCTAssertNil(recipe.rating)
        XCTAssertNil(recipe.queuedAt)
        XCTAssertTrue(recipe.wantToCook)
    }
}

final class IngredientSectionTests: XCTestCase {
    func testMentionsMarkTheIngredientNamesInTheStep() {
        func found(_ step: String, _ list: [String]) -> [String] {
            IngredientMatcher.mentions(in: step, ingredients: list).map { String(step[$0]) }
        }
        XCTAssertEqual(found("Add the black beans and stir.", ["1 can black beans"]), ["black beans"])
        XCTAssertEqual(found("Scatter the parsley on top.", ["2 tbsp finely chopped fresh parsley"]), ["parsley"])
        XCTAssertEqual(found("Dice the onions.", ["1 onion"]), ["onions"])
        XCTAssertEqual(found("Fold in the berries.", ["1 cup blueberries"]), [])
        XCTAssertEqual(found("Heat the olive oil.", ["2 tbsp extra virgin olive oil"]), ["olive oil"])
    }

    func testStepsFindTheirIngredients() {
        let chili = [
            "500 g black beans, dried", "4 cans diced tomatoes", "1 can corn", "4 bell peppers", "1 onion", "2 cloves garlic",
            "5 tbsp tomato paste", "3 tbsp canola oil", "Vegetable broth", "Salt",
        ]
        let find = { (step: String) in IngredientMatcher.indices(in: step, ingredients: chili) }
        XCTAssertEqual(find("Soak the beans overnight in plenty of water."), [0])
        XCTAssertEqual(find("Fry the onion, garlic and peppers in the oil, then stir in the tomato paste."), [3, 4, 5, 6, 7])
        XCTAssertEqual(find("Add everything to the pot with the tomatoes, corn and broth and simmer for 15 minutes."), [1, 2, 8])
        XCTAssertEqual(find("Serve hot."), [])
    }

    func testSharedWordsDoNotLinkTheWrongIngredient() {
        let list = ["2 red bell peppers", "1 tsp black pepper", "1 tbsp olive oil", "1 tbsp canola oil", "1 tomato paste"]
        XCTAssertEqual(IngredientMatcher.indices(in: "Slice the bell peppers.", ingredients: list), [0])
        XCTAssertEqual(IngredientMatcher.indices(in: "Season with black pepper.", ingredients: list), [1])
    }

    func testGroupingReordersAndNumbersSections() throws {
        let list = ["2 potatoes", "1 tsp cinnamon", "2 tbsp oil", "2 tbsp sugar", "1 tsp salt"]
        let result = try XCTUnwrap(IngredientGrouper.apply([
            IngredientGrouper.Group(title: "Cinnamon sugar:", members: [3, 1]),
            IngredientGrouper.Group(title: "Chips", members: [0, 2, 4]),
        ], to: list))
        XCTAssertEqual(result.ingredients, ["1 tsp cinnamon", "2 tbsp sugar", "2 potatoes", "2 tbsp oil", "1 tsp salt"])
        XCTAssertEqual(result.sections, [IngredientSection(title: "Cinnamon sugar", start: 0), IngredientSection(title: "Chips", start: 2)])
    }

    func testGroupingKeepsUnclaimedIngredientsAndIgnoresSingleGroups() throws {
        let list = ["a", "b", "c", "d"]
        let result = try XCTUnwrap(IngredientGrouper.apply([IngredientGrouper.Group(title: "Main", members: [0, 1, 9])], to: list))
        XCTAssertEqual(result.sections.map(\.title), ["Main", "Other"])
        XCTAssertEqual(result.ingredients, list)
        XCTAssertNil(IngredientGrouper.apply([IngredientGrouper.Group(title: "All", members: [0, 1, 2, 3])], to: list))
    }

    func testSectionsSurviveStandardizingAndShowInMarkdown() {
        let recipe = Recipe(
            title: "Chips", ingredients: ["2 potatoes", " ", "1 tsp cinnamon", "2 tbsp sugar"],
            ingredientSections: [IngredientSection(title: "Chips", start: 0), IngredientSection(title: "Cinnamon sugar:", start: 2), IngredientSection(title: " ", start: 3)]
        ).standardized()
        XCTAssertEqual(recipe.ingredients, ["2 potatoes", "1 tsp cinnamon", "2 tbsp sugar"])
        XCTAssertEqual(recipe.ingredientSections, [IngredientSection(title: "Chips", start: 0), IngredientSection(title: "Cinnamon sugar", start: 1)])
        XCTAssertEqual(recipe.ingredientGroups.map { $0.items.count }, [1, 2])
        XCTAssertTrue(recipe.markdown.contains("### Cinnamon sugar"))
        XCTAssertEqual(recipe.standardized(), recipe)
    }

    func testIngredientsBeforeTheFirstHeadingFormAnUntitledGroup() {
        let recipe = Recipe(title: "R", ingredients: ["1 egg", "1 cup flour", "1 cup milk"], ingredientSections: [IngredientSection(title: "Batter", start: 1)])
        XCTAssertEqual(recipe.ingredientGroups.map { $0.title }, [nil, "Batter"])
    }

    func testTextParserTurnsSubheadingsIntoSections() {
        let recipe = RecipeTextParser.parse("""
        Halloween Chips
        Ingredients
        For the chips:
        2 potatoes
        2 tbsp olive oil
        Cinnamon sugar:
        2 tbsp sugar
        1 tsp cinnamon
        Method
        1. Bake.
        """)
        XCTAssertEqual(recipe.ingredients.count, 4)
        XCTAssertEqual(recipe.ingredientSections.map(\.title), ["For the chips", "Cinnamon sugar"])
        XCTAssertEqual(recipe.ingredientSections.map(\.start), [0, 2])
    }
}
