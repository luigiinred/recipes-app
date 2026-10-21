import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Mascots", .serialized)
@MainActor
struct MascotSnapshotTests {
    @Test("every wok frame")
    func wokFrames() {
        let frames = HStack(spacing: 0) { ForEach(0..<5, id: \.self) { TomatoWokLoader(height: 70, frame: $0) } }.padding(8)
        assertPageSnapshots(of: frames, inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("import loading, part way through")
    func importLoading() {
        let model = ImportProgressModel()
        model.apply(.plan(["Fetching the page", "Parsing recipe details", "Finding ingredients", "Adding to your cookbook"]))
        model.apply(.began(0)); model.apply(.finished(0)); model.apply(.began(1)); model.apply(.finished(1)); model.apply(.began(2))
        let page = ImportLoadingView(title: "Importing recipe…", subtitle: "allrecipes.com", model: model, cancel: {})
        assertPageSnapshots(of: page.paperBackground(), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .screen)
    }

    @Test("empty states")
    func emptyStates() {
        let page = VStack {
            MascotEmptyState(mascot: .tomatoWave, title: "No recipes yet", message: "Tap + to add one, or share one from Safari.")
            MascotEmptyState(mascot: .tomatoGroceries, title: "Nothing to buy", message: "Add ingredients from any recipe.")
        }
        assertPageSnapshots(of: page.paperBackground(), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
