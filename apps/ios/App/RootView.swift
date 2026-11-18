import RecipeKit
import SwiftUI

enum AppSection: Hashable {
    case recipes(RecipeCollection)
    case discover(UUID)
    case feeds
    case plan
    case groceries
    case settings
}

#if os(iOS)
struct RootView: View {
    enum AppTab: Hashable {
        case home, recipes, feeds, plan, groceries, settings, discover
        case collection(RecipeCollection)
    }

    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var discover: DiscoverController
    @EnvironmentObject private var feeds: FeedLoader
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.tabOrder) private var tabOrderRaw = ""
    @AppStorage(AppSettings.Key.navigationStyle) private var navigationStyle = NavigationStyle.standard
    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab: AppTab
    @State private var query: String
    @State private var browsing = HomeBrowsing()
    private let showsSmartPlan: Bool
    /// Kept here so folding or unfolding a Duo, which swaps the tab items, keeps the open recipe.
    @State private var recipesPath: [RecipesRoute]
    @State private var otherLibraryPath: [RecipesRoute] = []
    @State private var otherLibraryQuery = ""

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
        let shown = AppSettings.tabs(UserDefaults.standard.string(forKey: AppSettings.Key.tabOrder) ?? "")
        _tab = State(initialValue: tab == .recipes || tab == .home ? Self.appTab(shown.first(where: \.isLibrary) ?? .home) : tab)
        _query = State(initialValue: searchQuery)
        self.showsSmartPlan = showsSmartPlan
    }

    private var sidebarCollections: [RecipeCollection] {
        RecipeCollection.smart(for: RatingStyle(rawValue: ratingStyleRaw) ?? .favorites)
            .filter { $0 != .uncategorized || !$0.filter(library.recipes).isEmpty }
    }

    /// iPhone's tab bar never holds more than five, so it never grows a More tab. iPad's sidebar holds them all.
    private var barTabs: [TabItem] {
        sizeClass == .regular ? AppSettings.tabs(tabOrderRaw) : AppSettings.barTabs(tabOrderRaw)
    }

    private func inBar(_ tab: MainTab) -> Bool { barTabs.contains(TabItem(tab)) }

    /// Where recipes open: the first of Home and Recipes in the bar.
    private var libraryTab: AppTab { Self.appTab(barTabs.first(where: \.isLibrary) ?? .home) }

    private static func appTab(_ item: TabItem) -> AppTab {
        switch item {
        case .home: .home
        case .recipes: .recipes
        case .feeds: .feeds
        case .plan: .plan
        case .groceries: .groceries
        case .settings: .settings
        }
    }

    /// The first library tab keeps the shared stack, so links and a folding Duo land there; the second has its own.
    private func libraryTab(_ item: TabItem) -> some TabContent<AppTab> {
        let primary = Self.appTab(item) == libraryTab
        return Tab(item.title, systemImage: item.symbol, value: Self.appTab(item)) {
            RecipesTab(path: primary ? $recipesPath : $otherLibraryPath, query: primary ? $query : $otherLibraryQuery,
                       showsAllRecipes: item == .recipes)
        }
    }

    private func featureTab(_ item: TabItem) -> some TabContent<AppTab> {
        Tab(item.title, systemImage: item.symbol, value: Self.appTab(item)) {
            switch item {
            case .feeds: AnyView(FeedStreamTab())
            case .plan: AnyView(PlanTab(showsSmartPlan: showsSmartPlan))
            case .groceries: AnyView(GroceriesTab())
            default: AnyView(SettingsView(inSheet: false, splitsPages: sizeClass == .regular))
            }
        }
        .badge(badge(for: item))
    }

    /// New posts on Discover, and what's left to buy on Groceries; nothing shows at zero.
    private func badge(for item: TabItem) -> Text? {
        let count = switch item {
        case .feeds: feeds.items(for: library.feeds).count { !feeds.isViewed($0.entry) }
        case .groceries: library.groceries.count { !$0.isChecked }
        default: 0
        }
        guard count > 0 else { return nil }
        return Text(count > 99 ? "99+" : "\(count)")
    }

    @TabContentBuilder<AppTab>
    private var sidebarTabs: some TabContent<AppTab> {
        let tabs = barTabs
        TabSection("Recipes") {
            ForEach(tabs.filter(\.isLibrary)) { libraryTab($0) }
            ForEach(sidebarCollections, id: \.self) { collection in
                Tab(collection.title, systemImage: collection.symbol, value: AppTab.collection(collection)) { RecipesTab(root: collection) }
                    .defaultVisibility(.hidden, for: .tabBar)
            }
            if !discover.sources.isEmpty {
                Tab("Shared Recipes", systemImage: "binoculars", value: AppTab.discover) { RecipesTab(root: .discoverHome(discover.sources)) }
                    .defaultVisibility(.hidden, for: .tabBar)
            }
            ForEach(library.categoryTree) { node in
                Tab(node.name, systemImage: node.children.isEmpty ? "tag" : "folder", value: AppTab.collection(.category(node.path))) {
                    RecipesTab(root: .category(node.path))
                }
                .defaultVisibility(.hidden, for: .tabBar)
            }
        }
        ForEach(tabs.filter { $0.feature != nil }) { featureTab($0) }
        Tab("Settings", systemImage: "gearshape", value: AppTab.settings) { SettingsView(inSheet: false, splitsPages: true) }
            .defaultVisibility(.hidden, for: .tabBar)
    }

    @TabContentBuilder<AppTab>
    private var phoneTabs: some TabContent<AppTab> {
        ForEach(barTabs) { item in
            if item.isLibrary { libraryTab(item) } else { featureTab(item) }
        }
    }

    /// In Home Screen mode the iPhone has no tab bar: Home links to every page, and its search sits at the bottom.
    private var usesHomeScreen: Bool { sizeClass != .regular && navigationStyle == .home }

    /// The tab bar and the sidebar are one component on iPad. Collections and categories filter the library tabs.
    var body: some View {
        Group {
            if usesHomeScreen {
                RecipesTab(path: $recipesPath, query: $query, searchAtBottom: true)
            } else {
                TabView(selection: $tab) {
                    if sizeClass == .regular { sidebarTabs } else { phoneTabs }
                }
                .tabViewStyle(.sidebarAdaptable)
                .sidebarFirst()
            }
        }
        .environment(browsing)
        .reviewPrompt()
        .toastHost()
        .cleanupScanning()
        .cookModeCover(cook)
        .onChange(of: tabOrderRaw) { keepTabShown() }
        .onChange(of: sizeClass) { _, size in
            if size != .regular, case .collection(let collection) = tab {
                recipesPath = [.collection(collection)]
                tab = libraryTab
            }
            keepTabShown()
        }
        .onChange(of: router.destination, initial: true) { _, destination in
            guard let destination else { return }
            let target: MainTab = switch destination {
            case .plan: .plan
            case .groceries: .groceries
            case .feeds: .feeds
            }
            if usesHomeScreen { recipesPath = [target.route] }
            else if inBar(target) { tab = Self.appTab(TabItem(target)) }
            router.destination = nil
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            if id != nil { tab = libraryTab }
        }
        .onChange(of: router.feedPost, initial: true) { _, entry in
            guard let entry else { return }
            if !usesHomeScreen, inBar(.feeds) { tab = .feeds; return }
            tab = libraryTab
            recipesPath = [.feedPost(entry)]
            router.feedPost = nil
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            switch kind {
            case .logDinner, .planWeek:
                if usesHomeScreen { recipesPath = [.plan] } else if inBar(.plan) { tab = .plan }
            case .addRecipe: tab = libraryTab
            case nil: break
            }
        }
    }

    /// A tab taken out of the bar, or Settings leaving the iPhone bar, falls back to the library.
    private func keepTabShown() {
        let shown: Set<AppTab> = Set(barTabs.map(Self.appTab))
        switch tab {
        case .collection, .discover: if sizeClass != .regular { tab = libraryTab }
        case .settings: if sizeClass != .regular, !shown.contains(.settings) { tab = libraryTab }
        default: if !shown.contains(tab) { tab = libraryTab }
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

struct RecipesTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var localPath: [RecipesRoute] = []
    @State private var selection: Recipe.ID?
    @FocusState private var isTyping: Bool
    /// Stays on until the search is cancelled, so scrolling (which drops the keyboard) keeps the results.
    @State private var isSearchOpen = false
    @Binding private var query: String
    private let sharedPath: Binding<[RecipesRoute]>?
    private let root: RecipesRoute?
    private var showsAllRecipes = false
    private var searchAtBottom = false

    init(root: RecipeCollection) {
        self.init(root: .collection(root))
    }

    init(root: RecipesRoute) {
        self.root = root
        sharedPath = nil
        _query = .constant("")
    }

    init(path: Binding<[RecipesRoute]>, query: Binding<String>, showsAllRecipes: Bool = false, searchAtBottom: Bool = false) {
        root = nil
        sharedPath = path
        _query = query
        self.showsAllRecipes = showsAllRecipes
        self.searchAtBottom = searchAtBottom
    }

    private var searchPlacement: SearchFieldPlacement {
        #if os(iOS)
        // Automatic puts an iPhone's search field in the bottom toolbar.
        sizeClass == .regular || searchAtBottom ? .automatic : .navigationBarDrawer(displayMode: .always)
        #else
        .automatic
        #endif
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
                else {
                    RecipesHomeView(selection: $selection, query: query, showsQuickFilters: isSearchOpen || isTyping || !query.isEmpty,
                                    searchFieldAtBottom: searchAtBottom && isTyping, keyboardIsUp: isTyping,
                                    showsAllRecipes: showsAllRecipes, isTabRoot: true, showsPages: searchAtBottom) { isTyping = false }
                        .searchable(text: $query, isPresented: $isSearchOpen, placement: searchPlacement, prompt: "Search")
                        #if os(iOS)
                        .searchToolbarBehavior(searchAtBottom ? .minimize : .automatic)
                        .toolbar {
                            if searchAtBottom {
                                ToolbarSpacer(.flexible, placement: .bottomBar)
                                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                            }
                        }
                        #endif
                        .searchFocused($isTyping)
                }
            }
            .navigationDestination(for: RecipesRoute.self) { destination($0) }
        }
        .recipeZoomScope()
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
    }

    private func destination(_ route: RecipesRoute) -> some View {
        RecipesRouteDestination(route: route, selection: $selection) { path.append($0) }
    }
}

