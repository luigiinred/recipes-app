import Foundation

public enum ReminderKind: String, CaseIterable, Codable, Sendable {
    case logDinner, planWeek, addRecipe
}

/// One reminder's schedule. `weekday` follows `Calendar` (1 is Sunday) and is ignored by daily reminders.
public struct ReminderSetting: Equatable, Sendable {
    public var isOn: Bool
    public var minutes: Int
    public var weekday: Int

    public init(isOn: Bool = false, minutes: Int, weekday: Int = 1) {
        self.isOn = isOn
        self.minutes = minutes
        self.weekday = weekday
    }
}

public struct ReminderPreferences: Equatable, Sendable {
    public var logDinner: ReminderSetting
    public var planWeek: ReminderSetting
    public var addRecipe: ReminderSetting

    public init(
        logDinner: ReminderSetting = ReminderPreferences.defaultSetting(for: .logDinner),
        planWeek: ReminderSetting = ReminderPreferences.defaultSetting(for: .planWeek),
        addRecipe: ReminderSetting = ReminderPreferences.defaultSetting(for: .addRecipe)
    ) {
        self.logDinner = logDinner
        self.planWeek = planWeek
        self.addRecipe = addRecipe
    }

    public static func defaultSetting(for kind: ReminderKind) -> ReminderSetting {
        switch kind {
        case .logDinner: ReminderSetting(minutes: 20 * 60)
        case .planWeek: ReminderSetting(minutes: 17 * 60, weekday: 1)
        case .addRecipe: ReminderSetting(minutes: 10 * 60, weekday: 7)
        }
    }

    public subscript(kind: ReminderKind) -> ReminderSetting {
        get {
            switch kind {
            case .logDinner: logDinner
            case .planWeek: planWeek
            case .addRecipe: addRecipe
            }
        }
        set {
            switch kind {
            case .logDinner: logDinner = newValue
            case .planWeek: planWeek = newValue
            case .addRecipe: addRecipe = newValue
            }
        }
    }

    public var anyOn: Bool { ReminderKind.allCases.contains { self[$0].isOn } }
}

public struct ReminderRequest: Equatable, Sendable {
    public let id: String
    public let kind: ReminderKind
    public let fireDate: Date
    public let title: String
    public let body: String
}

/// Works out which notifications to schedule. Everything is dated, so nothing keeps firing if the app is never reopened.
public enum ReminderPlanner {
    public static let idPrefix = "reminder."
    public static let daysAhead = 7
    public static let weeksAhead = 4
    public static let mealsThatMakeAPlan = 3

    private static let addRecipeNudges = [
        "Seen something good lately? Save it from a link, a photo, or a video.",
        "Got a recipe you keep meaning to save? Add it while you remember.",
        "Add one recipe this week and next week's plan gets easier.",
        "Tried something new? Write it down before it's gone.",
    ]

    public static func requests(
        _ preferences: ReminderPreferences,
        now: Date,
        calendar: Calendar = .current,
        plan: [MealPlanEntry],
        recipes: [Recipe]
    ) -> [ReminderRequest] {
        var requests: [ReminderRequest] = []
        if preferences.logDinner.isOn { requests += dinnerLogs(preferences.logDinner, now, calendar, plan, recipes) }
        if preferences.planWeek.isOn { requests += weekPlans(preferences.planWeek, now, calendar, plan) }
        if preferences.addRecipe.isOn { requests += recipeNudges(preferences.addRecipe, now, calendar) }
        return requests
    }

    private static func dinnerLogs(
        _ setting: ReminderSetting, _ now: Date, _ calendar: Calendar, _ plan: [MealPlanEntry], _ recipes: [Recipe]
    ) -> [ReminderRequest] {
        let today = calendar.startOfDay(for: now)
        let cookedToday = recipes.contains { $0.timeline.contains { calendar.isDate($0.date, inSameDayAs: now) } }
        return (0..<daysAhead).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(byAdding: .minute, value: setting.minutes, to: day),
                  fire > now, !(offset == 0 && cookedToday) else { return nil }
            let planned = plan.first { $0.day == DayKey.string(from: day, calendar: calendar) && $0.meal == .dinner }
            let body = planned.map { "Did you make \($0.title) tonight? Log it so you remember how it went." }
                ?? "What did you have for dinner? Log it in a couple of taps."
            return request(.logDinner, fire, calendar, title: "How was dinner?", body: body)
        }
    }

    private static func weekPlans(
        _ setting: ReminderSetting, _ now: Date, _ calendar: Calendar, _ plan: [MealPlanEntry]
    ) -> [ReminderRequest] {
        occurrences(of: setting, after: now, calendar).compactMap { fire in
            let start = calendar.startOfDay(for: fire)
            let days = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }.map { DayKey.string(from: $0, calendar: calendar) }
            let planned = plan.filter { days.contains($0.day) }.count
            guard planned < mealsThatMakeAPlan else { return nil }
            let body = planned == 0
                ? "Take two minutes to plan next week's meals."
                : "You have \(planned) \(planned == 1 ? "meal" : "meals") planned for next week. Fill in the rest?"
            return request(.planWeek, fire, calendar, title: "Plan next week", body: body)
        }
    }

    private static func recipeNudges(_ setting: ReminderSetting, _ now: Date, _ calendar: Calendar) -> [ReminderRequest] {
        occurrences(of: setting, after: now, calendar).map { fire in
            let week = calendar.component(.weekOfYear, from: fire)
            return request(.addRecipe, fire, calendar, title: "Add a recipe", body: addRecipeNudges[week % addRecipeNudges.count])
        }
    }

    private static func occurrences(of setting: ReminderSetting, after now: Date, _ calendar: Calendar) -> [Date] {
        let match = DateComponents(hour: setting.minutes / 60, minute: setting.minutes % 60, weekday: setting.weekday)
        var found: [Date] = []
        var cursor = now
        while found.count < weeksAhead, let next = calendar.nextDate(after: cursor, matching: match, matchingPolicy: .nextTime) {
            found.append(next)
            cursor = next
        }
        return found
    }

    private static func request(_ kind: ReminderKind, _ fire: Date, _ calendar: Calendar, title: String, body: String) -> ReminderRequest {
        ReminderRequest(
            id: "\(idPrefix)\(kind.rawValue).\(DayKey.string(from: fire, calendar: calendar))",
            kind: kind, fireDate: fire, title: title, body: body
        )
    }
}
