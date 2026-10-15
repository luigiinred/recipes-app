import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

#if os(iOS)
@Suite("Collapsing recipe header", .serialized)
@MainActor
struct HeaderSnapshotTests {
    private func page(offset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: CollapsingRecipeHeader<EmptyView, EmptyView>.photoHeight + 62)
                    ForEach(SampleData.chili.ingredients.prefix(10), id: \.self) { Text($0).padding(.horizontal, 20) }
                }
            }
            CollapsingRecipeHeader(title: SampleData.chili.title, topInset: 62, offset: offset) {
                RecipeImageView(recipe: SampleData.chili)
            } actions: {
                HeaderActionButton(title: "Cook", systemImage: "frying.pan", prominent: true) {}
                HeaderActionButton(title: "Groceries", systemImage: "checklist") {}
                HeaderActionButton(title: "Up Next", systemImage: "text.line.first.and.arrowtriangle.forward") {}
                HeaderActionButton(title: "Plan", systemImage: "calendar.badge.plus") {}
            }
        }
    }

    @Test("resting")
    func resting() { assertPageSnapshots(of: page(offset: 0), inNavigationStack: false) }

    @Test("halfway")
    func halfway() { assertPageSnapshots(of: page(offset: 130), inNavigationStack: false) }

    @Test("collapsed into the bar")
    func collapsed() { assertPageSnapshots(of: page(offset: 400), inNavigationStack: false) }
}
#endif
