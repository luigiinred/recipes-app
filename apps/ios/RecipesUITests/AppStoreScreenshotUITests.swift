#if os(iOS)
import XCTest

/// Drives the app to one screen and saves a screenshot for the App Store (`app-store/`). Skipped unless APP_STORE_SCENE is set.
final class AppStoreScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!
    private let hero = "Brown Butter Chocolate Chip Cookies"

    func testCapture() throws {
        let env = ProcessInfo.processInfo.environment
        guard let named = env["APP_STORE_SCENE"], let out = env["APP_STORE_OUT"], let library = env["APP_STORE_LIB"] else {
            throw XCTSkip("Not capturing App Store screenshots")
        }
        continueAfterFailure = false
        let dark = named.hasSuffix("-dark")
        let scene = named.replacingOccurrences(of: "-dark", with: "")

        app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-recipeListStyle", env["APP_STORE_STYLE"] ?? (scene == "list" ? "list" : "cards"), "-onboardingCompleted", "YES", "-defaultMeal", "lunch", "-reviewPromptDismissed", "YES"]
        if dark { app.launchArguments += ["-AppleInterfaceStyle", "Dark"] }
        if env["APP_STORE_LANDSCAPE"] == "1" { XCUIDevice.shared.orientation = .landscapeLeft }
        app.launch()

        let loaded = NSPredicate(format: "label == 'Brown Butter Chocolate Chip Cookies' OR label == '19'")
        XCTAssertTrue(app.staticTexts.matching(loaded).firstMatch.waitForExistence(timeout: 40), "library should load")
        sleep(3)
        let regular = app.windows.firstMatch.frame.width > 700
        if regular { showTopTabBar() }

        switch scene {
        case "home":
            break
        case "library":
            if regular { openRecipe(hero) } else { open("All Recipes") }
        case "list":
            open("All Recipes")
        case "recipe":
            if !regular { open("All Recipes") }
            openRecipe(hero)
        case "ingredients":
            if !regular { open("All Recipes") }
            openRecipe(hero)
            app.swipeUp()
            app.swipeUp()
        case "cook":
            if !regular { open("All Recipes") }
            openRecipe(hero)
            tapButton("Cook")
            sleep(3)
            app.swipeLeft()
            sleep(1)
            app.swipeLeft()
        case "plan":
            tab("Plan")
            tapButton("My Week")
            if regular { openRecipe("Thai Red Curry") }
        case "upnext":
            tab("Plan")
            if regular { openRecipe("Slow-Braised Beef") }
        case "groceries":
            tab("Groceries")
        case "settings":
            tab("Settings")
        case "roundtrip":
            tab("Settings")
            tab("Recipes")
        case "search":
            tab("Search")
        case "import":
            tapButton("Add Recipe")
            tapButton("Import from Web or YouTube…")
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            field.tap()
            field.typeText("http://localhost:8765/lemon-herb-gnocchi.html")
            tapButton("Import")
            let previewed = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Lemon Herb Gnocchi' OR value == 'Lemon Herb Gnocchi'")).firstMatch.waitForExistence(timeout: 40)
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(out)/\(named).png"))
            XCTAssertTrue(previewed, "the import should open a preview")
        case "idea":
            tab("Plan")
            tapButton("My Week")
            let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add meal on'")).allElementsBoundByIndex.first(where: \.isHittable)
            XCTAssertNotNil(add, "No Add meal button")
            add?.tap()
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8))
            field.tap()
            field.typeText("Taco night")
            tapButton("Add")
            XCTAssertTrue(app.staticTexts["Taco night"].firstMatch.waitForExistence(timeout: 8), "the idea should join the week")
            if regular { openRecipe("Thai Red Curry") }
        case "cleanup":
            if !regular { open("All Recipes") }
            openRecipe(hero)
            tapButton("More")
            tapButton("Edit")
            let cleanUp = app.buttons["Clean Up with Apple Intelligence"].firstMatch
            for _ in 0..<8 where !cleanUp.exists || !cleanUp.isHittable { app.swipeUp() }
            XCTAssertTrue(cleanUp.exists, "No Clean Up button")
        case "smartplan":
            tab("Plan")
            tapButton("My Week")
            tapButton("Smart Plan")
            sleep(8)
        default:
            XCTFail("Unknown scene \(scene)")
        }

        sleep(3)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: URL(fileURLWithPath: "\(out)/\(named).png"))
    }

    /// iPad remembers whether the tab bar is in the sidebar; the App Store shots show it across the top.
    private func showTopTabBar() {
        let hide = app.buttons["Hide Sidebar"].firstMatch
        guard hide.waitForExistence(timeout: 5) else { return }
        hide.tap()
        sleep(2)
    }

    private func open(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No \(title)")
        row.tap()
        sleep(1)
    }

    private func openRecipe(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No \(title)")
        row.tap()
        sleep(2)
    }

    /// A tab is a button in the top tab bar, or a row in the sidebar when the tab bar is built into it.
    private func tab(_ name: String) {
        let places = [app.tabBars.buttons[name], app.buttons[name], app.cells.staticTexts[name], app.staticTexts[name]].map(\.firstMatch)
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let target = places.first(where: { $0.exists && $0.isHittable }) {
                target.tap()
                sleep(1)
                return
            }
            usleep(300_000)
        }
        print(app.debugDescription)
        XCTFail("No tab \(name)")
    }

    private func tapButton(_ name: String) {
        XCTAssertTrue(app.buttons[name].firstMatch.waitForExistence(timeout: 8), "No button \(name)")
        let screen = app.windows.firstMatch.frame
        let candidates = app.buttons.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
        // Frames, not isHittable: a hidden copy has no hit point and makes XCTest fail. The visible one is the lowest.
        guard let button = candidates
            .filter({ $0.exists && !$0.frame.isEmpty && screen.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) })
            .max(by: { $0.frame.minY < $1.frame.minY }) else {
            return XCTFail("No visible button \(name)")
        }
        button.tap()
    }
}
#endif
