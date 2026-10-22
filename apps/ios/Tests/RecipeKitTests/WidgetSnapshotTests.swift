import XCTest
@testable import RecipeKit

final class WidgetSnapshotTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ key: String, hour: Int = 9) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: DayKey.date(from: key, calendar: calendar)!)!
    }

    private func make(
        recipes: [Recipe] = [], mealPlan: [MealPlanEntry] = [], groceries: [GroceryItem] = [], imageIDs: Set<UUID> = []
    ) -> WidgetSnapshot {
        WidgetSnapshot.make(
            recipes: recipes, mealPlan: mealPlan, groceries: groceries, imageIDs: imageIDs,
            today: date("2026-03-24"), calendar: calendar
        )
    }

    func testMealsStartTodayAndAreOrdered() {
        let plan = [
            MealPlanEntry(title: "Old", day: "2026-03-23"),
            MealPlanEntry(title: "Dinner", day: "2026-03-24", meal: .dinner),
            MealPlanEntry(title: "Breakfast", day: "2026-03-24", meal: .breakfast),
            MealPlanEntry(title: "Far", day: "2026-04-30"),
            MealPlanEntry(title: "Tomorrow", day: "2026-03-25"),
        ]
        let snapshot = make(mealPlan: plan)
        XCTAssertEqual(snapshot.meals.map(\.title), ["Breakfast", "Dinner", "Tomorrow"])
        XCTAssertEqual(snapshot.meals(on: date("2026-03-24"), calendar: calendar).map(\.title), ["Breakfast", "Dinner"])
    }

    func testUpNextFollowsTheQueueOrder() {
        let early = Date(timeIntervalSince1970: 1_000), late = Date(timeIntervalSince1970: 2_000)
        let recipes = [
            Recipe(title: "Second", wantToCook: true, queuedAt: late),
            Recipe(title: "Skipped"),
            Recipe(title: "First", wantToCook: true, queuedAt: early),
        ]
        XCTAssertEqual(make(recipes: recipes).upNext.map(\.title), ["First", "Second"])
    }

    func testGroceriesListOnlyWhatIsLeftToBuy() {
        let groceries = [
            GroceryItem(name: "Milk", quantity: "1 L", createdAt: Date(timeIntervalSince1970: 2)),
            GroceryItem(name: "Eggs", isChecked: true),
            GroceryItem(name: "Flour", createdAt: Date(timeIntervalSince1970: 1)),
        ]
        let snapshot = make(groceries: groceries)
        XCTAssertEqual(snapshot.toBuy.map(\.name), ["Flour", "Milk"])
        XCTAssertEqual(snapshot.checkedCount, 1)
    }

    func testPoolSkipsIdeasAndPrefersPhotos() {
        let plain = Recipe(title: "Plain", ingredients: ["1 egg"])
        let photo = Recipe(title: "Photo", steps: ["Cook."])
        let idea = Recipe(title: "Idea")
        let snapshot = make(recipes: [plain, idea, photo], imageIDs: [photo.id])
        XCTAssertEqual(snapshot.pool.map(\.title), ["Photo", "Plain"])
        XCTAssertEqual(snapshot.pool.map(\.hasImage), [true, false])
    }

    func testRandomDishHoldsStillWithinAWindowAndMovesBetweenThem() {
        let recipes = (0..<12).map { Recipe(title: "R\($0)", ingredients: ["x"]) }
        let snapshot = make(recipes: recipes)
        let morning = snapshot.randomDish(at: date("2026-03-24", hour: 7), calendar: calendar)
        XCTAssertEqual(morning, snapshot.randomDish(at: date("2026-03-24", hour: 11), calendar: calendar))
        let picks = Set((0..<8).compactMap { snapshot.randomDish(at: date("2026-03-24", hour: 6 * $0 % 24).addingTimeInterval(Double($0) * 86_400), calendar: calendar)?.id })
        XCTAssertGreaterThan(picks.count, 1)
        XCTAssertNil(WidgetSnapshot.empty.randomDish(at: Date()))
    }

    func testStoreRoundTripsSnapshotAndPrunesImages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetStore(directory: directory)
        XCTAssertEqual(store.load(), .empty)
        let keep = UUID(), drop = UUID()
        let snapshot = WidgetSnapshot(upNext: [.init(id: keep, title: "Soup", minutes: 30, hasImage: true)], toBuy: [.init(id: UUID(), name: "Milk")])
        try store.save(snapshot)
        try store.saveImage(Data([1]), for: keep)
        try store.saveImage(Data([2]), for: drop)
        XCTAssertEqual(store.load(), snapshot)
        store.pruneImages(keeping: [keep])
        XCTAssertTrue(store.hasImage(for: keep))
        XCTAssertFalse(store.hasImage(for: drop))
    }
}
