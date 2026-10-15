#if os(iOS)
import RecipeKit
import SwiftUI

/// The iPad sidebar: the built-in collections, then the category tree. At most two levels are visible at a glance;
/// deeper categories fold away.
struct RecipesSidebar: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @Binding var selection: RecipeCollection?
    @State private var collapsed: Set<String> = []
    @State private var showingSettings = false

    private var collections: [RecipeCollection] {
        let liked: RecipeCollection = (RatingStyle(rawValue: ratingStyleRaw) ?? .favorites) == .stars ? .topRated : .favorites
        return [.all, .recent, liked, .uncategorized].filter { $0 == .all || $0 == .recent || $0 == liked || !$0.filter(library.recipes).isEmpty }
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(collections, id: \.self) { row($0) }
            }
            if !library.categoryTree.isEmpty {
                Section("Categories") {
                    ForEach(library.categoryTree) { categoryRows($0) }
                }
            }
        }
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    private func row(_ collection: RecipeCollection) -> some View {
        LabeledContent {
            Text("\(collection.filter(library.recipes).count)").foregroundStyle(.secondary).monospacedDigit()
        } label: {
            Label(collection.title, systemImage: collection.symbol)
        }
        .tag(collection)
    }

    private func categoryRows(_ node: CategoryNode) -> AnyView {
        let collection = RecipeCollection.category(node.path)
        if node.children.isEmpty { return AnyView(row(collection)) }
        let expanded = Binding(
            get: { !collapsed.contains(node.path) },
            set: { if $0 { collapsed.remove(node.path) } else { collapsed.insert(node.path) } }
        )
        return AnyView(
            DisclosureGroup(isExpanded: expanded) {
                ForEach(node.children) { categoryRows($0) }
            } label: { row(collection) }
        )
    }
}
#endif
