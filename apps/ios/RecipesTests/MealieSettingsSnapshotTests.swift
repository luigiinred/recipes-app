import SwiftUI
import Testing
@testable import Recipes

@Suite("Mealie settings", .serialized)
@MainActor
struct MealieSettingsSnapshotTests {
    @Test("not connected")
    func disconnected() {
        assertPageSnapshots(
            of: MealieSettingsPage().environmentObject(MealieSyncController(previewing: .disconnected)),
            macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet
        )
    }

    @Test("connected")
    func connected() {
        let mealie = MealieSyncController(previewing: .idle, address: "https://mealie.example.com", username: "timmy")
        assertPageSnapshots(of: MealieSettingsPage().environmentObject(mealie), macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("sync stopped before deleting most recipes")
    func blocked() {
        let mealie = MealieSyncController(
            previewing: .failed("This would delete 40 items, which looks like a mistake. Nothing was changed.", canForce: true),
            address: "http://192.168.1.20:9925", username: "timmy"
        )
        assertPageSnapshots(of: MealieSettingsPage().environmentObject(mealie), macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
