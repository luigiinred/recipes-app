import RecipeKit
import Testing
@testable import Recipes

@Suite("Review prompt")
struct ReviewPromptTests {
    private let cooked = Recipe(title: "Soup", ingredients: ["Water"], steps: ["Boil"])
    private func due(_ recipes: [Recipe], onboarded: Bool = true, dismissed: Bool = false) -> Bool {
        ReviewPrompt.isDue(recipes: recipes, onboarded: onboarded, dismissed: dismissed)
    }

    @Test("appears at five recipes, not before")
    func threshold() {
        #expect(!due(Array(repeating: cooked, count: 4)))
        #expect(due(Array(repeating: cooked, count: 5)))
    }

    @Test("ideas don't count toward the five")
    func ideas() {
        #expect(!due(Array(repeating: cooked, count: 4) + [Recipe(title: "Spaghetti")]))
    }

    @Test("stays away until onboarded and after a dismissal")
    func suppressed() {
        let five = Array(repeating: cooked, count: 5)
        #expect(!due(five, onboarded: false))
        #expect(!due(five, dismissed: true))
    }
}
