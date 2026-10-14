import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public struct PlanCandidate: Sendable, Hashable {
    public var id: UUID
    public var title: String
    public var tags: [String]
    public var minutes: Int?
    public var isFavorite: Bool
    public var isQueued: Bool

    public init(id: UUID, title: String, tags: [String] = [], minutes: Int? = nil, isFavorite: Bool = false, isQueued: Bool = false) {
        self.id = id
        self.title = title
        self.tags = tags
        self.minutes = minutes
        self.isFavorite = isFavorite
        self.isQueued = isQueued
    }
}

public struct PlanRequest: Sendable {
    public var days: [String]
    public var meals: [Meal]
    /// Queued recipes first, in queue order.
    public var recipes: [PlanCandidate]
    /// Slots already filled, as "day|meal".
    public var taken: Set<String>

    public init(days: [String], meals: [Meal], recipes: [PlanCandidate], taken: Set<String> = []) {
        self.days = days
        self.meals = meals
        self.recipes = recipes
        self.taken = taken
    }

    public static func slotKey(_ day: String, _ meal: Meal) -> String { "\(day)|\(meal.rawValue)" }

    var freeSlots: [(day: Int, meal: Meal)] {
        days.indices.flatMap { day in
            meals.sorted { $0.order < $1.order }.compactMap { meal in
                taken.contains(Self.slotKey(days[day], meal)) ? nil : (day, meal)
            }
        }
    }
}

public struct PlanSuggestion: Identifiable, Hashable, Sendable {
    public var recipeID: UUID
    public var day: String
    public var meal: Meal
    public var id: String { Self.slotKey(day, meal) }

    static func slotKey(_ day: String, _ meal: Meal) -> String { PlanRequest.slotKey(day, meal) }

    public init(recipeID: UUID, day: String, meal: Meal) {
        self.recipeID = recipeID
        self.day = day
        self.meal = meal
    }
}

public enum SmartPlanner {
    public static var isAvailable: Bool { AppleIntelligence.status.isAvailable }

    /// Asks the on-device model for a plan and falls back to a simple rotation when it isn't available or gives nothing usable.
    public static func suggest(_ request: PlanRequest) async -> (suggestions: [PlanSuggestion], usedAppleIntelligence: Bool) {
        if let generated = await generate(request), !generated.isEmpty { return (generated, true) }
        return (rotation(request), false)
    }

    /// Queued recipes first, then favorites, then the rest; no recipe twice in a day or again until the others have had a turn.
    public static func rotation(_ request: PlanRequest) -> [PlanSuggestion] {
        let pool = request.recipes.enumerated().sorted { left, right in
            func rank(_ item: PlanCandidate) -> Int { item.isQueued ? 0 : item.isFavorite ? 1 : 2 }
            return (rank(left.element), left.offset) < (rank(right.element), right.offset)
        }.map(\.element)
        guard !pool.isEmpty else { return [] }
        var result: [PlanSuggestion] = []
        var next = 0
        var usedToday: [String: Set<UUID>] = [:]
        for slot in request.freeSlots {
            let day = request.days[slot.day]
            var pick: PlanCandidate?
            for offset in 0..<pool.count {
                let candidate = pool[(next + offset) % pool.count]
                if !(usedToday[day] ?? []).contains(candidate.id) {
                    pick = candidate
                    next = (next + offset + 1) % pool.count
                    break
                }
            }
            guard let pick else { continue }
            usedToday[day, default: []].insert(pick.id)
            result.append(PlanSuggestion(recipeID: pick.id, day: day, meal: slot.meal))
        }
        return result
    }

    /// Turns the model's numbered picks into suggestions, dropping anything out of range, off the menu, or already placed.
    public static func validated(_ picks: [(recipe: Int, day: Int, meal: String)], for request: PlanRequest) -> [PlanSuggestion] {
        let free = Set(request.freeSlots.map { PlanRequest.slotKey(request.days[$0.day], $0.meal) })
        var filled: Set<String> = []
        var result: [PlanSuggestion] = []
        for pick in picks {
            guard request.recipes.indices.contains(pick.recipe - 1),
                  request.days.indices.contains(pick.day - 1),
                  let meal = Meal(rawValue: pick.meal.lowercased()) else { continue }
            let day = request.days[pick.day - 1]
            let key = PlanRequest.slotKey(day, meal)
            guard free.contains(key), filled.insert(key).inserted else { continue }
            result.append(PlanSuggestion(recipeID: request.recipes[pick.recipe - 1].id, day: day, meal: meal))
        }
        return result.sorted { ($0.day, $0.meal.order) < ($1.day, $1.meal.order) }
    }

    static func prompt(for request: PlanRequest) -> String {
        let recipes = request.recipes.prefix(60).enumerated().map { index, recipe in
            var line = "\(index + 1). \(recipe.title)"
            if !recipe.tags.isEmpty { line += " [\(recipe.tags.prefix(2).joined(separator: ", "))]" }
            if let minutes = recipe.minutes { line += " \(minutes) min" }
            if recipe.isQueued { line += " (queued)" }
            if recipe.isFavorite { line += " (favorite)" }
            return line
        }
        let days = request.days.enumerated().map { index, key in
            let name = DayKey.date(from: key).map { $0.formatted(.dateTime.weekday(.wide)) } ?? key
            return "\(index + 1). \(name) (\(key))"
        }
        let slots = request.freeSlots.map { "day \($0.day + 1) \($0.meal.rawValue)" }
        return """
            Recipes:
            \(recipes.joined(separator: "\n"))

            Days:
            \(days.joined(separator: "\n"))

            Fill exactly these open slots, one recipe each: \(slots.joined(separator: "; ")).
            """
    }

    private static func generate(_ request: PlanRequest) async -> [PlanSuggestion]? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *), isAvailable, !request.recipes.isEmpty, !request.freeSlots.isEmpty {
            let limited = PlanRequest(days: request.days, meals: request.meals, recipes: Array(request.recipes.prefix(60)), taken: request.taken)
            let session = LanguageModelSession(instructions: """
                You plan a week of home cooking from the user's own recipes. Refer to recipes and days only by the numbers given. \
                Prefer queued recipes and favorites, vary cuisines and ingredients across the week, put quick recipes on busy-sounding weekdays \
                and longer ones on weekends, and never repeat a recipe on the same day. Breakfast recipes belong at breakfast.
                """)
            do {
                let response = try await session.respond(to: prompt(for: limited), generating: GeneratedWeekPlan.self)
                return validated(response.content.meals.map { ($0.recipeNumber, $0.dayNumber, $0.meal) }, for: limited)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedWeekPlan {
    @Guide(description: "One entry per open slot.")
    var meals: [GeneratedMeal]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedMeal {
    @Guide(description: "The number of the recipe from the Recipes list.")
    var recipeNumber: Int
    @Guide(description: "The number of the day from the Days list.")
    var dayNumber: Int
    @Guide(.anyOf(["breakfast", "lunch", "dinner", "snack"]))
    var meal: String
}
#endif
