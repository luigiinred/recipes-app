import XCTest
@testable import RecipeKit

final class LibraryExportTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testExportsEverythingAndRoundTrips() throws {
        let library = Library(root: directory)
        let soup = try library.recipes.save(Recipe(title: "Soup", ingredients: ["6 tomatoes"], steps: ["Simmer."], tags: ["Dinner/Soup"]))
        let toast = try library.recipes.save(Recipe(title: "Toast"))
        let photo = Data([0xFF, 0xD8, 0xFF, 0xD9])
        try library.images.save(photo, for: soup.id)
        try library.mealPlan.save(MealPlanEntry(recipeID: soup.id, title: "Soup", day: "2026-10-12", meal: .dinner))
        try library.groceries.save(GroceryItem(name: "tomatoes", quantity: "6"))
        try library.feeds.save(Feed(url: "https://example.com/feed.xml", title: "Example"))

        let export = try library.export()
        let decoded = try RecipeCoding.makeDecoder().decode(LibraryExport.self, from: try export.jsonData())

        XCTAssertEqual(decoded.version, LibraryExport.currentVersion)
        XCTAssertEqual(decoded.recipes.map(\.title), ["Soup", "Toast"])
        XCTAssertEqual(decoded.recipes.first { $0.id == soup.id }?.tags, ["Dinner/Soup"])
        XCTAssertEqual(decoded.mealPlan.map(\.title), ["Soup"])
        XCTAssertEqual(decoded.groceries.map(\.name), ["tomatoes"])
        XCTAssertEqual(decoded.feeds.map(\.title), ["Example"])
        XCTAssertEqual(decoded.images[soup.id.uuidString.lowercased()], photo)
        XCTAssertNil(decoded.images[toast.id.uuidString.lowercased()])
    }

    func testEmptyLibraryExports() throws {
        let export = try Library(root: directory).export()
        XCTAssertTrue(export.recipes.isEmpty)
        XCTAssertTrue(export.images.isEmpty)
        XCTAssertNoThrow(try export.jsonData())
    }
}
