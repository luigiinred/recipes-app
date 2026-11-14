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

/// When a feed post counts as viewed.
enum FeedMarkMode: String, CaseIterable {
    case onClose, onOpen, manual

    var title: String {
        switch self {
        case .onClose: "When I Go Back"
        case .onOpen: "When I Open It"
        case .manual: "Only When I Mark It"
        }
    }
}

/// A tab the user can place in the tab bar, in the order they choose.
enum TabItem: String, CaseIterable, Identifiable {
    case home, recipes, feeds, upNext, plan, groceries, settings

    var id: String { rawValue }

    init(_ tab: MainTab) { self = TabItem(rawValue: tab.rawValue)! }

    var feature: MainTab? { MainTab(rawValue: rawValue) }

    /// Home and Recipes both open the library; at least one of them always stays.
    var isLibrary: Bool { self == .home || self == .recipes }

    var title: String {
        switch self {
        case .home: "Home"
        case .recipes: "Recipes"
        case .settings: "Settings"
        default: feature?.title ?? rawValue
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .recipes: "book.closed"
        case .settings: "gearshape"
        default: feature?.symbol ?? "square"
        }
    }
}

/// What the first tab opened on before tabs could be arranged; read once to carry the choice over.
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
        static let darkColorTheme = "colorThemeDark"
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
        static let feedShowViewed = "feedShowViewed"
        static let feedMarkViewed = "feedMarkViewed"
        static let feedReader = "feedOpensInReader"
        static let feedDiscoverDismissed = "feedDiscoverCardDismissed"
        static let readerTextSize = "readerTextSize"
        static let readerFont = "readerFont"
        static let readerTheme = "readerTheme"
        static let settingsInTabBar = "settingsInTabBar"
        static let firstTab = "firstTab"
        static let tabOrder = "tabOrder"
        static let suggestCleanups = "suggestCleanups"
        static let scanForCleanups = "scanLibraryForCleanups"

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

    /// The tabs in the tab bar, in order. An empty value carries over the older first-tab, hidden-tab and Settings choices.
    static func tabs(_ raw: String, defaults: UserDefaults = .standard) -> [TabItem] {
        var seen = Set<TabItem>()
        let decoded = raw.split(separator: ",").compactMap { TabItem(rawValue: String($0)) }.filter { seen.insert($0).inserted }
        if decoded.contains(where: \.isLibrary) { return decoded }
        let first = FirstTab(rawValue: defaults.string(forKey: Key.firstTab) ?? "") == .recipes ? TabItem.recipes : .home
        let hidden = Set((defaults.string(forKey: Key.hiddenTabs) ?? "").split(separator: ",").compactMap { MainTab(rawValue: String($0)) })
        let features = MainTab.allCases.filter { !hidden.contains($0) }.map(TabItem.init)
        let settings: [TabItem] = defaults.bool(forKey: Key.settingsInTabBar) ? [.settings] : []
        return [first] + features + settings
    }

    static func encode(_ tabs: [TabItem]) -> String {
        tabs.map(\.rawValue).joined(separator: ",")
    }

    static func hiddenTabs(_ raw: String) -> Set<MainTab> {
        Set(MainTab.allCases).subtracting(tabs(raw).compactMap(\.feature))
    }

    static let tabBarLimit = 5

    /// The tabs that fit in the iPhone tab bar.
    static func barTabs(_ raw: String) -> [TabItem] {
        Array(tabs(raw).prefix(tabBarLimit))
    }

    /// Adds a tab at the end of the bar, or takes it out.
    static func showing(_ tab: MainTab, _ shown: Bool, hidden raw: String) -> String {
        var list = tabs(raw)
        let item = TabItem(tab)
        if shown { if !list.contains(item) { list.append(item) } } else { list.removeAll { $0 == item } }
        return encode(list)
    }

    static var keepsScreenAwake: Bool {
        UserDefaults.standard.register(defaults: [Key.keepAwake: true])
        return UserDefaults.standard.bool(forKey: Key.keepAwake)
    }
}
