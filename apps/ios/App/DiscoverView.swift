import RecipeKit
import SwiftUI

/// Set inside Discover, where the Recipes tab's views show a shared server's recipes read-only and offer to add them to yours.
struct DiscoverScope {
    let catalog: DiscoverCatalog
    let add: @MainActor (Recipe.ID) -> Void
}

private struct DiscoverScopeKey: EnvironmentKey {
    static let defaultValue: DiscoverScope? = nil
}

extension EnvironmentValues {
    var discover: DiscoverScope? {
        get { self[DiscoverScopeKey.self] }
        set { self[DiscoverScopeKey.self] = newValue }
    }
}

enum DiscoverRoute: Hashable {
    case home
    case collection(RecipeCollection)
    case recipe(UUID)
}

/// A page inside one Discover server: its home, a collection or category, or a recipe.
struct DiscoverPage: View {
    @EnvironmentObject private var discover: DiscoverController
    let sourceID: UUID
    let route: DiscoverRoute
    let open: (Recipe.ID) -> Void

    var body: some View {
        if let catalog = discover.catalog(for: sourceID) {
            DiscoverCatalogPage(catalog: catalog, route: route, open: open)
        } else {
            ContentUnavailableView("Server Removed", systemImage: "binoculars", description: Text("This server isn't in Discover anymore."))
        }
    }
}

