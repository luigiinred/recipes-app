#if os(macOS)
import RecipeKit
import XCTest

final class CategoryDragUITests: XCTestCase {
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

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = root.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Sweets"].waitForExistence(timeout: 15), "sidebar should list the categories")
        return app
    }

    private func item(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let text = app.staticTexts[label].firstMatch
        if text.exists { return text }
        return app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    private func drag(_ app: XCUIApplication, _ source: String, onto target: String, at offset: CGFloat) {
        let from = item(app, source).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = item(app, target).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: offset))
        from.click(forDuration: 0.5, thenDragTo: to)
    }

    private func tags() throws -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: try Library(root: root).recipes.list().map { ($0.title, $0.tags) })
    }

    func testDroppingACategoryOnAnotherNestsIt() throws {
        let app = launch()
        drag(app, "Sweets", onto: "Breakfast", at: 0.5)
        let deadline = Date().addingTimeInterval(10)
        while try tags()["Brownies"] != ["Breakfast/Sweets"], Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
        XCTAssertEqual(try tags()["Brownies"], ["Breakfast/Sweets"])
        XCTAssertEqual(try tags()["Pancakes"], ["Breakfast"])
    }

    func testDroppingACategoryAboveAnotherReordersIt() throws {
        let app = launch()
        drag(app, "Sweets", onto: "Breakfast", at: 0.05)
        let store = Library(root: root).categoryOrder
        let deadline = Date().addingTimeInterval(10)
        while store.load().first != "Sweets", Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
        XCTAssertEqual(store.load().first, "Sweets")
        XCTAssertEqual(try tags()["Brownies"], ["Sweets"], "reordering leaves recipe tags alone")
    }

    func testDroppingARecipeOnACategoryFilesItThere() throws {
        let app = launch()
        XCTAssertTrue(item(app, "Brownies").waitForExistence(timeout: 10))
        drag(app, "Brownies", onto: "Breakfast", at: 0.5)
        let deadline = Date().addingTimeInterval(10)
        while try tags()["Brownies"] != ["Sweets", "Breakfast"], Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
        XCTAssertEqual(try tags()["Brownies"], ["Sweets", "Breakfast"])
    }

    func testDroppingASubcategoryOnRecipesTakesItOutOfItsParent() throws {
        let app = launch()
        XCTAssertTrue(item(app, "Pasta").waitForExistence(timeout: 10))
        drag(app, "Pasta", onto: "Recipes", at: 0.5)
        let deadline = Date().addingTimeInterval(10)
        while try tags()["Carbonara"] != ["Pasta"], Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
        XCTAssertEqual(try tags()["Carbonara"], ["Pasta"])
    }
}
#endif
