import RecipeKit
import SwiftUI

enum AppSection: Hashable {
    case recipes(RecipeCollection)
    case feed(UUID)
    case plan
    case groceries
}

#if os(iOS)
struct RootView: View {
    enum AppTab: Hashable {
        case recipes, feeds, plan, groceries, settings, search
    }

    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab: AppTab
    @State private var query: String
    private let planMode: PlanMode
    private let showsSmartPlan: Bool
    private let recipesPath: [RecipesRoute]
    private let recipeSelection: Recipe.ID?
    private let recipesCollection: RecipeCollection

    init(
        tab: AppTab = .recipes, searchQuery: String = "", planMode: PlanMode = .queue, showsSmartPlan: Bool = false,
        recipesPath: [RecipesRoute] = [], recipeSelection: Recipe.ID? = nil, recipesCollection: RecipeCollection = .all
    ) {
        self.recipesCollection = recipesCollection
        self.recipesPath = recipesPath
        self.recipeSelection = recipeSelection
        _tab = State(initialValue: tab)
        _query = State(initialValue: searchQuery)
        self.planMode = planMode
        self.showsSmartPlan = showsSmartPlan
    }

    /// The tab bar and the sidebar are one component on iPad. Collections and categories filter the Recipes tab.
    var body: some View {
        TabView(selection: $tab) {
            Tab("Recipes", systemImage: "book.closed", value: AppTab.recipes) { RecipesTab(path: recipesPath, selection: recipeSelection, collection: recipesCollection) }
            Tab("Plan", systemImage: "calendar", value: AppTab.plan) { PlanTab(mode: planMode, showsSmartPlan: showsSmartPlan) }
            Tab("Groceries", systemImage: "checklist", value: AppTab.groceries) { GroceriesTab() }
            if sizeClass == .regular {
                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) { SettingsView(inSheet: false, splitsPages: true) }
            }
            Tab(value: AppTab.search, role: .search) { SearchTab(query: $query) }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sidebarFirst()
        .reviewPrompt()
        .tabViewSearchActivation(.searchTabSelection)
        .cookModeCover(cook)
        .onChange(of: router.recipeID, initial: true) { _, id in
            if id != nil { tab = .recipes }
        }
    }
}

private extension View {
    /// Starts iPad in the sidebar, where the user can still switch to the top tab bar.
    @ViewBuilder
    func sidebarFirst() -> some View {
        if #available(iOS 27.0, *) { defaultTabBarPlacement(.sidebar) } else { self }
    }
}

struct SearchTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var query: String
    @State private var path: [UUID] = []

    private var results: [Recipe] {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : library.recipes.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List(results) { recipe in
                NavigationLink(value: recipe.id) { RecipeRow(recipe: recipe) }
                    .themedRow()
                    .recipeSwipeActions(for: recipe)
            }
            .listStyle(.plain)
            .themedCanvas()
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Search Recipes", systemImage: "magnifyingglass",
                                           description: Text("Find a recipe by name, ingredient, or category."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: UUID.self) { id in
                if let recipe = library.recipe(id: id) { RecipeDetailView(recipe: recipe) }
            }
        }
        .searchable(text: $query, prompt: "Search recipes")
    }
}

struct RecipesTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @State private var path: [RecipesRoute]
    @State private var selection: Recipe.ID?

    init(path: [RecipesRoute] = [], selection: Recipe.ID? = nil, collection: RecipeCollection = .all) {
        var path = path
        if path.isEmpty {
            if collection != .all { path.append(.collection(collection)) }
            if let selection { path.append(.recipe(selection)) }
        }
        _path = State(initialValue: path)
    }

    /// Home, then a collection or category, then a recipe, each pushed onto one stack. On iPad the first two are grids and a recipe fills the screen.
    var body: some View {
        NavigationStack(path: $path) {
            RecipesHomeView(selection: $selection)
                .navigationDestination(for: RecipesRoute.self) { destination($0) }
        }
        .onChange(of: selection) { _, id in
            guard let id else { return }
            path.append(.recipe(id))
            selection = nil
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            guard let id else { return }
            path = [.recipe(id)]
            router.recipeID = nil
        }
    }

    @ViewBuilder
    private func destination(_ route: RecipesRoute) -> some View {
        switch route {
        case .collection(let collection):
            RecipeListView(collection: .constant(collection), selection: $selection)
        case .recipe(let id):
            if let recipe = library.recipe(id: id) { RecipeDetailView(recipe: recipe).id(id) }
        }
    }
}

struct PlanTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var path: [UUID] = []
    @State private var mode: PlanMode
    private let showsSmartPlan: Bool

    init(mode: PlanMode = .queue, showsSmartPlan: Bool = false) {
        _mode = State(initialValue: mode)
        self.showsSmartPlan = showsSmartPlan
    }

    var body: some View {
        NavigationStack(path: $path) {
            PlanView(mode: $mode, open: { path.append($0) }, showsSmartPlan: showsSmartPlan)
                .navigationDestination(for: UUID.self) { id in
                    if let recipe = library.recipe(id: id) {
                        RecipeDetailView(recipe: recipe)
                    }
                }
        }
    }
}

