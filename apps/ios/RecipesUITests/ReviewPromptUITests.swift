#if os(iOS)
import RecipeKit
import XCTest

final class ReviewPromptUITests: XCTestCase {
    private var library: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        library = FileManager.default.temporaryDirectory.appendingPathComponent("recipes-ui-\(UUID().uuidString)")
        let recipes = Library(root: library).recipes
        for index in 1...5 {
            _ = try recipes.save(Recipe(title: "Recipe \(index)", ingredients: ["1 egg"], steps: ["Cook."]))
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: library)
    }

    func testRateUsOpensTheAppStoreReviewPage() {
        let app = XCUIApplication()
        app.launchEnvironment["RECIPES_DIR"] = library.path
        app.launchArguments += ["-syncGroceriesWithReminders", "NO", "-onboardingCompleted", "YES", "-reviewPromptDismissed", "NO"]
        app.launch()

        let rateUs = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Rate us'")).firstMatch
        XCTAssertTrue(rateUs.waitForExistence(timeout: 15), "the banner should show once there are five recipes")
        rateUs.tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "the simulator has no App Store, so the review link opens in Safari")
    }
}
#endif
