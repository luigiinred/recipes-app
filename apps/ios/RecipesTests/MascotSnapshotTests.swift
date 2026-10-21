import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Mascots", .serialized)
@MainActor
struct MascotSnapshotTests {
    @Test("every character in every scene")
    func scenes() {
        MascotCast.deterministic = true
        let sheet = VStack(spacing: 6) {
            ForEach(MascotScene.allCases, id: \.self) { scene in
                HStack(spacing: 4) {
                    ForEach(MascotCharacter.allCases, id: \.self) { MascotView(character: $0, scene: scene, height: 64) }
                }
            }
        }.padding(8)
        assertPageSnapshots(of: sheet, inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("a stir fry through the loop")
    func stirFryFrames() {
        MascotCast.deterministic = true
        let frames = HStack(spacing: 0) {
            ForEach([0.0, 0.15, 0.3, 0.45, 0.7], id: \.self) { MascotView(character: .tomato, scene: .stirFry, height: 70, frozenAt: $0) }
        }.padding(8)
        assertPageSnapshots(of: frames, inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("ingredients")
    func ingredients() {
        MascotCast.deterministic = true
        let row = HStack { ForEach(Produce.allCases, id: \.self) { ProduceView(produce: $0, height: 48) } }.padding(8)
        assertPageSnapshots(of: row, inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    @Test("import loading, part way through")
    func importLoading() {
        let model = ImportProgressModel()
        model.apply(.plan(["Fetching the page", "Parsing recipe details", "Finding ingredients", "Adding to your cookbook"]))
        model.apply(.finished(0)); model.apply(.finished(1))
        let page = ImportLoadingView(title: "Importing recipe…", subtitle: "allrecipes.com", model: model, cancel: {}, character: .potato, mascotFrozenAt: 0.33)
        assertPageSnapshots(of: page.paperBackground(), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .screen)
    }

    @Test("empty states")
    func emptyStates() {
        let page = VStack {
            MascotEmptyState(scene: .wave, character: .tomato, title: "No recipes yet", message: "Tap + to add one, or share one from Safari.")
            MascotEmptyState(scene: .hop, character: .lemon, title: "Nothing to buy", message: "Add ingredients from any recipe.")
        }
        assertPageSnapshots(of: page.paperBackground(), inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }
}
