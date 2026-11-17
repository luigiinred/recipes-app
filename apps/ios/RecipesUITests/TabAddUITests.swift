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
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-navigationStyle", "tabs", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: library)
    }

    func testTabBarHasNoSearchOrAddTab() {
        XCTAssertFalse(app.tabBars.buttons["Search"].exists)
        XCTAssertFalse(app.tabBars.buttons["Add"].exists)
    }

    func testPlanUpNextPlusOpensASearch() {
        app.tabBars.buttons["Plan"].tap()
        let add = app.buttons["Add to Up Next"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Up Next has its own add button")
        add.tap()
        XCTAssertTrue(app.searchFields["Search recipes or type a meal"].waitForExistence(timeout: 5), "the + opens a search")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "its search is ready to type")
    }

    func testGroceriesTabButtonFocusesNewItemField() {
        app.tabBars.buttons["Groceries"].tap()
        let add = app.navigationBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the Add item field should take focus")
    }

    func testPlanHasNoAddInItsNavigationBar() {
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Plan My Week"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["Add"].exists)
    }
}
#endif