struct GroceriesTab: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    GroceriesView(layout: .toBuy, embedded: true)
                    Divider()
                    GroceriesView(layout: .completed, embedded: true)
                }
                .navigationTitle("Groceries")
                .toolbar { GroceriesMenu() }
            } else {
                GroceriesView(layout: .combined)
            }
        }
    }
}
#else
struct RootView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter

    @State private var section: AppSection?
    @State private var selection: Recipe.ID?
    @State private var entrySelection: FeedEntry.ID?
    @State private var collection: RecipeCollection
    @State private var addingFeed = false
    @State private var planMode: PlanMode

    init(section: AppSection = .recipes(.all), selection: Recipe.ID? = nil, entrySelection: FeedEntry.ID? = nil, planMode: PlanMode = .queue) {
        _planMode = State(initialValue: planMode)
        _section = State(initialValue: section)
        _selection = State(initialValue: selection)
        _entrySelection = State(initialValue: entrySelection)
        if case .recipes(let collection) = section {
            _collection = State(initialValue: collection)
        } else {
            _collection = State(initialValue: .all)
        }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(section: $section, addingFeed: $addingFeed)
        } content: {
            switch section ?? .recipes(.all) {
            case .recipes:
                RecipeListView(collection: $collection, selection: $selection)
            case .feed(let id):
                if let feed = library.feeds.first(where: { $0.id == id }) {
                    FeedEntriesList(feed: feed, selection: $entrySelection).id(feed.id)
                }
            case .plan:
                PlanView(mode: $planMode, open: { selection = $0 })
            case .groceries:
                GroceriesView(layout: .toBuy)
            }
        } detail: {
            switch section ?? .recipes(.all) {
            case .groceries:
                GroceriesView(layout: .completed)
            case .feed(let id):
                FeedDetail(feedID: id, entryID: entrySelection)
            default:
                if let recipe = library.recipe(id: selection) {
                    RecipeDetailView(recipe: recipe).id(recipe.id)
                } else {
                    ContentUnavailableView("Select a recipe", systemImage: "fork.knife")
                }
            }
        }
        .onChange(of: section) { _, new in
            if case .recipes(let newCollection) = new { collection = newCollection }
            entrySelection = nil
        }
        .sheet(isPresented: $addingFeed) { AddFeedSheet() }
        .cookModeCover(cook)
        .onChange(of: router.recipeID, initial: true) { _, id in
            guard let id else { return }
            section = .recipes(.all)
            selection = id
            router.recipeID = nil
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.onboardingCompleted) private var onboarded = false
    @AppStorage(AppSettings.Key.reviewPromptDismissed) private var reviewDismissed = false
    @Binding var section: AppSection?
    @Binding var addingFeed: Bool
    @State private var collapsed: Set<String> = []

    var body: some View {
        List(selection: $section) {
            Section {
                row(.all)
                ForEach(RecipeCollection.smart(for: RatingStyle(rawValue: ratingStyleRaw) ?? .favorites), id: \.self) { row($0) }
                ForEach(library.categoryTree) { categoryRows($0) }
            } header: {
                Text("Recipes").font(.system(.title2, weight: .bold)).foregroundStyle(.primary)
            }
            if AppFeatures.feeds {
            Section("Feeds") {
                ForEach(library.feeds) { feed in
                    Label(feed.title, systemImage: "dot.radiowaves.up.forward").lineLimit(1)
                        .tag(AppSection.feed(feed.id))
                        .contextMenu {
                            Button("Unsubscribe", role: .destructive) { Task { await library.remove(feed) } }
                        }
                }
                Button { addingFeed = true } label: { Label("Add Feed…", systemImage: "plus") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            }
            Section {
                Label("Plan", systemImage: "calendar").tag(AppSection.plan)
                Label("Groceries", systemImage: "checklist").tag(AppSection.groceries)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if ReviewPrompt.isDue(recipes: library.recipes, onboarded: onboarded, dismissed: reviewDismissed) {
                    ReviewPromptBanner().padding(.vertical, 8)
                }
                HStack {
                    Label(library.isICloud ? "Synced with iCloud" : "Stored on this device",
                          systemImage: library.isICloud ? "icloud" : "internaldrive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    SettingsLink { Image(systemName: "gearshape") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Settings")
                }
                .padding(10)
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
    }

    private func categoryRows(_ node: CategoryNode) -> AnyView {
        if node.children.isEmpty { return AnyView(categoryRow(node.path)) }
        let expanded = Binding(
            get: { !collapsed.contains(node.path) },
            set: { if $0 { collapsed.remove(node.path) } else { collapsed.insert(node.path) } }
        )
        return AnyView(
            DisclosureGroup(isExpanded: expanded) {
                ForEach(node.children) { categoryRows($0) }
            } label: { categoryRow(node.path) }
        )
    }

    /// Dropping a recipe on a category files it there.
    private func categoryRow(_ path: String) -> some View {
        row(.category(path))
            .dropDestination(for: RecipeDragItem.self) { items, _ in
                Task { for item in items { await library.addTag(item.id, to: path) } }
                return !items.isEmpty
            }
    }

    private func row(_ collection: RecipeCollection) -> some View {
        Label(collection.title, systemImage: collection.symbol)
            .tag(AppSection.recipes(collection))
    }
}

struct FeedDetail: View {
    @EnvironmentObject private var loader: FeedLoader
    let feedID: UUID
    let entryID: FeedEntry.ID?

    var body: some View {
        if let entryID, case .loaded(let entries)? = loader.states[feedID], let entry = entries.first(where: { $0.id == entryID }) {
            FeedEntryPreview(entry: entry)
        } else {
            ContentUnavailableView("Select a post", systemImage: "dot.radiowaves.up.forward")
        }
    }
}
#endif
