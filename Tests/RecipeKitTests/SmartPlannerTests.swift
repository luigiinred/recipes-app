import XCTest
@testable import RecipeKit

final class SmartPlannerTests: XCTestCase {
    private let days = ["2026-10-12", "2026-10-13", "2026-10-14"]
    private func recipe(_ title: String, queued: Bool = false, favorite: Bool = false) -> PlanCandidate {
        PlanCandidate(id: UUID(), title: title, isFavorite: favorite, isQueued: queued)
    }

    func testRotationUsesTheQueueFirstAndSkipsTakenSlots() {
        let plain = recipe("Plain"), queued = recipe("Queued", queued: true), loved = recipe("Loved", favorite: true)
        let request = PlanRequest(days: days, meals: [.dinner], recipes: [plain, loved, queued], taken: [PlanRequest.slotKey(days[1], .dinner)])
        let plan = SmartPlanner.rotation(request)
        XCTAssertEqual(plan.map(\.day), [days[0], days[2]])
        XCTAssertEqual(plan.map(\.recipeID), [queued.id, loved.id])
    }

    func testRotationNeverRepeatsARecipeWithinADay() {
        let request = PlanRequest(days: ["2026-10-12"], meals: [.lunch, .dinner], recipes: [recipe("Only")])
        XCTAssertEqual(SmartPlanner.rotation(request).count, 1)
    }

    func testModelPicksOutsideTheRequestAreDropped() {
        let one = recipe("One"), two = recipe("Two")
        let request = PlanRequest(days: days, meals: [.dinner], recipes: [one, two], taken: [PlanRequest.slotKey(days[2], .dinner)])
        let picks: [(recipe: Int, day: Int, meal: String)] = [
            (1, 1, "dinner"), (2, 2, "Dinner"), (3, 1, "dinner"), (1, 9, "dinner"), (1, 1, "lunch"), (2, 1, "dinner"), (1, 3, "dinner"),
        ]
        let plan = SmartPlanner.validated(picks, for: request)
        XCTAssertEqual(plan.map(\.day), [days[0], days[1]])
        XCTAssertEqual(plan.map(\.recipeID), [one.id, two.id])
    }
}
