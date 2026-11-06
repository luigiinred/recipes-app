import RecipeKit
import SwiftUI

enum AppSection: Hashable {
    case recipes(RecipeCollection)
    case discover(UUID)
    case feeds
    case upNext
    case plan
    case groceries
}

#if os(iOS)
struct RootView: View {
    enum AppTab: Hashable {
        case recipes, feeds, upNext, plan, groceries, settings, search, discover
        case collection(RecipeCollection)
    }

    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenTabsRaw = ""
    @AppStorage(AppSettings.Key.settingsInTabBar) private var settingsInTabBar = false
    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab: AppTab
    @State private var query: String
    @State private var browsing = HomeBrowsing()
    private let showsSmartPlan: Bool
    /// Kept here so folding or unfolding a Duo, which swaps the tab items, keeps the open recipe.
    @State private var recipesPath: [RecipesRoute]
    @State private var searchPath: [RecipesRoute] = []

    init(
        tab: AppTab = .recipes, searchQuery: String = "", showsSmartPlan: Bool = false,
        recipesPath: [RecipesRoute] = [], recipeSelection: Recipe.ID? = nil, recipesCollection: RecipeCollection = .all
    ) {
        var path = recipesPath
        if path.isEmpty {
            if recipesCollection != .all { path.append(.collection(recipesCollection)) }
            if let recipeSelection { path.append(.recipe(recipeSelection)) }
        }
        _recipesPath = State(initialValue: path)
        _tab = State(initialValue: tab)
        _query = State(initialValue: searchQuery)
        self.showsSmartPlan = showsSmartPlan
    }

    private var sidebarCollections: [RecipeCollection] {
        RecipeCollection.smart(for: RatingStyle(rawValue: ratingStyleRaw) ?? .favorites)
            .filter { $0 != .uncategorized || !$0.filter(library.recipes).isEmpty }
    }

    private func shows(_ tab: MainTab) -> Bool { !AppSettings.hiddenTabs(hiddenTabsRaw).contains(tab) }

    /// The tab bar and the sidebar are one component on iPad. Collections and categories filter the Recipes tab.
    var body: some View {
        TabView(selection: $tab) {
            if sizeClass == .regular {
                TabSection("Recipes") {
                    Tab("Home", systemImage: "house", value: AppTab.recipes) { RecipesTab(path: $recipesPath, query: $query) }
                    ForEach(sidebarCollections, id: \.self) { collection in
                        Tab(collection.title, systemImage: collection.symbol, value: AppTab.collection(collection)) { RecipesTab(root: collection) }
                            .defaultVisibility(.hidden, for: .tabBar)
                    }
                    if !discover.sources.isEmpty {
                        Tab("Discover", systemImage: "binoculars", value: AppTab.discover) { RecipesTab(root: .discoverHome(discover.sources)) }
                            .defaultVisibility(.hidden, for: .tabBar)
                    }
                    ForEach(library.categoryTree) { node in
                        Tab(node.name, systemImage: node.children.isEmpty ? "tag" : "folder", value: AppTab.collection(.category(node.path))) { RecipesTab(root: .category(node.path)) }
                            .defaultVisibility(.hidden, for: .tabBar)
                    }
                }
            } else {
                Tab("Home", systemImage: "house", value: AppTab.recipes) { RecipesTab(path: $recipesPath, query: $query) }
            }
            if shows(.feeds) {
                Tab("Feeds", systemImage: "dot.radiowaves.up.forward", value: AppTab.feeds) { FeedStreamTab() }
            }
            if shows(.upNext) {
                Tab("Up Next", systemImage: MainTab.upNext.symbol, value: AppTab.upNext) { UpNextTab() }
            }
            if shows(.plan) {
                Tab("Plan", systemImage: "calendar", value: AppTab.plan) { PlanTab(showsSmartPlan: showsSmartPlan) }
            }
            if shows(.groceries) {
                Tab("Groceries", systemImage: "checklist", value: AppTab.groceries) { GroceriesTab() }
            }
            // iPhone opens Settings from the gear on Home unless it's set to sit in the tab bar.
            if sizeClass == .regular || settingsInTabBar {
                Tab("Settings", systemImage: "gearshape", value: AppTab.settings) { SettingsView(inSheet: false, splitsPages: sizeClass == .regular) }
            }
            // Wide screens search from the My Recipes page itself.
            if sizeClass != .regular {
                Tab("Search", systemImage: "magnifyingglass", value: AppTab.search, role: .search) { SearchTab(query: $query, path: $searchPath) }
            }
        }
        .environment(browsing)
        .tabViewStyle(.sidebarAdaptable)
        .sidebarFirst()
        .reviewPrompt()
        .tabViewSearchActivation(.searchTabSelection)
        .toastHost()
        .cookModeCover(cook)
        .onChange(of: settingsInTabBar) { _, shown in
            if !shown, sizeClass != .regular, tab == .settings { tab = .recipes }
        }
        .onChange(of: hiddenTabsRaw) {
            if let hidden = mainTab(tab), !shows(hidden) { tab = .recipes }
        }
        .onChange(of: sizeClass) { _, size in
            if size != .regular, tab == .settings, !settingsInTabBar { tab = .recipes }
            if size != .regular, case .collection(let collection) = tab {
                recipesPath = [.collection(collection)]
                tab = .recipes
                return
            }
            guard size == .regular, tab == .search else { return }
            if !searchPath.isEmpty { recipesPath = searchPath }
            searchPath = []
            tab = .recipes
        }
        .onChange(of: router.destination, initial: true) { _, destination in
            guard let destination else { return }
            let target: AppTab = switch destination {
            case .plan: .plan
            case .groceries: .groceries
            case .feeds: .feeds
            }
            if let main = mainTab(target), shows(main) { tab = target }
            router.destination = nil
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            if id != nil { tab = .recipes }
        }
        .onChange(of: router.feedPost, initial: true) { _, entry in
            if entry != nil { tab = shows(.feeds) ? .feeds : .recipes }
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            switch kind {
            case .logDinner, .planWeek: if shows(.plan) { tab = .plan }
            case .addRecipe: tab = .recipes
            case nil: break
            }
        }
    }

