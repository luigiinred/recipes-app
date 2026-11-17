import Foundation
import RecipeKit
import Testing
@testable import Recipes

@Suite("Meal Plan calendar")
@MainActor
struct MealCalendarSyncTests {
    @Test("each meal lands at its usual hour for an hour on its day")
    func mealTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Denver")!
        let breakfast = try #require(MealCalendarSync.times(for: MealPlanEntry(title: "Oats", day: "2026-11-16", meal: .breakfast), calendar: calendar))
        let dinner = try #require(MealCalendarSync.times(for: MealPlanEntry(title: "Chili", day: "2026-11-16", meal: .dinner), calendar: calendar))
        #expect(calendar.component(.hour, from: breakfast.start) == 8)
        #expect(calendar.component(.hour, from: dinner.start) == 18)
        #expect(dinner.end.timeIntervalSince(dinner.start) == 3600)
        #expect(calendar.component(.day, from: dinner.start) == 16)
    }

    @Test("a meal on a day that can't be read gets no event")
    func badDay() {
        #expect(MealCalendarSync.times(for: MealPlanEntry(title: "Oats", day: "someday", meal: .lunch)) == nil)
    }
}