struct PlanTab: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @State private var path: [UUID] = []
    var showsSmartPlan = false

    var body: some View {
        NavigationStack(path: $path) {
            MealBoardView(open: { path.append($0) }, showsSmartPlan: showsSmartPlan)
                .navigationTitle("Plan")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: UUID.self) { id in
                    if let recipe = library.recipe(id: id) {
                        RecipeDetailView(recipe: recipe)
                    }
                }
        }
        .recipeZoomScope()
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
            }
        }
    }
}
#endif

/// Where a pushed `RecipesRoute` lands, in any stack that pushes them.
struct RecipesRouteDestination: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    let route: RecipesRoute
    @Binding var selection: Recipe.ID?
    let push: (RecipesRoute) -> Void

    var body: some View {
        switch route {
        case .collection(let collection):
            RecipeListView(collection: .constant(collection), selection: $selection)
        case .recipe(let id):
            if let recipe = library.recipe(id: id) { RecipeDetailView(recipe: recipe).id(id) }
        case .discoverSources:
            DiscoverSourcesView()
        case .discover(let source, let route):
            DiscoverPage(sourceID: source, route: route) { push(.discover(source, .recipe($0))) }
        case .tag(let path):
            RecipesHomeView(selection: $selection, tag: path).id(path)
        case .allRecipes:
            RecipesHomeView(selection: $selection, showsAllRecipes: true)
        case .feeds:
            FeedStreamView()
        case .feedPost(let entry):
            FeedEntryPreview(entry: entry)
        case .plan:
            MealBoardView { push(.recipe($0)) }
                .navigationTitle("Plan")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        case .groceries:
            GroceriesView(layout: .combined)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { router.add = .groceries } label: { Label("Add", systemImage: "plus") }
                    }
                }
        case .homeSettings:
            #if os(iOS)
            HomeSettingsPage()
            #else
            ContentUnavailableView("Customize Home in Settings", systemImage: "gearshape")
            #endif
        }
    }
}