    private func mainTab(_ tab: AppTab) -> MainTab? {
        switch tab {
        case .feeds: .feeds
        case .upNext: .upNext
        case .plan: .plan
        case .groceries: .groceries
        default: nil
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

/// The My Recipes page again, with the search text as one more filter.
struct SearchTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Binding var query: String
    @Binding var path: [RecipesRoute]
    @State private var selection: Recipe.ID?
    @FocusState private var isTyping: Bool

    var body: some View {
        NavigationStack(path: $path) {
            RecipesHomeView(selection: $selection, query: query, showsQuickFilters: true, isSearching: isTyping) { isTyping = false }
                .navigationDestination(for: RecipesRoute.self) { route in
                    switch route {
                    case .collection(let collection):
                        RecipeListView(collection: .constant(collection), selection: $selection)
                    case .recipe(let id):
                        if let recipe = library.recipe(id: id) { RecipeDetailView(recipe: recipe).id(id) }
                    case .tag(let path):
                        RecipesHomeView(selection: $selection, tag: path).id(path)
                    case .allRecipes:
                        RecipesHomeView(selection: $selection, showsAllRecipes: true)
                    case .feeds:
                        FeedStreamView()
                    case .feedPost(let entry):
                        FeedEntryPreview(entry: entry)
                    case .upNext:
                        QueueView { path.append(.recipe($0)) }.navigationTitle("Up Next")
                    case .homeSettings:
                        HomeSettingsPage()
                    case .discoverSources:
                        DiscoverSourcesView()
                    case .discover(let source, let route):
                        DiscoverPage(sourceID: source, route: route) { path.append(.discover(source, .recipe($0))) }
                    }
                }
        }
        .environment(\.openRecipesRoute) { path.append($0) }
        .searchable(text: $query, prompt: "Search My Recipes")
        .searchFocused($isTyping)
        .onChange(of: selection) { _, id in
            guard let id else { return }
            isTyping = false
            path.append(.recipe(id))
            selection = nil
        }
    }
}

struct RecipesTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenTabsRaw = ""
    @State private var localPath: [RecipesRoute] = []
    @State private var selection: Recipe.ID?
    @FocusState private var isTyping: Bool
    @Binding private var query: String
    private let sharedPath: Binding<[RecipesRoute]>?
    private let root: RecipesRoute?

    init(root: RecipeCollection) {
        self.init(root: .collection(root))
    }

    init(root: RecipesRoute) {
        self.root = root
        sharedPath = nil
        _query = .constant("")
    }

    init(path: Binding<[RecipesRoute]>, query: Binding<String>) {
        root = nil
        sharedPath = path
        _query = query
    }

    private var path: [RecipesRoute] {
        get { sharedPath?.wrappedValue ?? localPath }
        nonmutating set { if let sharedPath { sharedPath.wrappedValue = newValue } else { localPath = newValue } }
    }

    /// Home, then a collection or category, then a recipe, each pushed onto one stack. On iPad the first two are grids and a recipe fills the screen.
    var body: some View {
        NavigationStack(path: sharedPath ?? $localPath) {
            Group {
                if let root { destination(root) }
                else if sizeClass == .regular {
                    RecipesHomeView(selection: $selection, query: query, showsQuickFilters: isTyping || !query.isEmpty, isSearching: isTyping) { isTyping = false }
                        .searchable(text: $query, prompt: "Search My Recipes")
                        .searchFocused($isTyping)
                } else {
                    RecipesHomeView(selection: $selection)
                }
            }
            .navigationDestination(for: RecipesRoute.self) { destination($0) }
        }
        .environment(\.openRecipesRoute) { path.append($0) }
        .onChange(of: selection) { _, id in
            guard let id else { return }
            isTyping = false
            path.append(.recipe(id))
            selection = nil
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            guard let id else { return }
            path = [.recipe(id)]
            router.recipeID = nil
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            if kind == .addRecipe { path = [] }
        }
        .onChange(of: router.feedPost, initial: true) { _, entry in
            // The Feeds tab opens the post when it's showing.
            guard let entry, sharedPath != nil, AppSettings.hiddenTabs(hiddenTabsRaw).contains(.feeds) else { return }
            path = [.feedPost(entry)]
            router.feedPost = nil
        }
    }

    @ViewBuilder
    private func destination(_ route: RecipesRoute) -> some View {
        switch route {
        case .collection(let collection):
            RecipeListView(collection: .constant(collection), selection: $selection)
        case .recipe(let id):
            if let recipe = library.recipe(id: id) { RecipeDetailView(recipe: recipe).id(id) }
        case .discoverSources:
            DiscoverSourcesView()
        case .discover(let source, let route):
            DiscoverPage(sourceID: source, route: route) { path.append(.discover(source, .recipe($0))) }
        case .tag(let path):
            RecipesHomeView(selection: $selection, tag: path).id(path)
        case .allRecipes:
            RecipesHomeView(selection: $selection, showsAllRecipes: true)
        case .feeds:
            FeedStreamView()
        case .feedPost(let entry):
            FeedEntryPreview(entry: entry)
        case .upNext:
            QueueView { path.append(.recipe($0)) }.navigationTitle("Up Next")
        case .homeSettings:
            HomeSettingsPage()
        }
    }
}

struct UpNextTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            QueueView { path.append($0) }
                .navigationTitle("Up Next")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: UUID.self) { id in
                    if let recipe = library.recipe(id: id) { RecipeDetailView(recipe: recipe) }
                }
        }
    }
}

