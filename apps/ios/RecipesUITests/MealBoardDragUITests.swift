import RecipeKit
import XCTest

final class MealBoardDragUITests: XCTestCase {
    private var root: URL!
    private var app: XCUIApplication!

    private var sunday: String {
        let calendar = Calendar.current
        return DayKey.string(from: calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date(), calendar: calendar)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        root = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        let library = Library(root: root)
        _ = try library.recipes.save(Recipe(title: "Queued Curry", ingredients: ["1 can chickpeas"], steps: ["Simmer."],
                                            wantToCook: true, queuedAt: Date(timeIntervalSince1970: 1)))
        _ = try library.recipes.save(Recipe(title: "Queued Chili", ingredients: ["1 can beans"], steps: ["Simmer."],
                                            wantToCook: true, queuedAt: Date(timeIntervalSince1970: 2)))
        _ = try library.recipes.save(Recipe(title: "Lentil Stew", ingredients: ["1 cup lentils"], steps: ["Stew."]))
    }

    /// Without My Recipes, an iPhone shows Up Next and Sunday side by side.
    private func launch(showsRecipes: Bool) {
        app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = root.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES"]
        app.launch()
        openPlan()
        XCTAssertTrue(element("board.upNext").waitForExistence(timeout: 15), "Plan opens the board")
        // A launch argument would pin the setting, so flip it as a person would.
        if element("board.recipes").exists != showsRecipes {
            app.buttons[showsRecipes ? "Show My Recipes" : "Hide My Recipes"].firstMatch.tap()
        }
        XCTAssertEqual(element("board.recipes").waitForExistence(timeout: 3), showsRecipes)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func openPlan() {
        #if os(macOS)
        XCTAssertTrue(app.staticTexts["Plan"].firstMatch.waitForExistence(timeout: 15))
        app.staticTexts["Plan"].firstMatch.click()
        #else
        let tab = app.tabBars.buttons["Plan"]
        if tab.waitForExistence(timeout: 10) { tab.tap() } else { app.buttons["Plan"].firstMatch.tap() }
        #endif
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    private var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    /// On iPhone a column is a pill; its cards show below once it's picked.
    private func card(_ title: String, in column: String) -> XCUIElement {
        guard isPhone else { return element(column).descendants(matching: .any)["board.card.\(title)"].firstMatch }
        element(column).tap()
        return element("board.page").descendants(matching: .any)["board.card.\(title)"].firstMatch
    }

    /// A day column may sit past the screen's edge on iPhone; drop onto the part that shows.
    private func drag(_ source: XCUIElement, onto target: XCUIElement) {
        XCTAssertTrue(source.waitForExistence(timeout: 5), "\(source) exists")
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(target) exists")
        let window = app.windows.firstMatch.frame
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        func point(_ frame: CGRect, y: CGFloat) -> XCUICoordinate {
            let visible = frame.intersection(window)
            return origin.withOffset(CGVector(dx: visible.midX - window.minX, dy: y - window.minY))
        }
        let from = point(source.frame, y: source.frame.midY)
        let to = point(target.frame, y: target.frame.minY + min(target.frame.height * 0.3, 200))
        #if os(macOS)
        from.click(forDuration: 0.6, thenDragTo: to)
        #else
        from.press(forDuration: 1.0, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.6)
        #endif
    }

    private func waitFor(_ condition: @escaping () throws -> Bool, _ message: String) {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if (try? condition()) == true { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail(message)
    }

    private func recipe(_ title: String) throws -> Recipe? { try Library(root: root).recipes.list().first { $0.title == title } }
    private func plan() throws -> [MealPlanEntry] { try Library(root: root).mealPlan.list() }

    func testDraggingARecipeFromMyRecipesQueuesIt() throws {
        launch(showsRecipes: true)
        drag(element("board.recipe.Lentil Stew"), onto: element("board.upNext"))
        waitFor({ try self.recipe("Lentil Stew")?.wantToCook == true }, "Lentil Stew joins Up Next")
        XCTAssertTrue(card("Lentil Stew", in: "board.upNext").waitForExistence(timeout: 5))
    }

    func testDraggingARecipeFromMyRecipesOntoADayPlansIt() throws {
        launch(showsRecipes: true)
        drag(element("board.recipe.Lentil Stew"), onto: element("board.day.\(sunday)"))
        waitFor({ try self.plan().contains { $0.title == "Lentil Stew" && $0.day == self.sunday } }, "Lentil Stew is planned on Sunday")
    }

    func testDraggingAnUpNextCardOntoADayPlansItAndDequeuesIt() throws {
        launch(showsRecipes: false)
        drag(card("Queued Curry", in: "board.upNext"), onto: element("board.day.\(sunday)"))
        waitFor({ try self.plan().contains { $0.title == "Queued Curry" } && self.recipe("Queued Curry")?.wantToCook == false },
                "Queued Curry moves from Up Next to Sunday")
        XCTAssertTrue(card("Queued Curry", in: "board.day.\(sunday)").waitForExistence(timeout: 5))
    }

    func testDraggingAPlannedMealBackToUpNextUnplansIt() throws {
        launch(showsRecipes: false)
        drag(card("Queued Curry", in: "board.upNext"), onto: element("board.day.\(sunday)"))
        waitFor({ try !self.plan().isEmpty }, "Queued Curry is planned first")
        drag(card("Queued Curry", in: "board.day.\(sunday)"), onto: element("board.upNext"))
        waitFor({ try self.plan().isEmpty && self.recipe("Queued Curry")?.wantToCook == true }, "Queued Curry goes back to Up Next; plan: \((try? plan().map { "\($0.title) \($0.day)" }) ?? []), queued: \((try? recipe("Queued Curry")?.wantToCook) ?? nil)")
    }

    func testDraggingAnUpNextCardOntoAnotherMovesItAhead() throws {
        launch(showsRecipes: false)
        drag(card("Queued Chili", in: "board.upNext"), onto: card("Queued Curry", in: "board.upNext"))
        waitFor({
            let chili = try self.recipe("Queued Chili")?.queuedAt ?? .distantFuture
            let curry = try self.recipe("Queued Curry")?.queuedAt ?? .distantPast
            return chili < curry
        }, "Queued Chili moves ahead of Queued Curry")
    }

    func testDraggingAnUpNextCardBackToMyRecipesRemovesIt() throws {
        try XCTSkipIf(isPhone, "an iPhone shows My Recipes in place of the cards, not beside them")
        launch(showsRecipes: true)
        drag(card("Queued Chili", in: "board.upNext"), onto: element("board.recipes"))
        waitFor({ try self.recipe("Queued Chili")?.wantToCook == false }, "Queued Chili leaves Up Next")
    }
}

extension MealBoardDragUITests {
    func testTappingAPillWhileMyRecipesShowsOpensItsCards() throws {
        launch(showsRecipes: true)
        try XCTSkipUnless(isPhone)
        element("board.upNext").tap()
        XCTAssertTrue(element("board.page").waitForExistence(timeout: 5), "tapping a pill swaps My Recipes for its cards")
    }
}
