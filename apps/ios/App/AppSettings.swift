import Foundation
import RecipeKit

/// User preferences, stored in UserDefaults so views can bind to them with @AppStorage.
/// A tab that Settings can hide. Home and Settings always show.
enum MainTab: String, CaseIterable {
    case feeds, upNext, plan, groceries

    var title: String {
        switch self {
        case .feeds: "Feeds"
        case .upNext: "Up Next"
        case .plan: "Plan"
        case .groceries: "Groceries"
        }
    }

    var symbol: String {
        switch self {
        case .feeds: "dot.radiowaves.up.forward"
        case .upNext: "text.line.first.and.arrowtriangle.forward"
        case .plan: "calendar"
        case .groceries: "checklist"
        }
    }
}

/// What the first tab opens on: the Home sections, or every recipe.
enum FirstTab: String, CaseIterable {
    case home, recipes

    var title: String {
        switch self {
        case .home: "Home"
        case .recipes: "Recipes"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .recipes: "book.closed"
        }
    }
}

enum AppSettings {
    enum Key {
        static let defaultMeal = "defaultMeal"
        static let hiddenMeals = "hiddenMeals"
        static let weekStart = "weekStart"
        static let reviewImports = "reviewImports"
        static let keepAwake = "keepAwakeWhileCooking"
        static let listStyle = "recipeListStyle"
        static let homeSort = "recipeHomeSort"
        static let defaultSort = "recipeDefaultSort"
        static let remembersSort = "rememberRecipeSort"
        static let quickChips = "recipeQuickChips"
        static let homeSections = "homeSections"
        static let hiddenHomeSections = "hiddenHomeSections"
        static let homeTipDismissed = "homeCustomizeTipDismissed"
        static let recipeDetails = "recipeDetails"
        static let reminders = "syncGroceriesWithReminders"
        static let ratingStyle = "ratingStyle"
        static let showDeleteSwipe = "showDeleteInSwipeActions"
        static let onboardingCompleted = "onboardingCompleted"
        static let reviewPromptDismissed = "reviewPromptDismissed"
        static let mealieServer = "mealieServer"
        static let mealieUser = "mealieUser"
        static let mealieList = "mealieShoppingList"
        static let mealieSyncPlan = "mealieSyncMealPlan"
        static let mealieSyncGroceries = "mealieSyncGroceries"
        static let appearance = "appearance"
        static let colorTheme = "colorTheme"
        static let fontStyle = "fontStyle"
        static let accentColor = "accentColorHex"
        static let customThemeCanvas = "customThemeCanvasHex"
        static let customThemeSurface = "customThemeSurfaceHex"
        static let customThemeAccent = "customThemeAccentHex"
        static let customThemeDarkCanvas = "customThemeDarkCanvasHex"
        static let customThemeDarkSurface = "customThemeDarkSurfaceHex"
        static let customThemeDarkAccent = "customThemeDarkAccentHex"
        static let hiddenTabs = "hiddenTabs"
        static let feedsOffline = "saveFeedsOffline"
        static let feedLayout = "feedLayout"
        static let settingsInTabBar = "settingsInTabBar"
        static let firstTab = "firstTab"

        static func reminderOn(_ kind: ReminderKind) -> String { "reminder.\(kind.rawValue).on" }
        static func reminderMinutes(_ kind: ReminderKind) -> String { "reminder.\(kind.rawValue).minutes" }
        static func reminderWeekday(_ kind: ReminderKind) -> String { "reminder.\(kind.rawValue).weekday" }
    }

    static func reminderPreferences(_ defaults: UserDefaults = .standard) -> ReminderPreferences {
        var preferences = ReminderPreferences()
        for kind in ReminderKind.allCases {
            let fallback = ReminderPreferences.defaultSetting(for: kind)
            preferences[kind] = ReminderSetting(
                isOn: defaults.bool(forKey: Key.reminderOn(kind)),
                minutes: defaults.object(forKey: Key.reminderMinutes(kind)) as? Int ?? fallback.minutes,
                weekday: defaults.object(forKey: Key.reminderWeekday(kind)) as? Int ?? fallback.weekday
            )
        }
        return preferences
    }

    enum WeekStart: String, CaseIterable {
        case system, sunday, monday, saturday

        var title: String { self == .system ? "System Default" : rawValue.capitalized }

        var firstWeekday: Int? {
            switch self {
            case .system: nil
            case .sunday: 1
            case .monday: 2
            case .saturday: 7
            }
        }
    }

    static func calendar(weekStart raw: String? = nil) -> Calendar {
        var calendar = Calendar.current
        let setting = WeekStart(rawValue: raw ?? UserDefaults.standard.string(forKey: Key.weekStart) ?? "") ?? .system
        if let weekday = setting.firstWeekday { calendar.firstWeekday = weekday }
        return calendar
    }

    static func defaultMeal(at date: Date = Date()) -> Meal {
        let choice = MealChoice(rawValue: UserDefaults.standard.string(forKey: Key.defaultMeal) ?? "") ?? .automatic
        return choice.resolved(at: date)
    }

    static func hiddenMeals(_ raw: String? = nil) -> Set<Meal> {
        let text = raw ?? UserDefaults.standard.string(forKey: Key.hiddenMeals) ?? ""
        return Set(text.split(separator: ",").compactMap { Meal(rawValue: String($0)) })
    }

    static func encode(_ meals: Set<Meal>) -> String {
        meals.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func hiddenTabs(_ raw: String) -> Set<MainTab> {
        Set(raw.split(separator: ",").compactMap { MainTab(rawValue: String($0)) })
    }

    static func encode(_ tabs: Set<MainTab>) -> String {
        tabs.map(\.rawValue).sorted().joined(separator: ",")
    }

    static let tabBarLimit = 5

    /// The optional tabs that fit in the iPhone tab bar beside the first tab, and Settings when it sits there.
    static func barTabs(hidden raw: String, settingsInTabBar: Bool) -> [MainTab] {
        let room = tabBarLimit - 1 - (settingsInTabBar ? 1 : 0)
        return Array(MainTab.allCases.filter { !hiddenTabs(raw).contains($0) }.prefix(room))
    }

    static func showing(_ tab: MainTab, _ shown: Bool, hidden raw: String) -> String {
        var hidden = hiddenTabs(raw)
        if shown { hidden.remove(tab) } else { hidden.insert(tab) }
        return encode(hidden)
    }

    static var keepsScreenAwake: Bool {
        UserDefaults.standard.register(defaults: [Key.keepAwake: true])
        return UserDefaults.standard.bool(forKey: Key.keepAwake)
    }
}
