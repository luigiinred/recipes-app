import XCTest
@testable import RecipeKit

final class ReminderTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Wednesday, 21 Oct 2026, 15:00 UTC.
    private var now: Date { date(2026, 10, 21, 15) }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func requests(
        _ preferences: ReminderPreferences, at time: Date? = nil, plan: [MealPlanEntry] = [], recipes: [Recipe] = []
    ) -> [ReminderRequest] {
        ReminderPlanner.requests(preferences, now: time ?? now, calendar: calendar, plan: plan, recipes: recipes)
    }

    private func on(_ kind: ReminderKind) -> ReminderPreferences {
        var preferences = ReminderPreferences()
        preferences[kind].isOn = true
        return preferences
    }

    func testEverythingIsOffByDefault() {
        XCTAssertFalse(ReminderPreferences().anyOn)
        XCTAssertTrue(requests(ReminderPreferences()).isEmpty)
    }

    func testTurningOneOnLeavesTheOthersOff() {
        let result = requests(on(.planWeek))
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(Set(result.map(\.kind)), [.planWeek])
    }

    func testDinnerLogFiresEveryEveningAtTheChosenTime() {
        let result = requests(on(.logDinner))
        XCTAssertEqual(result.count, ReminderPlanner.daysAhead)
        XCTAssertEqual(result.first?.fireDate, date(2026, 10, 21, 20))
        XCTAssertEqual(result.last?.fireDate, date(2026, 10, 27, 20))
    }

    func testDinnerLogSkipsTonightOnceTheTimeHasPassed() {
        let result = requests(on(.logDinner), at: date(2026, 10, 21, 21))
        XCTAssertEqual(result.first?.fireDate, date(2026, 10, 22, 20))
        XCTAssertEqual(result.count, ReminderPlanner.daysAhead - 1)
    }

    func testDinnerLogSkipsTodayWhenSomethingWasAlreadyLogged() {
        var soup = Recipe(title: "Soup")
        soup.timeline = [TimelineEvent(date: date(2026, 10, 21, 12))]
        let result = requests(on(.logDinner), recipes: [soup])
        XCTAssertEqual(result.first?.fireDate, date(2026, 10, 22, 20))
    }

    func testDinnerLogNamesTheDinnerPlannedForThatDay() {
        let plan = [MealPlanEntry(title: "Sunday Sauce", day: "2026-10-21", meal: .dinner),
                    MealPlanEntry(title: "Toast", day: "2026-10-22", meal: .breakfast)]
        let result = requests(on(.logDinner), plan: plan)
        XCTAssertTrue(result[0].body.contains("Sunday Sauce"))
        XCTAssertFalse(result[1].body.contains("Toast"))
    }

    func testPlanWeekRepeatsOnTheChosenWeekday() {
        let result = requests(on(.planWeek))
        XCTAssertEqual(result.count, ReminderPlanner.weeksAhead)
        XCTAssertEqual(result.map { calendar.component(.weekday, from: $0.fireDate) }, [1, 1, 1, 1])
        XCTAssertEqual(result.first?.fireDate, date(2026, 10, 25, 17))
    }

    func testPlanWeekIsSkippedForAWeekThatAlreadyHasAPlan() {
        let plan = ["2026-10-26", "2026-10-28", "2026-10-30"].map { MealPlanEntry(title: "Dinner", day: $0) }
        let result = requests(on(.planWeek), plan: plan)
        XCTAssertEqual(result.first?.fireDate, date(2026, 11, 1, 17))
    }

    func testPlanWeekStillNudgesForAThinPlan() {
        let result = requests(on(.planWeek), plan: [MealPlanEntry(title: "Dinner", day: "2026-10-26")])
        XCTAssertEqual(result.first?.fireDate, date(2026, 10, 25, 17))
        XCTAssertTrue(result.first?.body.contains("1 meal planned") == true)
    }

    func testAddRecipeFollowsItsOwnWeekday() {
        let result = requests(on(.addRecipe))
        XCTAssertEqual(result.map { calendar.component(.weekday, from: $0.fireDate) }, [7, 7, 7, 7])
    }

    func testIdentifiersAreUniqueAndShareThePrefix() {
        var preferences = ReminderPreferences()
        ReminderKind.allCases.forEach { preferences[$0].isOn = true }
        let result = requests(preferences)
        XCTAssertEqual(Set(result.map(\.id)).count, result.count)
        XCTAssertTrue(result.allSatisfy { $0.id.hasPrefix(ReminderPlanner.idPrefix) })
    }

    func testTurningEverythingOffSchedulesNothing() {
        var preferences = ReminderPreferences()
        ReminderKind.allCases.forEach { preferences[$0].isOn = true }
        ReminderKind.allCases.forEach { preferences[$0].isOn = false }
        XCTAssertFalse(preferences.anyOn)
        XCTAssertTrue(requests(preferences).isEmpty)
    }
}
