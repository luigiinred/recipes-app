#if os(iOS)
import RecipeKit
import XCTest

final class CategoryDragIPadUITests: XCTestCase {
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

    private func launch() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = root.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES"]
        app.launch()
        try XCTSkipUnless(app.windows.firstMatch.frame.width > 700, "needs an iPad-sized window")
        XCTAssertTrue(tile(app, "Sweets").waitForExistence(timeout: 15), "the Recipes home should list the categories")
        return app
    }

    private func tile(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func drag(_ app: XCUIApplication, _ source: String, onto target: String, dx: CGFloat) {
        let from = tile(app, source).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = tile(app, target).coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5))
        from.press(forDuration: 1.0, thenDragTo: to)
    }

    private func tags() throws -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: try Library(root: root).recipes.list().map { ($0.title, $0.tags) })
    }

    func testDroppingATileOnAnotherNestsIt() throws {
        let app = try launch()
        drag(app, "Sweets", onto: "Breakfast", dx: 0.5)
        let deadline = Date().addingTimeInterval(10)
        while try tags()["Brownies"] != ["Breakfast/Sweets"], Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
        XCTAssertEqual(try tags()["Brownies"], ["Breakfast/Sweets"])
    }

    func testDroppingATileOnAnotherTilesLeadingEdgeReordersIt() throws {
        let app = try launch()
        drag(app, "Sweets", onto: "Breakfast", dx: 0.05)
        let store = Library(root: root).categoryOrder
        let deadline = Date().addingTimeInterval(10)
        while store.load().first != "Sweets", Date() < deadline { Thread.sleep(forTimeInterval: 0.3) }
        XCTAssertEqual(store.load().first, "Sweets")
        XCTAssertEqual(try tags()["Brownies"], ["Sweets"])
    }
}
#endif
