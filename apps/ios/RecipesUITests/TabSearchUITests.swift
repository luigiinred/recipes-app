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

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES"] + arguments
        app.launch()
        return app
    }

    func testHomeSearchesFromTheHeader() {
        let app = launch()
        XCTAssertFalse(app.tabBars.buttons["Search"].waitForExistence(timeout: 5), "search is no longer a tab")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), "the first tab has a search bar in its header")
        shot("home")
        field.tap()
        field.typeText("shak")
        XCTAssertTrue(app.staticTexts["Test Shakshuka"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Roasted Soup"].waitForNonExistence(timeout: 5), "results should be filtered by the query")
    }

    func testRecipesCanBeTheFirstTab() {
        let app = launch(["-firstTab", "recipes"])
        XCTAssertTrue(app.tabBars.buttons["Recipes"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.staticTexts["Roasted Soup"].waitForExistence(timeout: 5), "Recipes lists every recipe")
        XCTAssertTrue(app.searchFields.firstMatch.exists)
        shot("recipes-first")
    }

    func testTabBarNeverHoldsMoreThanFive() {
        let app = launch(["-settingsInTabBar", "YES", "-hiddenTabs", ""])
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        XCTAssertLessThanOrEqual(app.tabBars.buttons.count, 5)
        XCTAssertFalse(app.tabBars.buttons["More"].exists)
        shot("five-tabs")
    }

    private func shot(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["TAB_SHOTS"] else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
    }
}
#endif
