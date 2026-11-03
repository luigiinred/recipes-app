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

    @Test("dark, lighter than pitch black")
    func dark() {
        with(.dark) { assertPageSnapshots(of: GroceriesView(layout: .combined)) }
    }

    #if os(iOS)
    @Test("dark: collections and categories on the Recipes home match")
    func darkRecipesHome() {
        with(.dark) { assertPageSnapshots(of: RootView(tab: .recipes), inNavigationStack: false) }
    }
    #endif

    @Test("sepia")
    func sepia() {
        with(.sepia) { assertPageSnapshots(of: GroceriesView(layout: .combined), coverage: .sheet) }
    }

    @Test("cookbook palettes", arguments: [Appearance.butter, .linen, .olive, .rose, .crema, .mint, .blueberry, .chai, .cocoa])
    func palette(_ appearance: Appearance) {
        SampleData.defaults.set(appearance.accentHex, forKey: AppSettings.Key.accentColor)
        defer { SampleData.defaults.removeObject(forKey: AppSettings.Key.accentColor) }
        with(appearance) { assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka), named: appearance.rawValue, coverage: appearance.colorScheme == .dark ? .screen : .sheet, testName: "palette") }
    }

    @Test("a custom theme on the recipe page and its builder")
    func custom() {
        let keys = [AppSettings.Key.customThemeDark, AppSettings.Key.customThemeCanvas, AppSettings.Key.customThemeSurface, AppSettings.Key.accentColor]
        SampleData.defaults.set(true, forKey: AppSettings.Key.customThemeDark)
        SampleData.defaults.set("2F2E24", forKey: AppSettings.Key.customThemeCanvas)
        SampleData.defaults.set("3E3D31", forKey: AppSettings.Key.customThemeSurface)
        SampleData.defaults.set("B5A865", forKey: AppSettings.Key.accentColor)
        defer { keys.forEach { SampleData.defaults.removeObject(forKey: $0) } }
        with(.custom) {
            assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka), named: "recipe")
            assertPageSnapshots(of: CustomThemePage(), named: "builder", macSize: SnapshotEnvironment.macSheetSize)
        }
    }

    @Test("sepia reaches the bottom of an idea")
    func sepiaIdea() {
        with(.sepia) { assertPageSnapshots(of: RecipeDetailView(recipe: Recipe(title: "Sunday Sauce", summary: "Nonna's, from memory.")), coverage: .sheet) }
    }

    @Test("a recipe's timeline")
    func timeline() {
        assertPageSnapshots(of: RecipeTimelineSheet(recipeID: SampleData.chili.id), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
