#if os(iOS)
import RecipeKit
import XCTest

final class ScaleUITests: XCTestCase {
    private var library: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        library = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        _ = try Library(root: library).recipes.save(Recipe(
            title: "Too Much Chocolate Cake", servings: 12,
            ingredients: ["1 (18.25 ounce) package devil's food cake mix", "1 cup sour cream", "1 to 2 oz cocoa", "4 eggs"],
            steps: ["Bake."], tags: ["Dessert"]
        ))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: library)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO"]
        app.launch()
        return app
    }

    func testScalingTheRecipeChangesTheIngredients() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["All Recipes"].waitForExistence(timeout: 15))
        app.staticTexts["Dessert"].firstMatch.tap()
        app.staticTexts["Too Much Chocolate Cake"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Servings"].waitForExistence(timeout: 5))

        app.buttons["Scale recipe"].firstMatch.tap()
        app.buttons["2×"].firstMatch.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["24"].exists, "servings double")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '2 packages'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '2-4 oz'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '8 eggs'")).firstMatch.exists)
    }
}
#endif
