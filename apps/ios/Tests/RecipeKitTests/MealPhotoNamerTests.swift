import XCTest
@testable import RecipeKit

final class MealPhotoNamerTests: XCTestCase {
    func testLabelPromptListsConfidentLabelsMostLikelyFirst() {
        let prompt = MealPhotoNamer.labelPrompt([
            ("food", 0.9), ("fried_rice", 0.95), ("plate", 0.05),
        ])
        XCTAssertEqual(prompt, "Image recognition looked at a photo of a meal and saw, most likely first: fried rice (95%), food (90%). Name the dish.")
    }

    func testLabelPromptIsNilWithoutConfidentLabels() {
        XCTAssertNil(MealPhotoNamer.labelPrompt([("plate", 0.05)]))
        XCTAssertNil(MealPhotoNamer.labelPrompt([]))
    }
}
