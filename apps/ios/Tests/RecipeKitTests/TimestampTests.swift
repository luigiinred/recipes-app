import XCTest
@testable import RecipeKit

final class TimestampTests: XCTestCase {
    private let captions = [
        CaptionSegment(start: 0, duration: 5, text: "Hey everyone today we are making shakshuka"),
        CaptionSegment(start: 20, duration: 6, text: "First dice one big onion and slice the red pepper"),
        CaptionSegment(start: 45, duration: 6, text: "Warm the olive oil in a wide pan and cook the onion and pepper until soft"),
        CaptionSegment(start: 80, duration: 6, text: "Now stir in the garlic cumin and paprika for one minute until fragrant"),
        CaptionSegment(start: 120, duration: 6, text: "Pour in the crushed tomatoes season well and let it simmer until thickened"),
        CaptionSegment(start: 170, duration: 6, text: "Make four wells and crack in the eggs then cover the pan"),
    ]

    func testAlignsStepsInOrder() {
        let steps = [
            "Warm the olive oil in a wide pan and cook the onion and pepper until soft.",
            "Stir in the garlic, cumin and paprika and cook for 1 minute until fragrant.",
            "Pour in the tomatoes, season well, and simmer until thickened.",
            "Make four wells in the sauce and crack in the eggs. Cover and cook.",
        ]
        let times = StepTimestamper.align(steps: steps, captions: captions, windowSeconds: 10)
        XCTAssertEqual(times, [43, 78, 118, 168])
    }

    func testUnrelatedStepGetsNoTimestamp() {
        XCTAssertEqual(StepTimestamper.align(steps: ["Wash the dishes carefully afterwards"], captions: captions, windowSeconds: 10), [nil])
        XCTAssertEqual(StepTimestamper.align(steps: ["Dice the onion"], captions: [], windowSeconds: 10), [nil])
    }

    func testClockFormatting() {
        XCTAssertEqual(Recipe.clock(83), "1:23")
        XCTAssertEqual(Recipe.clock(3725), "1:02:05")
        XCTAssertEqual(Recipe.seconds(fromClock: "1:23"), 83)
        XCTAssertEqual(Recipe.seconds(fromClock: "90"), 90)
        XCTAssertNil(Recipe.seconds(fromClock: "abc"))
    }

    func testCaptionSegmentParsingBothFormats() {
        let legacy = #"<transcript><text start="1.5" dur="2">Hello &amp;amp; welcome</text></transcript>"#
        XCTAssertEqual(YouTubeImporter.parseCaptionSegments(legacy), [CaptionSegment(start: 1.5, duration: 2, text: "Hello & welcome")])
        let timed = #"<timedtext format="3"><body><p t="2500" d="1500"><s>Add</s><s> salt</s></p></body></timedtext>"#
        XCTAssertEqual(YouTubeImporter.parseCaptionSegments(timed), [CaptionSegment(start: 2.5, duration: 1.5, text: "Add salt")])
    }

    func testMarkdownLinksTimestamps() {
        let recipe = Recipe(
            title: "Soup", steps: ["Chop.", "Simmer."], stepTimestamps: [nil, 95],
            sourceURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )
        XCTAssertTrue(recipe.markdown.contains("2. Simmer. [▶ 1:35](https://youtu.be/dQw4w9WgXcQ?t=95)"))
        XCTAssertTrue(recipe.markdown.contains("1. Chop.\n"))
    }
}