struct PlanTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @State private var path: [UUID] = []
    var showsSmartPlan = false

    var body: some View {
        NavigationStack(path: $path) {
            MyWeekView(open: { path.append($0) }, showsSmartPlan: showsSmartPlan)
                .navigationTitle("Plan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { router.add = .plan } label: { Label("Add", systemImage: "plus") }
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let recipe = library.recipe(id: id) {
                        RecipeDetailView(recipe: recipe)
                    }
                }
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            if kind == .logDinner || kind == .planWeek { router.reminder = nil }
        }
    }
}

struct GroceriesTab: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            if sizeClass == .regular {
                GroceriesBoard()
            } else {
                GroceriesView(layout: .combined)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { router.add = .groceries } label: { Label("Add", systemImage: "plus") }
                        }
                    }
            }
        }
    }
}
#endif

/// To buy beside completed, for screens wide enough to show both; on an unfolded Duo the fold divides them.
struct GroceriesBoard: View {
    var body: some View {
        GeometryReader { geometry in
            let fold = geometry.verticalFold
            HStack(spacing: 0) {
                GroceriesView(layout: .toBuy, embedded: true)
                    .frame(width: fold?.minX)
                if let fold {
                    Color.clear.frame(width: fold.width)
                } else {
                    Divider()
                }
                GroceriesView(layout: .completed, embedded: true)
            }
        }
        .navigationTitle("Groceries")
        .toolbar { GroceriesMenu() }
    }
}

