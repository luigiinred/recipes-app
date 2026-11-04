import XCTest
@testable import RecipeKit

final class MealieBrowserTests: XCTestCase {
    private let id = UUID()

    private func summary(image: Any = "aBc1") -> MealieObject {
        [
            "id": id.uuidString.lowercased(), "slug": "tomato-soup", "name": "Tomato Soup", "description": "Bright and quick.",
            "image": image, "totalTime": "30 minutes", "performTime": "20 minutes",
            "tags": [["name": "Vegetarian"]], "recipeCategory": [["name": "Soup"]],
            "extras": ["recipesApp": #"{"id":"\#(UUID().uuidString)","stepTimestamps":[],"wantToCook":true}"#],
        ]
    }

    func testBrowsedRecipeKeepsMealiesIDAndLeavesOutTheOwnersQueue() throws {
        let entry = try XCTUnwrap(MealieBrowser.entry(from: summary()))
        XCTAssertEqual(entry.recipe.id, id)
        XCTAssertEqual(entry.slug, "tomato-soup")
        XCTAssertEqual(entry.recipe.title, "Tomato Soup")
        XCTAssertEqual(entry.recipe.cookMinutes, 20)
        XCTAssertEqual(Set(entry.recipe.tags), ["Vegetarian", "Soup"])
        XCTAssertFalse(entry.recipe.wantToCook)
        XCTAssertNil(entry.recipe.rating)
        XCTAssertTrue(entry.hasImage)
    }

    func testNoImageTokenMeansNoPhoto() throws {
        XCTAssertFalse(try XCTUnwrap(MealieBrowser.entry(from: summary(image: NSNull()))).hasImage)
        XCTAssertFalse(try XCTUnwrap(MealieBrowser.entry(from: summary(image: ""))).hasImage)
    }

    func testSkipsRecipesWithoutAnIDOrSlug() {
        var missing = summary()
        missing["slug"] = nil
        XCTAssertNil(MealieBrowser.entry(from: missing))
        XCTAssertNil(MealieBrowser.entry(from: ["id": "not-a-uuid", "slug": "x", "name": "X"]))
    }

    func testCopyIsANewRecipeOfYourOwn() throws {
        var recipe = try XCTUnwrap(MealieBrowser.entry(from: summary())).recipe
        recipe.timeline = [TimelineEvent(date: Date(), note: "Made it")]
        recipe.isFavorite = true
        recipe.ingredients = ["2 cups tomatoes"]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let copy = MealieBrowser.copy(of: recipe, now: now)
        XCTAssertNotEqual(copy.id, recipe.id)
        XCTAssertEqual(copy.title, recipe.title)
        XCTAssertEqual(copy.ingredients, recipe.ingredients)
        XCTAssertEqual(copy.createdAt, now)
        XCTAssertTrue(copy.timeline.isEmpty)
        XCTAssertFalse(copy.isFavorite)
    }
}
