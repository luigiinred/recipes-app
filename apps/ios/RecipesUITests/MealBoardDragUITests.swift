import RecipeKit
import XCTest

final class MealBoardDragUITests: XCTestCase {
    private var root: URL!
    private var app: XCUIApplication!

    /// Today is on screen everywhere: the iPhone strip opens centered on it, and wider boards show its week.
    private var today: String { DayKey.string(from: Date(), calendar: .current) }

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

    private func launch() {
        app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = root.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-navigationStyle", "tabs", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES", "-planShowsList", "NO"]
        app.launch()
        openPlan()
        XCTAssertTrue(element("board.upNext").waitForExistence(timeout: 15), "Plan opens the board")
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

    /// Every day is a column, and on iPhone the one in the middle of the pager is today's.
    private func card(_ title: String, in column: String) -> XCUIElement {
        element(column).descendants(matching: .any)["board.card.\(title)"].firstMatch
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
        from.press(forDuration: 0.5, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.6)
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

    func testAddingToADayUsesTheAddSearch() throws {
        launch()
        let add = app.buttons["board.add.\(today)"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let field = app.searchFields["Search recipes or type a meal"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "a day's add opens the same search as Up Next")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        field.typeText("Lentil")
        let row = app.buttons["add.row.Lentil Stew"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        waitFor({ try self.plan().contains { $0.title == "Lentil Stew" && $0.recipeID != nil && $0.day == self.today } }, "the picked recipe is planned today")
    }

    func testTypingWordsAndPressingReturnAddsThemToUpNext() throws {
        launch()
        app.buttons[isPhone ? "Add to Up Next" : "board.add.upNext"].firstMatch.tap()
        let field = app.searchFields["Search recipes or type a meal"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        field.typeText("Takeout tacos\n")
        waitFor({ try Library(root: self.root).upNextNotes.list().contains { $0.title == "Takeout tacos" } }, "the words join Up Next as they are")
        XCTAssertTrue(card("Takeout tacos", in: "board.upNext").waitForExistence(timeout: 5))
    }

    func testTappingAPillInTheNextWeekShowsThatDay() throws {
        launch()
        guard isPhone else { return }
        let nextWeek = DayKey.string(from: Calendar.current.date(byAdding: .day, value: 7, to: Date())!, calendar: .current)
        app.buttons["board.pill.\(today)"].firstMatch.swipeLeft()
        let pill = app.buttons["board.pill.\(nextWeek)"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        XCTAssertTrue(element("board.day.\(nextWeek)").waitForExistence(timeout: 5), "the pager follows the picked day")
    }

    func testListShowsTheWholeWeek() throws {
        launch()
        guard isPhone else { return }
        app.buttons["board.layout"].firstMatch.tap()
        XCTAssertTrue(app.buttons["board.add.\(today)"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'board.add.2'")).count, 1, "the list shows more than one day")
        app.buttons["board.layout"].firstMatch.tap()
    }

    func testDraggingAnUpNextCardOntoADayPlansItAndDequeuesIt() throws {
        launch()
        drag(card("Queued Curry", in: "board.upNext"), onto: element("board.day.\(today)"))
        waitFor({ try self.plan().contains { $0.title == "Queued Curry" } && self.recipe("Queued Curry")?.wantToCook == false },
                "Queued Curry moves from Up Next to today")
        XCTAssertTrue(card("Queued Curry", in: "board.day.\(today)").waitForExistence(timeout: 5))
    }

    func testDraggingAPlannedMealBackToUpNextUnplansIt() throws {
        launch()
        drag(card("Queued Curry", in: "board.upNext"), onto: element("board.day.\(today)"))
        waitFor({ try !self.plan().isEmpty }, "Queued Curry is planned first")
        drag(card("Queued Curry", in: "board.day.\(today)"), onto: element("board.upNext"))
        waitFor({ try self.plan().isEmpty && self.recipe("Queued Curry")?.wantToCook == true }, "Queued Curry goes back to Up Next; plan: \((try? plan().map { "\($0.title) \($0.day)" }) ?? []), queued: \((try? recipe("Queued Curry")?.wantToCook) ?? nil)")
    }

    func testDraggingAnUpNextCardOntoAnotherMovesItAhead() throws {
        launch()
        drag(card("Queued Chili", in: "board.upNext"), onto: card("Queued Curry", in: "board.upNext"))
        waitFor({
            let chili = try self.recipe("Queued Chili")?.queuedAt ?? .distantFuture
            let curry = try self.recipe("Queued Curry")?.queuedAt ?? .distantPast
            return chili < curry
        }, "Queued Chili moves ahead of Queued Curry")
    }
}

extension MealBoardDragUITests {
    func testDraggingAMealOntoAnotherMovesItAheadInTheDay() throws {
        let plan = Library(root: root).mealPlan
        try plan.save(MealPlanEntry(title: "Toast", day: today, meal: .dinner, position: 0))
        try plan.save(MealPlanEntry(title: "Soup", day: today, meal: .dinner, position: 1))
        launch()
        drag(card("Soup", in: "board.day.\(today)"), onto: card("Toast", in: "board.day.\(today)"))
        waitFor({
            let meals = try self.plan()
            let soup = meals.first { $0.title == "Soup" }?.position ?? .infinity
            let toast = meals.first { $0.title == "Toast" }?.position ?? -.infinity
            return soup < toast
        }, "Soup moves ahead of Toast")
    }
}