private struct DiscoverCatalogPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @ObservedObject var catalog: DiscoverCatalog
    let route: DiscoverRoute
    let open: (Recipe.ID) -> Void
    @State private var selection: Recipe.ID?

    var body: some View {
        content
            .environmentObject(catalog.library)
            .environment(\.discover, DiscoverScope(catalog: catalog) { [library, catalog] id in
                Task { await catalog.add(id, to: library) }
            })
            .task { await catalog.load() }
            .onChange(of: selection) { _, id in
                guard let id else { return }
                open(id)
                selection = nil
            }
            .alert("Couldn't Add Recipe", isPresented: Binding(get: { catalog.problem != nil }, set: { if !$0 { catalog.problem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(catalog.problem ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .home:
            #if os(iOS)
            DiscoverHomeView(catalog: catalog)
            #else
            RecipeListView(collection: .constant(.all), selection: $selection)
            #endif
        case .collection(let collection):
            RecipeListView(collection: .constant(collection), selection: $selection)
        case .recipe(let id):
            DiscoverRecipePage(catalog: catalog, id: id)
        }
    }
}

private struct DiscoverRecipePage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.discover) private var scope
    @ObservedObject var catalog: DiscoverCatalog
    let id: UUID
    @State private var photo: Data?
    @State private var loaded = false
    @State private var failure: String?

    var body: some View {
        Group {
            if loaded, let recipe = library.recipe(id: id), catalog.detailed.contains(id) {
                RecipeDetailView(
                    recipe: recipe, previewSave: { scope?.add(id) }, previewImage: photo,
                    previewSaveTitle: "Add to My Recipes", previewSaved: catalog.added.contains(id)
                )
                .transition(.opacity)
            } else if let failure {
                ContentUnavailableView("Couldn't Load Recipe", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else {
                RecipeDetailSkeleton(hasPhoto: library.hasImage(id))
            }
        }
        .animation(.recipeArrives, value: loaded)
        .task(id: id) {
            loaded = false
            async let image = catalog.photo(for: id)
            do { try await catalog.loadDetails(id) } catch { failure = error.localizedDescription }
            photo = await image
            loaded = true
        }
    }
}

/// What a Discover server's home shows before its recipes arrive, or when it has none.
struct DiscoverStatusView: View {
    @ObservedObject var catalog: DiscoverCatalog

    var body: some View {
        switch catalog.state {
        case .loading:
            RecipeRowsSkeleton().padding(.top, 16)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Reach \(catalog.source.name)", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await catalog.load() } }
            }
        case .loaded:
            ContentUnavailableView("No Recipes", systemImage: "binoculars", description: Text("\(catalog.source.name) has no recipes to browse yet."))
        }
    }
}

/// Saves the recipe to your own; once it's there, says so instead.
struct DiscoverAddButton: View {
    @ObservedObject var catalog: DiscoverCatalog
    let scope: DiscoverScope
    let id: Recipe.ID

    var body: some View {
        if catalog.added.contains(id) {
            Label("Added to My Recipes", systemImage: "checkmark.circle")
        } else {
            Button("Add to My Recipes", systemImage: "plus.circle") { scope.add(id) }
        }
    }
}

#if os(iOS)
/// Discover when more than one server has been shared: pick which one to browse.
struct DiscoverSourcesView: View {
    @EnvironmentObject private var discover: DiscoverController

    var body: some View {
        List(discover.sources) { source in
            NavigationLink(value: RecipesRoute.discover(source.id, .home)) {
                Label {
                    Text(source.name)
                    if let username = source.username, !username.isEmpty { Text(username) }
                } icon: {
                    Image(systemName: "server.rack")
                }
            }
            .themedRow(raised: true)
        }
        .themedCanvas()
        .navigationTitle("Discover")
    }
}

/// Home's way into Discover: straight into the server when only one has been shared.
struct DiscoverEntryTile: View {
    @Environment(\.appearance) private var appearance
    @Environment(\.appAccent) private var accent
    @Environment(\.openRecipesRoute) private var openRoute
    let sources: [DiscoverSource]

    private var detail: String {
        sources.count == 1 ? sources[0].name : "\(sources.count) servers"
    }

    var body: some View {
        Button { openRoute(.discoverHome(sources)) } label: {
            HStack(spacing: 14) {
                Image(systemName: "binoculars")
                    .appFont(.title2)
                    .foregroundStyle(accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Browse Shared Recipes").appFont(.headline).lineLimit(1)
                    Text(detail).appFont(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").appFont(.footnote, weight: .semibold).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(appearance.surface ?? Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
    }
}

/// A Discover server's home: its collections, then its categories to drill into.
private struct DiscoverHomeView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.discover) private var scope
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject var catalog: DiscoverCatalog

    private var collections: [RecipeCollection] {
        [.all, .recent, .uncategorized].filter { $0 != .uncategorized || !$0.filter(library.recipes).isEmpty }
    }

    var body: some View {
        Group {
            if library.recipes.isEmpty {
                DiscoverStatusView(catalog: catalog)
            } else if sizeClass == .regular {
                grid
            } else {
                list
            }
        }
        .themedCanvas()
        .navigationTitle(catalog.source.name)
    }

    private var list: some View {
        List {
            Section {
                ForEach(collections, id: \.self) { collection in
                    NavigationLink(value: RecipesRoute.opening(collection, in: scope)) {
                        LabeledContent {
                            Text("\(collection.filter(library.recipes).count)").foregroundStyle(.secondary).monospacedDigit()
                        } label: {
                            Label(collection.title, systemImage: collection.symbol)
                        }
                    }
                    .themedRow(raised: true)
                }
            }
            if !library.categoryTree.isEmpty {
                Section("Categories") {
                    ForEach(library.categoryTree) { CategoryRow(node: $0) }
                }
            }
        }
        .contentMargins(.top, 16, for: .scrollContent)
        .refreshable { await catalog.load(force: true) }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                GridSection(title: nil, minimum: 240, spacing: 16) {
                    ForEach(collections, id: \.self) { FolderTile(collection: $0, recipes: library.recipes, scope: scope) }
                }
                if !library.categoryTree.isEmpty {
                    GridSection(title: "Categories", minimum: 240, spacing: 16) {
                        ForEach(library.categoryTree) {
                            FolderTile(collection: .category($0.path), symbol: $0.children.isEmpty ? "tag" : "folder", recipes: library.recipes, scope: scope)
                        }
                    }
                }
            }
            .padding(24)
        }
        .refreshable { await catalog.load(force: true) }
    }
}

extension RecipesRoute {
    /// Discover on the Recipes home: straight into the server when there's only one.
    static func discoverHome(_ sources: [DiscoverSource]) -> RecipesRoute {
        if sources.count == 1, let only = sources.first { return .discover(only.id, .home) }
        return .discoverSources
    }

    /// Opens a collection or category in the library that's showing, which inside Discover is the server's.
    static func opening(_ collection: RecipeCollection, in scope: DiscoverScope?) -> RecipesRoute {
        guard let scope else { return .collection(collection) }
        return .discover(scope.catalog.source.id, .collection(collection))
    }
}
#endif
