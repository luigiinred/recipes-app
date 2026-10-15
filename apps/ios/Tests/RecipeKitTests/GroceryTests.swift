import XCTest
@testable import RecipeKit

final class GroceryTests: XCTestCase {
    func testIngredientSplit() {
        let cases: [(String, String, String)] = [
            ("500g black beans dried", "500g", "black beans dried"),
            ("2 cloves garlic", "2 cloves", "garlic"),
            ("1 1/2 cups flour", "1 1/2 cups", "flour"),
            ("4 bell peppers", "4", "bell peppers"),
            ("2 tbsp of olive oil", "2 tbsp", "olive oil"),
            ("½ cup milk", "½ cup", "milk"),
            ("salt", "", "salt"),
            ("2 cups", "", "2 cups"),
        ]
        for (input, quantity, name) in cases {
            let parts = IngredientParser.split(input)
            XCTAssertEqual(parts.quantity, quantity, input)
            XCTAssertEqual(parts.name, name, input)
        }
    }

    func testDayKeyRoundTrip() {
        let date = DayKey.date(from: "2026-03-24")!
        XCTAssertEqual(DayKey.string(from: date), "2026-03-24")
        XCTAssertNil(DayKey.date(from: "2026-02-31"))
        XCTAssertNil(DayKey.date(from: "tomorrow"))
    }

    func testLibraryStoresRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = Library(root: root)
        let stamp = Date(timeIntervalSince1970: 1_800_000_000)
        var item = GroceryItem(parsing: "3 tbsp canola oil")
        item.createdAt = stamp
        item.updatedAt = stamp
        try library.groceries.save(item)
        let entry = MealPlanEntry(title: "Chili", day: "2026-03-26", meal: .dinner, createdAt: stamp, updatedAt: stamp)
        try library.mealPlan.save(entry)
        XCTAssertEqual(try library.groceries.list(), [item])
        XCTAssertEqual(try library.mealPlan.list(), [entry])
        try library.groceries.delete(item)
        try library.groceries.delete(item)
        XCTAssertTrue(try library.groceries.list().isEmpty)
    }
}
