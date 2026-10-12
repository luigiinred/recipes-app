import SwiftUI
import Testing
@testable import Recipes

@Suite("Settings", .serialized)
@MainActor
struct SettingsSnapshotTests {
    @Test("settings")
    func settings() {
        assertPageSnapshots(of: SettingsView(intelligenceOverride: (.notEnabled, false)), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("add to the planner: search and pick")
    func plannerAddSheet() {
        assertPageSnapshots(of: PlannerAddSheet(day: SampleData.now, initialMeal: .lunch), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
