import Foundation

public enum Meal: String, Codable, CaseIterable, Sendable {
    case breakfast, lunch, dinner, snack

    public var title: String { rawValue.capitalized }

    public var symbol: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon"
        case .snack: "cup.and.saucer"
        }
    }

    public var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

public struct MealPlanEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var recipeID: UUID?
    public var title: String
    public var day: String
    public var meal: Meal
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        recipeID: UUID? = nil,
        title: String,
        day: String,
        meal: Meal = .dinner,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recipeID = recipeID
        self.title = title
        self.day = day
        self.meal = meal
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum DayKey {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, key.count == 10 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.day], from: date).day == parts[2] else { return nil }
        return date
    }
}

/// What to file a newly planned recipe under: a fixed meal, or whichever fits the time of day.
public enum MealChoice: String, CaseIterable, Sendable {
    case automatic, breakfast, lunch, dinner, snack

    public var title: String { rawValue.capitalized }

    public func resolved(at date: Date = Date(), calendar: Calendar = .current) -> Meal {
        switch self {
        case .automatic: Meal.fitting(hour: calendar.component(.hour, from: date))
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .dinner: .dinner
        case .snack: .snack
        }
    }
}

extension Meal {
    /// Breakfast until late morning, lunch through early afternoon, a snack mid-afternoon, dinner in the evening.
    public static func fitting(hour: Int) -> Meal {
        switch hour {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 15..<17: .snack
        case 17..<22: .dinner
        default: .snack
        }
    }
}
