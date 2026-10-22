#if os(iOS)
import RecipeKit
import XCTest

final class IPadSidebarUITests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        root = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        let recipes = Library(root: root).recipes
        for (title, tag) in [("Pancakes", "Breakfast"), ("Carbonara", "Dinner/Pasta"), ("Brownies", "Sweets")] {
            _ = try recipes.save(Recipe(title: title, ingredients: ["1 egg"], steps: ["Cook."], tags: [tag]))
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testSidebarNestsCollectionsAndCategoriesUnderRecipes() throws {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = root.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES"]
        app.launch()
        try XCTSkipUnless(app.windows.firstMatch.frame.width > 700, "needs an iPad-sized window")

        for name in ["Recipes", "Plan", "Groceries", "Settings"] {
            XCTAssertTrue(app.buttons[name].firstMatch.waitForExistence(timeout: 15), "\(name) stays in the top tab bar")
        }

        app.buttons["Toggle sidebar"].firstMatch.tap()
        func row(_ label: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        let breakfast = row("Breakfast")
        XCTAssertTrue(breakfast.waitForExistence(timeout: 10), "categories are listed under Recipes in the sidebar")
        XCTAssertTrue(row("Most Recent").exists)
        breakfast.tap()
        XCTAssertTrue(app.staticTexts["Pancakes"].firstMatch.waitForExistence(timeout: 10), "the category opens its recipes")
        XCTAssertFalse(app.staticTexts["Brownies"].firstMatch.exists, "and only its recipes")
    }
}
#endif
