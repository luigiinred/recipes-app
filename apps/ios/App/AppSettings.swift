import Foundation
import RecipeKit

/// User preferences, stored in UserDefaults so views can bind to them with @AppStorage.
enum AppSettings {
    enum Key {
        static let defaultMeal = "defaultMeal"
        static let hiddenMeals = "hiddenMeals"
        static let weekStart = "weekStart"
        static let reviewImports = "reviewImports"
        static let keepAwake = "keepAwakeWhileCooking"
        static let listStyle = "recipeListStyle"
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
        static let fontStyle = "fontStyle"
        static let accentColor = "accentColorHex"

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

    static var keepsScreenAwake: Bool {
        UserDefaults.standard.register(defaults: [Key.keepAwake: true])
        return UserDefaults.standard.bool(forKey: Key.keepAwake)
    }
}