extension MainTab {
    var route: RecipesRoute {
        switch self {
        case .feeds: .feeds
        case .plan: .plan
        case .groceries: .groceries
        }
    }
}

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
/// Home is the left column and whatever it opens fills the right one, with its own stack for drilling in.
struct RootView: View {
    @EnvironmentObject private var cook: CookSession
    @EnvironmentObject private var router: AppRouter
    @State private var columns = NavigationSplitViewVisibility.automatic
    @State private var browsing = HomeBrowsing()
    @State private var query = ""
    @State private var homeSelection: Recipe.ID?
    @State private var detail: [RecipesRoute]
    @State private var detailSelection: Recipe.ID?
    @State private var showsSettings = false

    init(selection: Recipe.ID? = nil) {
        _detail = State(initialValue: selection.map { [.recipe($0)] } ?? [])
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            RecipesHomeView(selection: $homeSelection, query: query, showsQuickFilters: !query.isEmpty, isTabRoot: true)
                .searchable(text: $query, placement: .sidebar, prompt: "Search My Recipes")
                .environment(\.openRecipesRoute) { route in
                    homeSelection = nil
                    open(route)
                }
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 520)
        } detail: {
            if showsSettings {
                SettingsView(inSheet: false)
            } else {
                NavigationStack(path: $detail) {
                    ContentUnavailableView("Nothing Open", systemImage: "sidebar.right",
                                           description: Text("Recipes, pages, and posts you open from Home appear here."))
                        .navigationDestination(for: RecipesRoute.self) { route in
                            RecipesRouteDestination(route: route, selection: $detailSelection) { detail.append($0) }
                        }
                }
                .environment(\.openRecipesRoute) { detail.append($0) }
            }
        }
        .environment(browsing)
        .onChange(of: homeSelection) { _, id in
            if let id { open(.recipe(id)) }
        }
        .onChange(of: detailSelection) { _, id in
            guard let id else { return }
            detail.append(.recipe(id))
            detailSelection = nil
        }
        .onChange(of: router.showsSettings) { _, shows in
            guard shows else { return }
            showsSettings = true
            router.showsSettings = false
        }
        .panelHost(sidebar: $columns)
        .frame(minWidth: 720, minHeight: 480)
        .toastHost()
        .cleanupScanning()
        .cookModeCover(cook)
        .onChange(of: router.destination, initial: true) { _, destination in
            guard let destination else { return }
            let route: RecipesRoute = switch destination {
            case .plan: .plan
            case .groceries: .groceries
            case .feeds: .feeds
            }
            open(route)
            router.destination = nil
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            guard let id else { return }
            open(.recipe(id))
            router.recipeID = nil
        }
        .onChange(of: router.feedPost, initial: true) { _, entry in
            guard let entry else { return }
            open(.feedPost(entry))
            router.feedPost = nil
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            if kind == .logDinner || kind == .planWeek {
                open(.plan)
                router.reminder = nil
            }
        }
    }

    private func open(_ route: RecipesRoute) {
        showsSettings = false
        detail = [route]
    }
}

struct SidebarView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.onboardingCompleted) private var onboarded = false
    @AppStorage(AppSettings.Key.reviewPromptDismissed) private var reviewDismissed = false
    @AppStorage(AppSettings.Key.tabOrder) private var hiddenTabsRaw = ""
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
                ForEach(AppSettings.tabs(hiddenTabsRaw).compactMap(\.feature), id: \.self) { tab in
                    Label(tab.title, systemImage: tab.symbol).tag(tab.section)
                }
            }
            if !discover.sources.isEmpty {
                Section("Shared Recipes") {
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
                    Button { section = .settings } label: { Image(systemName: "gearshape") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
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
        case .plan: .plan
        case .groceries: .groceries
        }
    }
}
#endif
