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
        case home, recipes, feeds, upNext, plan, groceries, settings, discover
        case collection(RecipeCollection)
    }

    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.tabOrder) private var tabOrderRaw = ""
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
        case .upNext: .upNext
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
            case .upNext: AnyView(UpNextTab())
            case .plan: AnyView(PlanTab(showsSmartPlan: showsSmartPlan))
            case .groceries: AnyView(GroceriesTab())
            default: AnyView(SettingsView(inSheet: false, splitsPages: sizeClass == .regular))
            }
        }
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

    /// The tab bar and the sidebar are one component on iPad. Collections and categories filter the library tabs.
    var body: some View {
        TabView(selection: $tab) {
            if sizeClass == .regular { sidebarTabs } else { phoneTabs }
        }
        .environment(browsing)
        .tabViewStyle(.sidebarAdaptable)
        .sidebarFirst()
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
            if inBar(target) { tab = Self.appTab(TabItem(target)) }
            router.destination = nil
        }
        .onChange(of: router.recipeID, initial: true) { _, id in
            if id != nil { tab = libraryTab }
        }
        .onChange(of: router.feedPost, initial: true) { _, entry in
            guard let entry else { return }
            if inBar(.feeds) { tab = .feeds; return }
            tab = libraryTab
            recipesPath = [.feedPost(entry)]
            router.feedPost = nil
        }
        .onChange(of: router.reminder, initial: true) { _, kind in
            switch kind {
            case .logDinner, .planWeek: if inBar(.plan) { tab = .plan }
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
    @Binding private var query: String
    private let sharedPath: Binding<[RecipesRoute]>?
    private let root: RecipesRoute?
    private var showsAllRecipes = false

    init(root: RecipeCollection) {
        self.init(root: .collection(root))
    }

    init(root: RecipesRoute) {
        self.root = root
        sharedPath = nil
        _query = .constant("")
    }

    init(path: Binding<[RecipesRoute]>, query: Binding<String>, showsAllRecipes: Bool = false) {
        root = nil
        sharedPath = path
        _query = query
        self.showsAllRecipes = showsAllRecipes
    }

    private var searchPlacement: SearchFieldPlacement {
        #if os(iOS)
        sizeClass == .regular ? .automatic : .navigationBarDrawer(displayMode: .always)
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
                    RecipesHomeView(selection: $selection, query: query, showsQuickFilters: isTyping || !query.isEmpty,
                                    showsAllRecipes: showsAllRecipes, isTabRoot: true) { isTyping = false }
                        .searchable(text: $query, placement: searchPlacement, prompt: "Search My Recipes")
                        .searchFocused($isTyping)
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
    }

    private func destination(_ route: RecipesRoute) -> some View {
        RecipesRouteDestination(route: route, selection: $selection) { path.append($0) }
    }
}

/// Where a pushed `RecipesRoute` lands, in any stack that pushes them.
struct RecipesRouteDestination: View {
    @EnvironmentObject private var library: RecipeLibrary
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
        case .upNext:
            QueueView { push(.recipe($0)) }.navigationTitle("Up Next")
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
    @AppStorage(AppSettings.Key.tabOrder) private var hiddenTabsRaw = ""

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
        .cleanupScanning()
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
