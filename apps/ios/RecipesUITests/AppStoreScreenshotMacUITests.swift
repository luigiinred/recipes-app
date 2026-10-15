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
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-recipeListStyle", "list", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "YES", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts[hero].firstMatch.waitForExistence(timeout: 40), "library should load")
        app.menuBars.menuBarItems["Window"].click()
        app.menuItems["Zoom"].click()
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
        default:
            XCTFail("Unknown scene \(scene)")
        }

        sleep(3)
        let png = app.windows.firstMatch.screenshot().pngRepresentation
        let saved = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("app-store-\(scene).png")
        try png.write(to: saved)
        print("APP_STORE_SHOT \(saved.path)")
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
