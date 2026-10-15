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

    @Test("add a meal: Up Next and search")
    func addMealSheet() {
        assertPageSnapshots(of: AddMealSheet(day: SampleData.now, initialMeal: .lunch, source: .all), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
