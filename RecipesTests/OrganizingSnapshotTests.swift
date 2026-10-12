import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Organizing", .serialized)
@MainActor
struct OrganizingSnapshotTests {
    @Test("compact list with small photos on the left (the default)")
    func compactList() {
        assertPageSnapshots(of: RecipeListView(
            collection: .constant(.all), selection: .constant(nil), showsCollectionMenu: true, styleOverride: .list
        ))
    }

    @Test("photo cards")
    func photoCards() {
        assertPageSnapshots(of: RecipeListView(
            collection: .constant(.all), selection: .constant(nil), showsCollectionMenu: true, styleOverride: .cards
        ))
    }

    @Test("nested category menu content")
    func nestedCategory() {
        assertPageSnapshots(of: Self.list(.category("Dinner/Pasta")))
    }

    @Test("editor: categories, favorite, want to cook")
    func editor() {
        assertPageSnapshots(of: RecipeEditorView(recipe: SampleData.chili) { _, _ in }, inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet)
    }

    #if os(macOS)
    @Test("sidebar: collections and feeds")
    func sidebar() {
        assertPageSnapshots(
            of: SidebarView(section: .constant(.recipes(.favorites)), addingFeed: .constant(false)),
            inNavigationStack: false, macSize: CGSize(width: 260, height: 700)
        )
    }
    #endif

    private static func list(_ collection: RecipeCollection) -> some View {
        RecipeListView(collection: .constant(collection), selection: .constant(nil), showsCollectionMenu: true)
    }
}