#if os(macOS)
struct RootView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenTabsRaw = ""

    @State private var section: AppSection?
    @State private var path: [Recipe.ID]
    @State private var selection: Recipe.ID?
    @State private var collection: RecipeCollection
    init(section: AppSection = .recipes(.all), selection: Recipe.ID? = nil) {
        _section = State(initialValue: section)
        _path = State(initialValue: selection.map { [$0] } ?? [])
        if case .recipes(let collection) = section {
            _collection = State(initialValue: collection)
        } else {
            _collection = State(initialValue: .all)
        }
    }

    /// The sidebar picks a section; a recipe opened from it fills the rest of the window.
    var body: some View {
        NavigationSplitView {
            SidebarView(section: $section)
        } detail: {
            NavigationStack(path: $path) {
                sectionRoot
                    .navigationDestination(for: Recipe.ID.self) { id in
                        if case .discover(let source) = section {
                            DiscoverPage(sourceID: source, route: .recipe(id)) { _ in }.id(id)
                        } else if let recipe = library.recipe(id: id) {
                            RecipeDetailView(recipe: recipe).id(id)
                        }
                    }
            }
        }
        .onChange(of: hiddenTabsRaw) {
            if let section, MainTab.allCases.contains(where: { $0.section == section && AppSettings.hiddenTabs(hiddenTabsRaw).contains($0) }) {
                self.section = .recipes(.all)
            }
        }
        .onChange(of: section) { _, new in
            if case .recipes(let newCollection) = new { collection = newCollection }
            path = []
        }
        .onChange(of: selection) { _, id in
            guard let id else { return }
            path.append(id)
            selection = nil
        }
        .toastHost()
        .cookModeCover(cook)
        .onChange(of: router.destination, initial: true) { _, destination in
            guard let destination else { return }
            let target: MainTab = switch destination {
            case .plan: .plan
            case .groceries: .groceries
            case .feeds: .feeds
            }
            if !AppSettings.hiddenTabs(hiddenTabsRaw).contains(target) { section = target.section }
            router.destination = nil
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            guard let id else { return }
            section = .recipes(.all)
            path = [id]
            router.recipeID = nil
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            switch kind {
            case .logDinner, .planWeek:
                if !AppSettings.hiddenTabs(hiddenTabsRaw).contains(.plan) { section = .plan }
                router.reminder = nil
            case .addRecipe:
                section = .recipes(.all)
            case nil: break
            }
        }
    }

    @ViewBuilder
    private var sectionRoot: some View {
        switch section ?? .recipes(.all) {
        case .recipes:
            RecipeListView(collection: $collection, selection: $selection)
        case .discover(let source):
            DiscoverPage(sourceID: source, route: .home) { path.append($0) }.id(source)
        case .feeds:
            FeedStreamView()
        case .plan:
            MyWeekView(open: { path.append($0) }).navigationTitle("Plan")
        case .upNext:
            QueueView { path.append($0) }.navigationTitle("Up Next")
        case .groceries:
            GroceriesBoard()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.onboardingCompleted) private var onboarded = false
    @AppStorage(AppSettings.Key.reviewPromptDismissed) private var reviewDismissed = false
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenTabsRaw = ""
    @Binding var section: AppSection?
    @State private var recipesExpanded = true
    @State private var collapsed: Set<String> = []

    var body: some View {
        List(selection: $section) {
            Section {
                DisclosureGroup(isExpanded: $recipesExpanded) {
                    row(.all)
                    ForEach(RecipeCollection.smart(for: RatingStyle(rawValue: ratingStyleRaw) ?? .favorites), id: \.self) { row($0) }
                    ForEach(library.categoryTree) { categoryRows($0) }
                } label: {
                    Label("Recipes", systemImage: "fork.knife")
                        .padding(.bottom, 6)
                        .contentShape(Rectangle())
                        .onTapGesture { recipesExpanded.toggle() }
                        .categoryRootDrop()
                }
                let hidden = AppSettings.hiddenTabs(hiddenTabsRaw)
                ForEach(MainTab.allCases.filter { !hidden.contains($0) }, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.symbol).tag(tab.section)
                }
            }
            if !discover.sources.isEmpty {
                Section("Discover") {
                    ForEach(discover.sources) { source in
                        Label(source.name, systemImage: "binoculars").lineLimit(1).tag(AppSection.discover(source.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if ReviewPrompt.isDue(recipes: library.recipes, onboarded: onboarded, dismissed: reviewDismissed) {
                    ReviewPromptBanner().padding(.vertical, 8)
                }
                HStack {
                    Label(library.isICloud ? "Synced with iCloud" : "Stored on this device",
                          systemImage: library.isICloud ? "icloud" : "internaldrive")
                        .appFont(.caption)
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

    /// Drop a recipe on a category to file it there; drag a category to reorder or nest it.
    private func categoryRow(_ path: String) -> some View {
        let collection = RecipeCollection.category(path)
        // The selection tag must wrap the drag and drop modifiers or a click can't select the row.
        return Label(collection.title, systemImage: collection.symbol)
            .categoryDragAndDrop(path)
            .tag(AppSection.recipes(collection))
    }

    private func row(_ collection: RecipeCollection) -> some View {
        Label(collection.title, systemImage: collection.symbol)
            .tag(AppSection.recipes(collection))
    }
}

extension MainTab {
    var section: AppSection {
        switch self {
        case .feeds: .feeds
        case .upNext: .upNext
        case .plan: .plan
        case .groceries: .groceries
        }
    }
}
#endif
