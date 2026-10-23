#if os(macOS)
import RecipeKit
import XCTest

final class SidebarNavigationUITests: XCTestCase {
    private var library: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        library = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        let recipes = Library(root: library).recipes
        _ = try recipes.save(Recipe(title: "Test Shakshuka", ingredients: ["2 eggs"], steps: ["Cook."], tags: ["Breakfast"]))
        _ = try recipes.save(Recipe(title: "Test Carbonara", ingredients: ["1 egg"], steps: ["Cook."], tags: ["Dinner/Pasta"]))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: library)
    }

    func testSidebarItemsSwitchPages() {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Test Shakshuka"].waitForExistence(timeout: 15), "recipe list should show the recipe")

        app.staticTexts["Plan"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Nothing in Up Next"].firstMatch.waitForExistence(timeout: 10), "Plan page should open on the Up Next queue")

        app.staticTexts["Groceries"].firstMatch.click()
        XCTAssertTrue(app.textFields["Add item"].firstMatch.waitForExistence(timeout: 10), "Groceries page should show the add field")

        app.staticTexts["All Recipes"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Test Shakshuka"].waitForExistence(timeout: 10), "All Recipes should list recipes again")

        app.staticTexts["Favorites"].firstMatch.click()
        XCTAssertFalse(app.staticTexts["Test Shakshuka"].waitForExistence(timeout: 2), "Favorites should be empty")
    }

    func testClickingACategoryShowsItsRecipes() {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Test Carbonara"].waitForExistence(timeout: 15), "recipe list should show the recipe")

        app.staticTexts["Breakfast"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Test Shakshuka"].waitForExistence(timeout: 10), "Breakfast should list its recipe")
        XCTAssertFalse(app.staticTexts["Test Carbonara"].waitForExistence(timeout: 2), "Breakfast should hide other recipes")

        app.staticTexts["Dinner"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Test Carbonara"].waitForExistence(timeout: 10), "a parent category should list its children's recipes")
        XCTAssertFalse(app.staticTexts["Test Shakshuka"].waitForExistence(timeout: 2), "Dinner should hide other recipes")

        app.staticTexts["Pasta"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Test Carbonara"].waitForExistence(timeout: 10), "a subcategory should list its recipe")
    }
}
#endif
