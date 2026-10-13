import RecipeKit
import SwiftUI

enum AppSection: Hashable {
    case recipes(RecipeCollection)
    case feed(UUID)
    case calendar
    case groceries
}

#if os(iOS)
struct RootView: View {
    enum AppTab: Hashable { case recipes, feeds, calendar, groceries, search }

    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter
    @State private var tab: AppTab
    @State private var query: String
    private let calendarMode: CalendarMode
    private let showsAddSheet: Bool
    private let recipesPath: [RecipesRoute]
    private let recipeSelection: Recipe.ID?
    private let recipesCollection: RecipeCollection

    init(
        tab: AppTab = .recipes, searchQuery: String = "", calendarMode: CalendarMode = .agenda, showsAddSheet: Bool = false,
        recipesPath: [RecipesRoute] = [], recipeSelection: Recipe.ID? = nil, recipesCollection: RecipeCollection = .all
    ) {
        self.recipesCollection = recipesCollection
        self.recipesPath = recipesPath
        self.recipeSelection = recipeSelection
        _tab = State(initialValue: tab)
        _query = State(initialValue: searchQuery)
        self.calendarMode = calendarMode
        self.showsAddSheet = showsAddSheet
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Recipes", systemImage: "book.closed", value: AppTab.recipes) { RecipesTab(path: recipesPath, selection: recipeSelection, collection: recipesCollection) }
            Tab("Planner", systemImage: "calendar", value: AppTab.calendar) { CalendarTab(mode: calendarMode, showsAddSheet: showsAddSheet) }
            Tab("Groceries", systemImage: "checklist", value: AppTab.groceries) { GroceriesTab() }
            Tab(value: AppTab.search, role: .search) { SearchTab(query: $query) }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .cookModeCover(cook)
        .onChange(of: router.recipeID, initial: true) { _, id in
            if id != nil { tab = .recipes }
        }
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
            }
            .listStyle(.plain)
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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var path: [RecipesRoute]
    @State private var selection: Recipe.ID?
    @State private var sidebarSelection: RecipeCollection?

    init(path: [RecipesRoute] = [], selection: Recipe.ID? = nil, collection: RecipeCollection = .all) {
        _path = State(initialValue: path)
        _selection = State(initialValue: selection)
        _sidebarSelection = State(initialValue: collection)
    }

    var body: some View {
        Group {
            if sizeClass == .regular { columns } else { stack }
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            guard let id else { return }
            if sizeClass == .regular {
                sidebarSelection = .all
                selection = id
            } else {
                path = [.recipe(id)]
            }
            router.recipeID = nil
        }
    }

    /// iPhone: home, then folders, then a recipe, each pushed onto one stack.
    private var stack: some View {
        NavigationStack(path: $path) {
            RecipesHomeView(selection: $selection)
                .navigationDestination(for: RecipesRoute.self) { destination($0) }
        }
        .onChange(of: selection) { _, id in
            guard let id else { return }
            path.append(.recipe(id))
            selection = nil
        }
    }

    /// iPad: collections and categories, the recipes in the one you pick, and the recipe itself.
    private var columns: some View {
        NavigationSplitView {
            RecipesSidebar(selection: $sidebarSelection)
        } content: {
            RecipeListView(
                collection: Binding(get: { sidebarSelection ?? .all }, set: { sidebarSelection = $0 }),
                selection: $selection, showsFolders: false
            )
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
        } detail: {
            if let recipe = library.recipe(id: selection) {
                RecipeDetailView(recipe: recipe).id(recipe.id)
            } else {
                ContentUnavailableView("Select a recipe", systemImage: "fork.knife")
            }
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

struct CalendarTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var path: [UUID] = []
    @State private var selection: Recipe.ID?
    @State private var mode: CalendarMode
    private let showsAddSheet: Bool

    init(mode: CalendarMode = .agenda, showsAddSheet: Bool = false) {
        _mode = State(initialValue: mode)
        self.showsAddSheet = showsAddSheet
    }

    private var optionalMode: Binding<CalendarMode?> {
        Binding(get: { mode }, set: { if let value = $0 { mode = value } })
    }

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                Group {
                    if mode == .agenda {
                        CalendarView(open: { selection = $0 }, mode: $mode)
                    } else {
                        RecipeDrawer(mode: optionalMode)
                    }
                }
                .navigationSplitViewColumnWidth(min: 340, ideal: 380, max: 460)
            } detail: {
                if mode == .planner {
                    WeekPlannerView(open: { selection = $0; mode = .agenda }, mode: $mode)
                } else if let recipe = library.recipe(id: selection) {
                    RecipeDetailView(recipe: recipe).id(recipe.id)
                } else {
                    ContentUnavailableView("Select a meal", systemImage: "calendar")
                }
            }
        } else {
            NavigationStack(path: $path) {
                Group {
                    if mode == .agenda {
                        CalendarView(open: { path.append($0) }, mode: $mode)
                    } else {
                        WeekPlannerView(open: { path.append($0) }, mode: $mode, isCompact: true, showsAddSheet: showsAddSheet)
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let recipe = library.recipe(id: id) {
                        RecipeDetailView(recipe: recipe)
                    }
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
                .toolbar { ClearCompletedButton() }
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
    @State private var calendarMode: CalendarMode

    init(section: AppSection = .recipes(.all), selection: Recipe.ID? = nil, entrySelection: FeedEntry.ID? = nil, calendarMode: CalendarMode = .agenda) {
        _calendarMode = State(initialValue: calendarMode)
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
            case .calendar:
                if calendarMode == .agenda {
                    CalendarView(open: { selection = $0 }, mode: $calendarMode)
                } else {
                    RecipeDrawer(mode: Binding(get: { calendarMode }, set: { if let value = $0 { calendarMode = value } }))
                }
            case .groceries:
                GroceriesView(layout: .toBuy)
            }
        } detail: {
            switch section ?? .recipes(.all) {
            case .groceries:
                GroceriesView(layout: .completed)
            case .calendar where calendarMode == .planner:
                WeekPlannerView(open: { selection = $0; calendarMode = .agenda }, mode: $calendarMode)
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
                Text("Recipes").font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(.primary)
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
                Label("Planner", systemImage: "calendar").tag(AppSection.calendar)
                Label("Groceries", systemImage: "checklist").tag(AppSection.groceries)
            }
        }
        .safeAreaInset(edge: .bottom) {
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
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
    }

    private func categoryRows(_ node: CategoryNode) -> AnyView {
        if node.children.isEmpty { return AnyView(row(.category(node.path))) }
        let expanded = Binding(
            get: { !collapsed.contains(node.path) },
            set: { if $0 { collapsed.remove(node.path) } else { collapsed.insert(node.path) } }
        )
        return AnyView(
            DisclosureGroup(isExpanded: expanded) {
                ForEach(node.children) { categoryRows($0) }
            } label: { row(.category(node.path)) }
        )
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
