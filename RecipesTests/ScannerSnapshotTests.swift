import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Scanner", .serialized)
@MainActor
struct ScannerSnapshotTests {
    @Test("scanned text turned into a recipe to review")
    func review() {
        let text = SampleData.scannedText
        assertPageSnapshots(
            of: RecipeEditorView(recipe: RecipeTextParser.parse(text), scannedText: text) { _, _ in },
            inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet
        )
    }

    @Test("YouTube video without a full recipe: review before saving")
    func youtubeReview() {
        assertPageSnapshots(
            of: RecipeEditorView(
                recipe: SampleData.youtubeDraft, scannedText: SampleData.transcript, scannedTextTitle: "Video captions",
                notice: SampleData.youtubeNotice, initialImage: SampleData.images[SampleData.pancakes.id]
            ) { _, _ in },
            inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet
        )
    }
}
