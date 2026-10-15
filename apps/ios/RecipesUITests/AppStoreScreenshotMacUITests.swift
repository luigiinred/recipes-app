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
            let curry = app.staticTexts["Thai Red Curry"].firstMatch
            if curry.waitForExistence(timeout: 5) { curry.click() }
        case "upnext":
            app.staticTexts["Plan"].firstMatch.click()
            let beef = app.staticTexts["Slow-Braised Beef"].firstMatch
            if beef.waitForExistence(timeout: 5) { beef.click() }
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
}
#endif
