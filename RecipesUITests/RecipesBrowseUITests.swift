#if os(iOS)
import RecipeKit
import XCTest

final class RecipesBrowseUITests: XCTestCase {
    private var library: URL!
    private var pieID: UUID!
    private let shots = "/private/tmp/claude-501/browse"

    override func setUpWithError() throws {
        continueAfterFailure = false
        library = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        let recipes = Library(root: library).recipes
        _ = try recipes.save(Recipe(title: "Chocolate Chip Cookies", ingredients: ["2 cups flour"], steps: ["Bake."], tags: ["Dessert/Cookies"]))
        _ = try recipes.save(Recipe(title: "Oatmeal Cookies", ingredients: ["1 cup oats"], steps: ["Bake."], tags: ["Dessert/Cookies"]))
        pieID = try recipes.save(Recipe(title: "Apple Pie", ingredients: ["6 apples"], steps: ["Bake."], tags: ["Dessert"])).id
        _ = try recipes.save(Recipe(title: "Black Bean Chili", ingredients: ["1 can beans"], steps: ["Simmer."], tags: ["Vegetarian", "Dinner"], isFavorite: true))
        try? FileManager.default.createDirectory(atPath: shots, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: library)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
    }

    func testDrillDownThroughCategories() {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO"]
        app.launch()

        XCTAssertTrue(app.staticTexts["All Recipes"].waitForExistence(timeout: 15), "home lists the built-in collections")
        XCTAssertTrue(app.staticTexts["Favorites"].exists)
        XCTAssertTrue(app.staticTexts["Dessert"].exists, "categories are listed on the home screen")
        XCTAssertTrue(app.staticTexts["Vegetarian"].exists)
        shot(app, "1-home")

        app.staticTexts["Dessert"].firstMatch.tap()
        sleep(1)
        shot(app, "2a-after-tap")
        if !app.staticTexts["Cookies"].waitForExistence(timeout: 5) { print("TREE:\n" + app.debugDescription) }
        XCTAssertTrue(app.staticTexts["Cookies"].exists, "Dessert shows its subcategory")
        XCTAssertTrue(app.staticTexts["Apple Pie"].exists, "and the recipes filed directly in it")
        XCTAssertFalse(app.staticTexts["Chocolate Chip Cookies"].exists, "recipes in a subcategory stay in the subcategory")
        shot(app, "2-dessert")

        app.staticTexts["Cookies"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Chocolate Chip Cookies"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Oatmeal Cookies"].exists)
        shot(app, "3-cookies")

        app.staticTexts["Chocolate Chip Cookies"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["2 cups flour"].waitForExistence(timeout: 5), "tapping a recipe opens it")
        shot(app, "4-recipe")
    }

    func testRecipeLinkOpensTheRecipe() {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["All Recipes"].waitForExistence(timeout: 15))

        XCUIDevice.shared.system.open(URL(string: "recipes://recipe/\(pieID.uuidString.lowercased())")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["Open"]
        if open.waitForExistence(timeout: 5) { open.tap() }
        XCTAssertTrue(app.staticTexts["6 apples"].waitForExistence(timeout: 10), "the link opens the recipe")
        shot(app, "5-deeplink")
    }
}
#endif
