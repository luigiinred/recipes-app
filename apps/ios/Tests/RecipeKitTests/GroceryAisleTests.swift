import XCTest
@testable import RecipeKit

final class GroceryAisleTests: XCTestCase {
    func testGuessesCommonGroceries() {
        let cases: [(String, GroceryAisle)] = [
            ("Limes", .produce),
            ("tomatoes", .produce),
            ("bell pepper", .produce),
            ("green beans", .produce),
            ("black pepper", .spices),
            ("chicken thighs", .meat),
            ("chicken stock", .pantry),
            ("sour cream", .dairy),
            ("eggs", .dairy),
            ("eggplant", .produce),
            ("sourdough bread", .bakery),
            ("frozen peas", .frozen),
            ("paper towels", .household),
            ("za'atar blend", .other),
        ]
        for (name, aisle) in cases {
            XCTAssertEqual(GroceryAisle.guess(name), aisle, name)
        }
    }

    func testKeySharesAnswersAcrossPlurals() {
        XCTAssertEqual(GroceryAisle.key(for: "Limes"), GroceryAisle.key(for: "lime"))
        XCTAssertEqual(GroceryAisle.key(for: "Tomatoes"), "tomato")
        XCTAssertEqual(GroceryAisle.key(for: "Berries"), "berry")
    }
}
