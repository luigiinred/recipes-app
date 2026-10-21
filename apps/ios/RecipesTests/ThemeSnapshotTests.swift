import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Theme and timeline", .serialized)
@MainActor
struct ThemeSnapshotTests {
    private func with(_ appearance: Appearance, _ body: () -> Void) {
        SampleData.defaults.set(appearance.rawValue, forKey: AppSettings.Key.appearance)
        defer { SampleData.defaults.removeObject(forKey: AppSettings.Key.appearance) }
        body()
    }

    @Test("theme settings")
    func settings() {
        assertPageSnapshots(of: ThemeSettingsPage(), macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("sans serif font and a green accent")
    func fontAndAccent() {
        SampleData.defaults.set(FontStyle.rounded.rawValue, forKey: AppSettings.Key.fontStyle)
        SampleData.defaults.set("3E8E5A", forKey: AppSettings.Key.accentColor)
        defer {
            SampleData.defaults.removeObject(forKey: AppSettings.Key.fontStyle)
            SampleData.defaults.removeObject(forKey: AppSettings.Key.accentColor)
        }
        assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka), coverage: .sheet)
    }

    @Test("pitch black")
    func pitchBlack() {
        with(.black) { assertPageSnapshots(of: GroceriesView(layout: .combined)) }
    }

    @Test("sepia")
    func sepia() {
        with(.sepia) { assertPageSnapshots(of: GroceriesView(layout: .combined), coverage: .sheet) }
    }

    @Test("a recipe's timeline")
    func timeline() {
        assertPageSnapshots(of: RecipeTimelineSheet(recipeID: SampleData.chili.id), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
