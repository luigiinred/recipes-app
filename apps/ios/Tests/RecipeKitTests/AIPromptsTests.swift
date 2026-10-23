import XCTest
@testable import RecipeKit

final class AIPromptsTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "AIPromptsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDefaultsApplyUntilCustomizingIsOn() {
        let defaults = defaults()
        defaults.set("Write it in pirate.", forKey: AIAction.splitSteps.textKey)
        XCTAssertEqual(AIAction.splitSteps.instructions(defaults: defaults), AIAction.splitSteps.defaultInstructions)

        defaults.set(true, forKey: AIAction.splitSteps.isCustomizedKey)
        XCTAssertEqual(AIAction.splitSteps.instructions(defaults: defaults), "Write it in pirate.")
    }

    func testEmptyCustomPromptFallsBackToDefault() {
        let defaults = defaults()
        defaults.set(true, forKey: AIAction.planWeek.isCustomizedKey)
        defaults.set("  \n ", forKey: AIAction.planWeek.textKey)
        XCTAssertEqual(AIAction.planWeek.instructions(defaults: defaults), AIAction.planWeek.defaultInstructions)
    }

    func testCustomizingOneActionLeavesTheOthers() {
        let defaults = defaults()
        defaults.set(true, forKey: AIAction.webPage.isCustomizedKey)
        defaults.set("Custom", forKey: AIAction.webPage.textKey)
        XCTAssertEqual(AIAction.videoCaptions.instructions(defaults: defaults), AIAction.videoCaptions.defaultInstructions)
    }
}
