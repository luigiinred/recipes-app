#if os(iOS)
import RecipeKit
import XCTest

final class TabAddUITests: XCTestCase {
    private var library: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        library = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        let recipes = Library(root: library).recipes
        _ = try recipes.save(Recipe(title: "Test Shakshuka", ingredients: ["2 eggs"], steps: ["Cook."], wantToCook: true, queuedAt: Date(timeIntervalSince1970: 1)))
        _ = try recipes.save(Recipe(title: "Roasted Soup", ingredients: ["1 tomato"], steps: ["Roast."], wantToCook: true, queuedAt: Date(timeIntervalSince1970: 2)))
        app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["All Recipes"].waitForExistence(timeout: 15))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: library)
    }

    func testSearchButtonStaysSearchOnRecipes() {
        XCTAssertTrue(app.tabBars.buttons["Search"].exists)
        XCTAssertFalse(app.tabBars.buttons["Add"].exists)
    }

    func testPlanTabButtonAddsToUpNext() {
        app.tabBars.buttons["Plan"].tap()
        let add = app.tabBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the search button should become Add on Plan")
        XCTAssertFalse(app.tabBars.buttons["Search"].exists)
        add.tap()
        XCTAssertTrue(app.navigationBars["Add to Up Next"].waitForExistence(timeout: 5))
    }

    func testGroceriesTabButtonFocusesNewItemField() {
        app.tabBars.buttons["Groceries"].tap()
        let add = app.tabBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the Add item field should take focus")
    }

    func testSearchComesBackAfterLeavingPlan() {
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.tabBars.buttons["Add"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Recipes"].tap()
        XCTAssertTrue(app.tabBars.buttons["Search"].waitForExistence(timeout: 5))
    }

    func testUpNextReorderIsAnIconNotText() {
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.buttons["Reorder"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Edit"].exists)
        app.buttons["Reorder"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
    }
}
#endif
