import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Cook mode and timers", .serialized)
@MainActor
struct CookModeSnapshotTests {
    @Test("a step with a detected timer, running timers below")
    func step() {
        assertPageSnapshots(of: CookModeView(), inNavigationStack: false, coverage: .adaptive)
    }

    @Test("ingredients")
    func ingredients() {
        assertPageSnapshots(of: IngredientsSheet(recipe: SampleData.shakshuka), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("new timer")
    func newTimer() {
        assertPageSnapshots(of: AddTimerSheet(defaultLabel: "Shakshuka"), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("add a recipe to cook mode")
    func addRecipe() {
        assertPageSnapshots(of: CookRecipePicker(), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
