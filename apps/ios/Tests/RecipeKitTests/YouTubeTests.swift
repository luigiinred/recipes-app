import XCTest
@testable import RecipeKit

final class YouTubeTests: XCTestCase {
    func testPlayerShapeFromOEmbed() {
        func ratio(_ width: Int, _ height: Int) -> Double? {
            YouTubeImporter.aspectRatio(fromOEmbed: Data("{\"width\":\(width),\"height\":\(height)}".utf8))
        }
        XCTAssertEqual(ratio(113, 200), 113.0 / 200.0)
        XCTAssertEqual(ratio(200, 113) ?? 0, 1.77, accuracy: 0.01)
        XCTAssertEqual(ratio(10, 100), 0.5)
        XCTAssertNil(YouTubeImporter.aspectRatio(fromOEmbed: Data("{}".utf8)))
    }

    func testVideoIDs() {
        func id(_ s: String) -> String? { YouTubeImporter.videoID(from: URL(string: s)!) }
        XCTAssertEqual(id("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10"), "dQw4w9WgXcQ")
        XCTAssertEqual(id("https://youtu.be/dQw4w9WgXcQ?si=abc"), "dQw4w9WgXcQ")
        XCTAssertEqual(id("https://m.youtube.com/shorts/dQw4w9WgXcQ"), "dQw4w9WgXcQ")
        XCTAssertEqual(id("https://www.youtube.com/embed/dQw4w9WgXcQ"), "dQw4w9WgXcQ")
        XCTAssertNil(id("https://www.youtube.com/@channel"))
        XCTAssertNil(id("https://example.com/watch?v=dQw4w9WgXcQ"))
    }

    func testDescriptionWithRecipeBecomesComplete() {
        let video = YouTubeVideo(id: "dQw4w9WgXcQ", title: "Easy Shakshuka", channel: "Cook Along", description: """
        My favorite breakfast, ready in 20 minutes!
        0:00 Intro
        INGREDIENTS:
        2 tbsp olive oil
        1 onion
        1 can crushed tomatoes
        4 eggs
        INSTRUCTIONS:
        1. Soften the onion in the oil.
        2. Add the tomatoes and simmer for 10 minutes.
        3. Crack in the eggs and cover.
        Subscribe for more! https://example.com
        https://instagram.com/cookalong
        #shakshuka #breakfast
        """)
        let (recipe, complete) = YouTubeImporter.build(from: video, extracted: nil)
        XCTAssertTrue(complete)
        XCTAssertEqual(recipe.title, "Easy Shakshuka")
        XCTAssertEqual(recipe.ingredients, ["2 tbsp olive oil", "1 onion", "1 can crushed tomatoes", "4 eggs"])
        XCTAssertEqual(recipe.steps.count, 3)
        XCTAssertEqual(recipe.summary, "My favorite breakfast, ready in 20 minutes!")
        XCTAssertEqual(recipe.tags, ["YouTube", "Eggs", "Vegetarian"])
        XCTAssertEqual(recipe.sourceURL, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testChattyDescriptionNeedsReviewUnlessTranscriptExtracted() {
        let video = YouTubeVideo(id: "dQw4w9WgXcQ", title: "Best Pasta", channel: "Chef", description: "Thanks for watching, this pasta is so good and easy to make.\n2 cups of love")
        let (partial, complete) = YouTubeImporter.build(from: video, extracted: nil)
        XCTAssertFalse(complete)
        XCTAssertTrue(partial.ingredients.isEmpty)
        XCTAssertFalse(partial.notes.isEmpty)

        let extracted = TranscriptRecipeExtractor.Extracted(ingredients: ["200g pasta", "2 tbsp butter"], steps: ["Boil the pasta.", "Toss with butter."], servings: 2, summary: "Buttery pasta.")
        let (filled, filledComplete) = YouTubeImporter.build(from: video, extracted: extracted)
        XCTAssertTrue(filledComplete)
        XCTAssertEqual(filled.ingredients, ["200g pasta", "2 tbsp butter"])
        XCTAssertEqual(filled.servings, 2)
    }

    func testCaptionParsing() {
        let xml = #"<transcript><text start="0" dur="2">Today we&amp;#39;re making soup</text><text start="2" dur="2">add two cups of stock</text></transcript>"#
        XCTAssertEqual(YouTubeImporter.parseCaptions(xml), "Today we're making soup add two cups of stock")
    }

    func testWebImageExtraction() throws {
        let html = """
        <meta property="og:image" content="https://example.com/p.jpg">
        <script type="application/ld+json">{"@type":"Recipe","name":"Toast","image":[{"@type":"ImageObject","url":"https://example.com/toast.jpg"}]}</script>
        """
        XCTAssertEqual(try RecipeImporter.recipe(fromHTML: html, sourceURL: nil).imageURL, "https://example.com/toast.jpg")
        let og = #"<meta property="og:image" content="/p.jpg"><script type="application/ld+json">{"@type":"Recipe","name":"Toast"}</script>"#
        XCTAssertEqual(try RecipeImporter.recipe(fromHTML: og, sourceURL: nil).imageURL, "/p.jpg")
    }
}
