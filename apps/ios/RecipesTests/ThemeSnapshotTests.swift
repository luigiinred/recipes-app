import CoreText
import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Theme and timeline", .serialized)
@MainActor
struct ThemeSnapshotTests {
    private func with(_ appearance: Appearance, _ theme: ColorTheme = .classic, _ body: () -> Void) {
        SampleData.defaults.set(appearance.rawValue, forKey: AppSettings.Key.appearance)
        SampleData.defaults.set(theme.rawValue, forKey: AppSettings.Key.colorTheme)
        defer {
            SampleData.defaults.removeObject(forKey: AppSettings.Key.appearance)
            SampleData.defaults.removeObject(forKey: AppSettings.Key.colorTheme)
        }
        body()
    }

    @Test("theme settings")
    func settings() {
        assertPageSnapshots(of: ThemeSettingsPage(), macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("a colored theme hides the accent choice")
    func coloredSettings() {
        with(.system, .blueberry) { assertPageSnapshots(of: ThemeSettingsPage(), macSize: SnapshotEnvironment.macSheetSize) }
    }

    @Test("font page")
    func fontPage() {
        assertPageSnapshots(of: FontSettingsPage(), macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("a recipe in Georgia")
    func georgia() {
        SampleData.defaults.set(FontStyle.georgia.rawValue, forKey: AppSettings.Key.fontStyle)
        defer { SampleData.defaults.removeObject(forKey: AppSettings.Key.fontStyle) }
        assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka), coverage: .sheet)
    }

    @Test("every font family is installed", arguments: FontStyle.allCases.compactMap(\.family))
    func installed(_ family: String) {
        let font = CTFontCreateWithName(family as CFString, 12, nil)
        #expect(CTFontCopyFamilyName(font) as String == family)
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

    @Test("classic dark is pitch black")
    func classicDark() {
        with(.dark) { assertPageSnapshots(of: GroceriesView(layout: .combined)) }
    }

    #if os(iOS)
    @Test("dark: collections and categories on the Recipes home match")
    func darkRecipesHome() {
        with(.dark) { assertPageSnapshots(of: RootView(tab: .recipes), inNavigationStack: false) }
    }
    #endif

    @Test("paper in light")
    func paper() {
        with(.light, .paper) { assertPageSnapshots(of: GroceriesView(layout: .combined), coverage: .sheet) }
    }

    @Test("themes follow light and dark", arguments: [ColorTheme.paper, .tomato, .pear, .blueberry, .plum])
    func palette(_ theme: ColorTheme) {
        with(.system, theme) { assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka), named: theme.rawValue, coverage: .screen, testName: "palette") }
    }

    @Test("old themes become a theme and a mode")
    func migration() {
        let defaults = UserDefaults(suiteName: "ThemeMigration")!
        defer { defaults.removePersistentDomain(forName: "ThemeMigration") }
        for (legacy, theme, mode) in [("black", ColorTheme.classic, Appearance.dark), ("sepia", .paper, .light), ("rose", .tomato, .system), ("dark", .classic, .dark)] {
            defaults.removePersistentDomain(forName: "ThemeMigration")
            defaults.set(legacy, forKey: AppSettings.Key.appearance)
            ColorTheme.migrateLegacyAppearance(in: defaults)
            #expect(defaults.string(forKey: AppSettings.Key.appearance) == mode.rawValue, "\(legacy)")
            #expect(defaults.string(forKey: AppSettings.Key.colorTheme) == (legacy == "dark" ? nil : theme.rawValue), "\(legacy)")
        }
    }

    @Test("a custom theme on the recipe page and its builder")
    func custom() {
        let keys = [AppSettings.Key.customThemeDarkCanvas, AppSettings.Key.customThemeDarkSurface, AppSettings.Key.customThemeDarkAccent]
        SampleData.defaults.set("2F2E24", forKey: AppSettings.Key.customThemeDarkCanvas)
        SampleData.defaults.set("3E3D31", forKey: AppSettings.Key.customThemeDarkSurface)
        SampleData.defaults.set("B5A865", forKey: AppSettings.Key.customThemeDarkAccent)
        defer { keys.forEach { SampleData.defaults.removeObject(forKey: $0) } }
        with(.system, .custom) {
            assertPageSnapshots(of: RecipeDetailView(recipe: SampleData.shakshuka), named: "recipe")
            assertPageSnapshots(of: CustomThemePage(), named: "builder", macSize: SnapshotEnvironment.macSheetSize)
        }
    }

    @Test("paper reaches the bottom of an idea")
    func paperIdea() {
        with(.light, .paper) { assertPageSnapshots(of: RecipeDetailView(recipe: Recipe(title: "Sunday Sauce", summary: "Nonna's, from memory.")), coverage: .sheet) }
    }

    @Test("a recipe's timeline")
    func timeline() {
        assertPageSnapshots(of: RecipeTimelineSheet(recipeID: SampleData.chili.id), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
