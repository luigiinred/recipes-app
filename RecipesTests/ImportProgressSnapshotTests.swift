import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Import progress", .serialized)
@MainActor
struct ImportProgressSnapshotTests {
    @Test("YouTube import part way through")
    func youtubeInProgress() {
        let model = ImportProgressModel()
        model.apply(.plan(["Finding the video and captions", "Reading the recipe", "Writing it up with the on-device model", "Downloading the photo"]))
        model.apply(.began(0))
        model.apply(.finished(0))
        model.apply(.began(3))
        model.apply(.began(1))
        model.apply(.finished(1))
        model.apply(.began(2))
        assertPageSnapshots(of: ImportProgressView(model: model).padding(24), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("progress fraction counts finished and skipped steps")
    func fraction() {
        let model = ImportProgressModel()
        model.apply(.plan(["a", "b", "c", "d"]))
        #expect(model.fraction == 0)
        model.apply(.finished(0))
        model.apply(.skipped(1))
        model.apply(.began(2))
        #expect(model.fraction == 0.625)
        model.apply(.finished(2))
        model.apply(.finished(3))
        #expect(model.fraction == 1)
    }
}
