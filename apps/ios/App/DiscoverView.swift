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
            RecipesHomeView(selection: $selection)
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
    @State private var failure: String?

    var body: some View {
        Group {
            if let recipe = library.recipe(id: id), catalog.detailed.contains(id) {
                RecipeDetailView(
                    recipe: recipe, previewSave: { scope?.add(id) }, previewImage: photo,
                    previewSaveTitle: "Add to My Recipes", previewSaved: catalog.added.contains(id)
                )
            } else if let failure {
                ContentUnavailableView("Couldn't Load Recipe", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else {
                ProgressView("Loading recipe…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: id) {
            do { try await catalog.loadDetails(id) } catch { failure = error.localizedDescription }
            photo = await catalog.photo(for: id)
        }
    }
}

/// What a Discover server's home shows before its recipes arrive, or when it has none.
struct DiscoverStatusView: View {
    @ObservedObject var catalog: DiscoverCatalog

    var body: some View {
        switch catalog.state {
        case .loading:
            ProgressView("Loading recipes…").frame(maxWidth: .infinity, maxHeight: .infinity)
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
