import SwiftUI
import Testing
@testable import Recipes

@Suite("Settings", .serialized)
@MainActor
struct SettingsSnapshotTests {
    @Test("settings")
    func settings() {
        assertPageSnapshots(of: SettingsView(
            intelligenceOverride: (.notEnabled, false),
            listing: URL(string: "https://apps.apple.com/app/id1")!,
            writeReview: URL(string: "https://apps.apple.com/app/id1?action=write-review")!
        ), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("reminders")
    func reminders() {
        assertPageSnapshots(of: RemindersSettingsPage(), macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("add a meal: Up Next and search")
    func addMealSheet() {
        assertPageSnapshots(of: AddMealSheet(day: SampleData.now, initialMeal: .lunch, source: .all), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
