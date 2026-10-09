import XCTest
@testable import RecipeKit

final class RecipeStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveListDelete() throws {
        let store = RecipeStore(directory: directory)
        let saved = try store.save(Recipe(title: "  Pancakes ", ingredients: ["flour"]))
        XCTAssertEqual(saved.title, "Pancakes")
        XCTAssertEqual(try store.list().map(\.title), ["Pancakes"])
        try store.delete(saved)
        XCTAssertTrue(try store.list().isEmpty)
    }

    func testRejectsEmptyTitle() {
        XCTAssertThrowsError(try RecipeStore(directory: directory).save(Recipe(title: "  ")))
    }

    func testFindByIdPrefixTitleAndSubstring() throws {
        let store = RecipeStore(directory: directory)
        let soup = try store.save(Recipe(title: "Tomato Soup"))
        _ = try store.save(Recipe(title: "Tomato Tart"))
        XCTAssertEqual(try store.find("tomato soup").id, soup.id)
        XCTAssertEqual(try store.find(String(soup.id.uuidString.prefix(8))).id, soup.id)
        XCTAssertEqual(try store.find("soup").id, soup.id)
        XCTAssertThrowsError(try store.find("tomato")) { error in
            guard case RecipeError.ambiguous = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try store.find("pizza"))
    }

    func testMinimalJSONDecodes() throws {
        let data = Data(#"{"title":"Toast","createdAt":"2026-01-01T10:00:00.123Z"}"#.utf8)
        let recipe = try RecipeCoding.makeDecoder().decode(Recipe.self, from: data)
        XCTAssertEqual(recipe.title, "Toast")
        XCTAssertTrue(recipe.ingredients.isEmpty)
    }

    func testSearchMatchesIngredientsAndTags() {
        let recipe = Recipe(title: "Toast", ingredients: ["sourdough bread"], tags: ["breakfast"])
        XCTAssertTrue(recipe.matches("bread breakfast"))
        XCTAssertFalse(recipe.matches("butter"))
    }
}
