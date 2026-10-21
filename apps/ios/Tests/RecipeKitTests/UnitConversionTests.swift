import XCTest
@testable import RecipeKit

final class UnitConversionTests: XCTestCase {
    private func conversions(_ line: String) -> [String] { Ingredient(parsing: line).conversions }

    func testCupsToSmallerAndMetricUnits() {
        XCTAssertEqual(conversions("1 cup flour"), ["16 tbsp", "8 fl oz", "237 ml"])
        XCTAssertEqual(conversions("1 1/2 cups milk"), ["24 tbsp", "12 fl oz", "355 ml"])
    }

    func testSpoonsToMetric() {
        XCTAssertEqual(conversions("1 tbsp olive oil"), ["3 tsp", "1/2 fl oz", "15 ml"])
        XCTAssertEqual(conversions("1 tsp salt"), ["1/3 tbsp", "5 ml"])
    }

    func testMetricVolumeToUS() {
        XCTAssertEqual(conversions("250 ml water"), ["17 tbsp", "8 1/2 fl oz", "1 cup"])
    }

    func testLargeVolumesSwitchToLiters() {
        XCTAssertEqual(conversions("5 cups stock"), ["1 1/4 quarts", "1.18 l"])
    }

    func testWeights() {
        XCTAssertEqual(conversions("8 oz cream cheese"), ["1/2 lb", "227 g"])
        XCTAssertEqual(conversions("500 g flour"), ["17 1/2 oz", "1 1/8 lb"])
        XCTAssertEqual(conversions("2 lb potatoes"), ["32 oz", "907 g"])
    }

    func testNothingToConvert() {
        XCTAssertEqual(conversions("2 cloves garlic"), [])
        XCTAssertEqual(conversions("3 eggs"), [])
        XCTAssertEqual(conversions("salt to taste"), [])
        XCTAssertEqual(conversions("2-3 cups broth"), [])
    }
}

final class TimelineTests: XCTestCase {
    func testOldRecipesDecodeWithoutATimeline() throws {
        let json = #"{"title": "Soup"}"#.data(using: .utf8)!
        let recipe = try RecipeCoding.makeDecoder().decode(Recipe.self, from: json)
        XCTAssertEqual(recipe.timeline, [])
        XCTAssertNil(recipe.lastMade)
    }

    func testTimelineSurvivesEncoding() throws {
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Date(timeIntervalSince1970: 1_800_000_000)
        var recipe = Recipe(title: "Soup")
        recipe.timeline = [TimelineEvent(date: later, note: "Needed more salt"), TimelineEvent(date: earlier)]
        let decoded = try RecipeCoding.makeDecoder().decode(Recipe.self, from: RecipeCoding.makeEncoder().encode(recipe))
        XCTAssertEqual(decoded.timeline, recipe.timeline)
        XCTAssertEqual(decoded.lastMade, later)
    }
}
