#if os(iOS)
import RecipeKit
import XCTest

final class TabSearchUITests: XCTestCase {
    private var library: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        library = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        let recipes = Library(root: library).recipes
        _ = try recipes.save(Recipe(title: "Test Shakshuka", ingredients: ["2 eggs"], steps: ["Cook."]))
        _ = try recipes.save(Recipe(title: "Roasted Soup", ingredients: ["1 tomato"], steps: ["Roast."]))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: library)
    }

    func testSearchButtonExpandsIntoSearchField() {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO"]
        app.launch()

        XCTAssertTrue(app.staticTexts["All Recipes"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.searchFields.firstMatch.exists, "the recipes tab should not show a search bar at the top")

        let searchTab = app.tabBars.buttons["Search"].firstMatch
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "the search button should be in the tab bar")
        searchTab.tap()

        sleep(2)
        if !app.searchFields.firstMatch.exists { print("UI TREE AFTER TAP:\n" + app.debugDescription) }
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "tapping search should expand into a search field")
        field.tap()
        field.typeText("shak")
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/private/tmp/claude-501/search-expanded.png"))
        XCTAssertTrue(app.staticTexts["Test Shakshuka"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Roasted Soup"].exists, "results should be filtered by the query")
    }
}
#endif
