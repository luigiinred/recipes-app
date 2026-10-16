#if os(macOS)
import XCTest

/// Saves a screenshot of the Mac window for the App Store (`app-store/`). Skipped unless APP_STORE_SCENE is set.
final class AppStoreScreenshotMacUITests: XCTestCase {
    private var app: XCUIApplication!
    private let hero = "Brown Butter Chocolate Chip Cookies"

    func testCapture() throws {
        let env = ProcessInfo.processInfo.environment
        guard let scene = env["APP_STORE_SCENE"], let library = env["APP_STORE_LIB"] else {
            throw XCTSkip("Not capturing App Store screenshots")
        }
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library
        app.launchEnvironment["RECIPES_WINDOW_SIZE"] = "1280x800"
        app.launchEnvironment["RECIPES_APPEARANCE"] = "light"
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-recipeListStyle", "list", "-onboardingCompleted", "YES", "-defaultMeal", "lunch", "-reviewPromptDismissed", "YES", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts[hero].firstMatch.waitForExistence(timeout: 40), "library should load")
        print("APP_STORE_WINDOW \(app.windows.firstMatch.frame)")
        // Folded category groups keep the sidebar from running into its footer.
        for triangle in app.disclosureTriangles.allElementsBoundByIndex.reversed() where triangle.isHittable { triangle.click() }
        sleep(3)

        switch scene {
        case "library":
            app.staticTexts[hero].firstMatch.click()
        case "plan":
            app.staticTexts["Plan"].firstMatch.click()
            let week = app.radioButtons["My Week"].firstMatch
            if week.waitForExistence(timeout: 5) { week.click() }
            sleep(1)
            openRecipe("Thai Red Curry")
        case "upnext":
            app.staticTexts["Plan"].firstMatch.click()
            openRecipe("Slow-Braised Beef")
        case "groceries":
            app.staticTexts["Groceries"].firstMatch.click()
        case "cook":
            openRecipe(hero)
            press("Cook")
            sleep(3)
            app.typeKey(.rightArrow, modifierFlags: [])
            sleep(1)
            app.typeKey(.rightArrow, modifierFlags: [])
        case "import":
            press("Add Recipe")
            press("Import from Web or YouTube…")
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            field.click()
            field.typeText("http://localhost:8765/lemon-herb-gnocchi.html")
            press("Import")
            let previewed = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Lemon Herb Gnocchi' OR value == 'Lemon Herb Gnocchi'")).firstMatch.waitForExistence(timeout: 40)
            XCTAssertTrue(previewed, "the import should open a preview")
        case "idea":
            app.staticTexts["Plan"].firstMatch.click()
            let week = app.radioButtons["My Week"].firstMatch
            if week.waitForExistence(timeout: 5) { week.click() }
            let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add meal on'")).firstMatch
            XCTAssertTrue(add.waitForExistence(timeout: 8), "No Add meal button")
            add.click()
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            field.click()
            field.typeText("Taco night")
            press("Add")
            sleep(3)
            let curry = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Thai Red Curry'")).firstMatch
            XCTAssertTrue(curry.waitForExistence(timeout: 8), "No Thai Red Curry")
            for _ in 0..<3 where app.staticTexts["Select a recipe"].exists {
                curry.click()
                sleep(2)
            }
        case "smartplan":
            app.staticTexts["Plan"].firstMatch.click()
            let week = app.radioButtons["My Week"].firstMatch
            if week.waitForExistence(timeout: 5) { week.click() }
            press("Smart Plan")
            sleep(6)
        case "cleanup":
            app.staticTexts[hero].firstMatch.click()
            press("More")
            press("Edit")
            let cleanUp = app.buttons["Clean Up with Apple Intelligence"].firstMatch
            for _ in 0..<12 where !cleanUp.exists || !cleanUp.isHittable { app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -800) }
            XCTAssertTrue(cleanUp.exists, "No Clean Up button")
        default:
            XCTFail("Unknown scene \(scene)")
        }

        sleep(3)
        app.activate()
        sleep(1)
        let png = app.windows.firstMatch.screenshot().pngRepresentation
        let saved = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("app-store-\(scene).png")
        try png.write(to: saved)
        print("APP_STORE_SHOT \(saved.path)")
    }

    /// Toolbar items surface as buttons, pop-up buttons, menu buttons or menu items depending on where they sit.
    private func press(_ name: String) {
        let places = [app.buttons[name], app.popUpButtons[name], app.menuButtons[name], app.menuItems[name]].map(\.firstMatch)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let target = places.first(where: { $0.exists && $0.isHittable }) {
                target.click()
                sleep(1)
                return
            }
            usleep(300_000)
        }
        XCTFail("No control \(name)")
    }

    /// A click right after a tab switch can land before the list is ready, so click again until the recipe opens.
    private func openRecipe(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), "No \(title)")
        for _ in 0..<3 {
            sleep(1)
            row.click()
            sleep(2)
            if !app.staticTexts["Select a recipe"].exists { return }
        }
    }
}
#endif
