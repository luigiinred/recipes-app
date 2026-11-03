import XCTest
@testable import RecipeKit

final class ProminentTitleTests: XCTestCase {
    func testTallestLinesWinInReadingOrder() {
        let title = RecipeScanner.prominentTitle(from: [
            (text: "Kirkland Signature", height: 0.04),
            (text: "MEAT", height: 0.12),
            (text: "LASAGNA", height: 0.14),
            (text: "Net wt 6 lb", height: 0.02),
        ])
        XCTAssertEqual(title, "Meat Lasagna")
    }

    func testNumbersAndSymbolsAreIgnored() {
        let title = RecipeScanner.prominentTitle(from: [
            (text: "6 LB", height: 0.3),
            (text: "Chicken Pot Pie", height: 0.1),
        ])
        XCTAssertEqual(title, "Chicken Pot Pie")
    }

    func testNoTextGivesNil() {
        XCTAssertNil(RecipeScanner.prominentTitle(from: []))
        XCTAssertNil(RecipeScanner.prominentTitle(from: [(text: "12", height: 0.2)]))
    }
}
