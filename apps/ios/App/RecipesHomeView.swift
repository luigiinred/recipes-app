#if os(iOS)
import RecipeKit
import SwiftUI

enum RecipeSort: String, CaseIterable {
    case recent, title, rating, quickest, lastCooked, shuffle

    var title: String {
        switch self {
        case .recent: "Most Recent"
        case .title: "Name"
        case .rating: "Rating"
        case .quickest: "Quickest"
        case .lastCooked: "Last Cooked"
        case .shuffle: "Shuffle"
        }
    }

    var symbol: String {
        switch self {
        case .recent: "clock"
        case .title: "textformat"
        case .rating: "star"
        case .quickest: "timer"
        case .lastCooked: "frying.pan"
        case .shuffle: "shuffle"
        }
    }

    /// `seed` keeps a shuffle in the same order until it is shuffled again.
    func sorted(_ recipes: [Recipe], seed: Int = 0) -> [Recipe] {
        switch self {
        case .recent:
            recipes.sorted { $0.createdAt > $1.createdAt }
        case .title:
            recipes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .rating:
            recipes.sorted { ($0.rating ?? 0, $0.isFavorite ? 1 : 0, $0.createdAt) > ($1.rating ?? 0, $1.isFavorite ? 1 : 0, $1.createdAt) }
        case .quickest:
            recipes.sorted { ($0.totalMinutes ?? .max, $0.title) < ($1.totalMinutes ?? .max, $1.title) }
        case .lastCooked:
            recipes.sorted { ($0.lastMade ?? .distantPast, $0.createdAt) > ($1.lastMade ?? .distantPast, $1.createdAt) }
        case .shuffle:
            recipes.sorted { Self.rank($0.id, seed) < Self.rank($1.id, seed) }
        }
    }

    private static func rank(_ id: UUID, _ seed: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(seed)
        hasher.combine(id)
        return hasher.finalize()
    }
}

/// A "Show only" filter in the Recipes home's filter sheet.
enum QuickFilter: String, CaseIterable {
    case under30, under60, liked, upNext, ideas, notMade, videos

    func title(_ style: RatingStyle) -> String {
        switch self {
        case .under30: "Under 30 min"
        case .under60: "Under 1 hour"
        case .liked: style == .stars ? "Top Rated" : "Favorites"
        case .upNext: "Up Next"
        case .ideas: "Ideas"
        case .notMade: "Not Made Yet"
        case .videos: "Videos"
        }
    }

    func symbol(_ style: RatingStyle) -> String {
        switch self {
        case .under30: "clock"
        case .under60: "hourglass"
        case .liked: style == .stars ? "star" : "heart"
        case .upNext: "text.line.first.and.arrowtriangle.forward"
        case .ideas: "lightbulb"
        case .notMade: "sparkles"
        case .videos: "play.rectangle"
        }
    }

    func matches(_ recipe: Recipe, _ style: RatingStyle) -> Bool {
        switch self {
        case .under30: (recipe.totalMinutes ?? .max) <= 30
        case .under60: (recipe.totalMinutes ?? .max) <= 60
        case .liked: style == .stars ? (recipe.rating ?? 0) >= 4 : recipe.isFavorite
        case .upNext: recipe.wantToCook
        case .ideas: recipe.isIdea
        case .notMade: recipe.timeline.isEmpty && !recipe.isIdea
        case .videos: recipe.youTubeVideoID != nil
        }
    }
}


/// A chip in the Search tab's quick filter row: a "Show only" filter or a tag. Settings picks them and their order.
enum QuickChip: Hashable {
    case filter(QuickFilter)
    case tag(String)

    static let defaults: [QuickChip] = [.liked, .upNext, .under30, .under60, .ideas, .notMade, .videos].map { .filter($0) }

    static func parse(_ raw: String) -> [QuickChip] {
        raw.split(separator: "\n").compactMap { QuickChip(token: String($0)) }
    }

    static func raw(_ chips: [QuickChip]) -> String { chips.map(\.token).joined(separator: "\n") }

    init?(token: String) {
        if token.hasPrefix("tag:") { self = .tag(String(token.dropFirst(4))) }
        else if let filter = QuickFilter(rawValue: token) { self = .filter(filter) }
        else { return nil }
    }

    var token: String {
        switch self {
        case .filter(let filter): filter.rawValue
        case .tag(let path): "tag:\(path)"
        }
    }

    func title(_ style: RatingStyle) -> String {
        switch self {
        case .filter(let filter): filter.title(style)
        case .tag(let path): CategoryTree.components(path).last ?? path
        }
    }

    func symbol(_ style: RatingStyle) -> String {
        switch self {
        case .filter(let filter): filter.symbol(style)
        case .tag: "tag"
        }
    }
}

/// A block on the Home page; Settings → Home orders them and hides any.
enum HomeSection: String, CaseIterable, Identifiable {
    case today, upNext, favorites, tags, discover, feeds, recipes

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .upNext: "Up Next"
        case .favorites: "Favorites"
        case .tags: "Tags"
        case .discover: "Discover"
        case .feeds: "Feeds"
        case .recipes: "Recipes"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .upNext: "text.line.first.and.arrowtriangle.forward"
        case .favorites: "heart"
        case .tags: "tag"
        case .discover: "binoculars"
        case .feeds: "dot.radiowaves.up.forward"
        case .recipes: "book.closed"
        }
    }

    var detail: String {
        switch self {
        case .today: "What's planned for today."
        case .upNext: "The recipes you've queued to cook."
        case .favorites: "The recipes you've hearted."
        case .tags: "Your top-level tags as photo tiles."
        case .discover: "Mealie servers shared with you."
        case .feeds: "The newest posts from recipe sites you follow."
        case .recipes: "Your first five recipes, with View All."
        }
    }

    var isOnByDefault: Bool { self != .discover }

    private static func parse(_ raw: String) -> [HomeSection] {
        raw.split(separator: ",").compactMap { HomeSection(rawValue: String($0)) }
    }

    /// Every section in its saved order; ones the saved order doesn't list go after the section they follow by default.
    static func order(_ raw: String) -> [HomeSection] {
        var order = parse(raw)
        for section in allCases where !order.contains(section) {
            let previous = allCases.prefix { $0 != section }.last { order.contains($0) }
            order.insert(section, at: previous.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
        }
        return order
    }

    /// Sections the saved order doesn't list yet keep their default visibility.
    static func hidden(_ raw: String, order orderRaw: String) -> Set<HomeSection> {
        let known = parse(orderRaw)
        return Set(parse(raw)).union(allCases.filter { !known.contains($0) && !$0.isOnByDefault })
    }

    static func raw(_ sections: some Sequence<HomeSection>) -> String { sections.map(\.rawValue).joined(separator: ",") }
}

/// Everything narrowing the Recipes home: a category, quick filters and a total time range.
struct HomeFilter: Equatable {
    static let timeStep = 10
    static let timeLimit = 120

    var scope = RecipeCollection.all
    var quick: Set<QuickFilter> = []
    /// Tags turned on from quick filter chips; a recipe needs every one.
    var tags: Set<String> = []
    var query = ""
    /// `timeLimit` means no maximum.
    var maxMinutes = HomeFilter.timeLimit

    var limitsTime: Bool { maxMinutes < Self.timeLimit }
    /// Search text doesn't count: Reset and the Filters badge leave it alone.
    var isActive: Bool { self != HomeFilter(query: query) }

    func apply(_ recipes: [Recipe], style: RatingStyle) -> [Recipe] {
        scope.filter(recipes).filter { recipe in
            quick.allSatisfy { $0.matches(recipe, style) } && fitsTime(recipe) && recipe.matches(query)
                && tags.allSatisfy { tag in recipe.tags.contains { CategoryTree.tag($0, isIn: tag) } }
        }
    }

    func contains(_ chip: QuickChip) -> Bool {
        switch chip {
        case .filter(let filter): quick.contains(filter)
        case .tag(let path): tags.contains(path)
        }
    }

    mutating func toggle(_ chip: QuickChip) {
        switch chip {
        case .filter(let filter): if quick.contains(filter) { quick.remove(filter) } else { quick.insert(filter) }
        case .tag(let path): if tags.contains(path) { tags.remove(path) } else { tags.insert(path) }
        }
    }

    func fitsTime(_ recipe: Recipe) -> Bool {
        guard limitsTime else { return true }
        guard let minutes = recipe.totalMinutes else { return false }
        return minutes <= maxMinutes
    }

    var timeTitle: String { limitsTime ? "Up to \(Self.minutes(maxMinutes))" : "Any time" }

    static func minutes(_ value: Int) -> String {
        value >= 60 && value % 60 == 0 ? "\(value / 60) hr" : "\(value) min"
    }
}

/// What the Recipes home is narrowed and sorted by, shared by the Recipes and Search tabs.
@Observable
final class HomeBrowsing {
    var filter = HomeFilter()
    var chosenSort: RecipeSort?
    var shuffleSeed = Int.random(in: .min ... .max)
}

/// The top of the Recipes tab (and the Search tab, with its query): every recipe, narrowed and sorted from the navigation bar.
struct RecipesHomeView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.listStyle) private var style = RecipeListStyle.list
    @AppStorage(AppSettings.Key.homeSort) private var savedSort = RecipeSort.recent
    @AppStorage(AppSettings.Key.defaultSort) private var defaultSort = RecipeSort.recent
    @AppStorage(AppSettings.Key.remembersSort) private var remembersSort = true
    @AppStorage(AppSettings.Key.quickChips) private var quickChipsRaw = QuickChip.raw(QuickChip.defaults)
    @AppStorage(AppSettings.Key.homeSections) private var homeSectionsRaw = ""
    @AppStorage(AppSettings.Key.hiddenHomeSections) private var hiddenHomeSectionsRaw = ""
    @AppStorage(AppSettings.Key.homeTipDismissed) private var homeTipDismissed = false
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenTabsRaw = ""
    @AppStorage(AppSettings.Key.settingsInTabBar) private var settingsInTabBar = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.referenceDate) private var referenceDate
    @Environment(HomeBrowsing.self) private var browsing
    @Environment(\.openRecipesRoute) private var openRoute
    @Environment(\.appAccent) private var accent
    @Binding var selection: Recipe.ID?
    var query = ""
    var showsQuickFilters = false
    var isSearching = false
    /// Shows one tag's page with its own filters instead of the shared home.
    var tag: String?
    /// Lists every recipe instead of the home's first few.
    var showsAllRecipes = false
    var onScroll: (() -> Void)?

    private var filter: HomeFilter {
        get {
            var filter = tag == nil ? browsing.filter : tagFilter
            filter.query = query
            if let tag { filter.scope = .category(tag) }
            return filter
        }
        nonmutating set {
            var filter = newValue
            filter.query = ""
            if tag == nil { browsing.filter = filter } else { tagFilter = filter }
        }
    }
    @State private var tagFilter = HomeFilter()
    private var chosenSort: RecipeSort? {
        get { browsing.chosenSort }
        nonmutating set { browsing.chosenSort = newValue }
    }
    private var shuffleSeed: Int {
        get { browsing.shuffleSeed }
        nonmutating set { browsing.shuffleSeed = newValue }
    }
    @State private var choosingFilter = false
    @State private var pinnedWidth: CGFloat = 0
    /// A line of chip text, so icon-only chips are as tall as the labeled ones.
    @ScaledMetric(relativeTo: .body) private var chipLine: CGFloat = 22
    @State private var titleInBar = false
    @State private var tagShelfWidth: CGFloat = 0
    @State private var tagsExpanded = false
    @State private var tagPage: Int?
    @State private var editing: Recipe?
    @State private var showingSettings = false

    private var ratingStyle: RatingStyle { RatingStyle(rawValue: ratingStyleRaw) ?? .favorites }
    private var isRegular: Bool { sizeClass == .regular }
    private var margin: CGFloat { isRegular ? 28 : 20 }
    private var sort: RecipeSort { remembersSort ? savedSort : chosenSort ?? defaultSort }
    private var sortBinding: Binding<RecipeSort> {
        Binding(get: { sort }, set: choose)
    }

    private var items: [Recipe] { sort.sorted(filter.apply(library.recipes, style: ratingStyle), seed: shuffleSeed) }

    static let homeRecipeLimit = 5
    static let sectionGap: CGFloat = 36

    /// The home shows its first few recipes under a Recipes heading; searching, tag pages and View All show them all.
    private var isHome: Bool { tag == nil && !showsAllRecipes && !showsQuickFilters && query.isEmpty }

    private var sections: [HomeSection] {
        guard isHome else { return [.tags, .recipes] }
        let hidden = HomeSection.hidden(hiddenHomeSectionsRaw, order: homeSectionsRaw)
        return HomeSection.order(homeSectionsRaw).filter { !hidden.contains($0) }
    }

    private var todayPicks: [HeroPick] {
        let key = DayKey.string(from: referenceDate ?? Date())
        return library.mealPlan.filter { $0.day == key }.sorted { ($0.meal.order, $0.title) < ($1.meal.order, $1.title) }
            .map { entry in
                // A meal synced from Mealie or typed in may have no recipe here; show it by title.
                let recipe = entry.recipeID.flatMap(library.recipe(id:)) ?? Recipe(id: entry.recipeID ?? entry.id, title: entry.title)
                return HeroPick(recipe: recipe, kicker: entry.meal.title)
            }
    }

    private var favoritePicks: [HeroPick] {
        RecipeCollection.favorites.filter(library.recipes).prefix(5).map { HeroPick(recipe: $0, kicker: "Favorite") }
    }

    private var upNextPicks: [HeroPick] {
        RecipeCollection.wantToCook.filter(library.recipes).prefix(5).map { HeroPick(recipe: $0, kicker: "Up Next") }
    }

    private func picks(for section: HomeSection) -> [HeroPick] {
        switch section {
        case .today: todayPicks
        case .upNext: upNextPicks
        case .favorites: favoritePicks
        case .tags, .discover, .feeds, .recipes: []
        }
    }

    private var title: String {
        guard filter.scope == .all else { return filter.scope.title }
        if isHome { return "Home" }
        return showsAllRecipes ? "Recipes" : "My Recipes"
    }

    var body: some View {
        Group {
            if library.recipes.isEmpty, !(isHome && library.isLoaded) {
                EmptyLibraryView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isRegular {
                grid
            } else {
                list
            }
        }
        .themedCanvas()
        .navigationTitle(titleInBar ? title : "")
        .navigationSubtitle(titleInBar && !isHome ? Self.countText(items.count) : "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .recipeActions(selection: $selection, listStyle: nil, addsAtTrailing: isHome)
        .toolbar {
            #if os(iOS)
            if isHome, !isRegular, !settingsInTabBar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
            #endif
            if !library.recipes.isEmpty, !isHome {
                ToolbarItem(placement: .primaryAction) { sortMenu }
                if !isRegular {
                    ToolbarItem(placement: .primaryAction) { styleButton }
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            if showsQuickFilters, !library.recipes.isEmpty { quickFilterBar }
        }
        .sheet(isPresented: $choosingFilter) {
            HomeFilterSheet(filter: Binding(get: { filter }, set: { filter = $0 }), ratingStyle: ratingStyle)
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(item: $editing) { recipe in
            RecipeEditorView(recipe: recipe) { saved, image, steps in Task { await library.save(saved, image: image, steps: steps) } }
        }
    }

    private var list: some View {
        let all = items
        let items = isHome ? Array(all.prefix(Self.homeRecipeLimit)) : all
        return List(selection: $selection) {
            Section {
                header(count: all.count)
                    .listRowInsets(EdgeInsets(top: 8, leading: margin, bottom: 12, trailing: margin))
                    .listRowSeparator(.hidden)
                    .themedRow()
                if isHome, !homeTipDismissed {
                    customizeTip
                        .listRowInsets(EdgeInsets(top: 0, leading: margin, bottom: Self.sectionGap, trailing: margin))
                        .listRowSeparator(.hidden)
                        .themedRow()
                }
                ForEach(sections) { section in
                    listSection(section, items: items, total: all.count)
                }
            }
            .listSectionSeparator(.hidden)
        }
        // List keeps rows in their old places when whole sections reorder, so rebuild it.
        .id(sections)
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .onScrollPhaseChange { _, phase in if phase == .interacting { onScroll?() } }
        .refreshable { await refresh() }
        .animation(.snappy, value: items.map(\.id))
    }

    @ViewBuilder
    private func listSection(_ section: HomeSection, items: [Recipe], total: Int) -> some View {
        switch section {
        case .today, .upNext, .favorites:
            let picks = picks(for: section)
            if !picks.isEmpty {
                heroSection(section, picks: picks)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: Self.sectionGap, trailing: 0))
                    .listRowSeparator(.hidden)
                    .themedRow()
            } else if let empty = emptyCard(section) {
                empty
                    .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: Self.sectionGap, trailing: margin))
                    .listRowSeparator(.hidden)
                    .themedRow()
            }
        case .tags:
            if showsTags {
                tagsRow
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: Self.sectionGap, trailing: 0))
                    .listRowSeparator(.hidden)
                    .themedRow()
            }
        case .discover:
            if !discover.sources.isEmpty {
                discoverSection
                    .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: Self.sectionGap, trailing: margin))
                    .listRowSeparator(.hidden)
                    .themedRow()
            }
        case .feeds:
            if showsFeedShelf {
                feedsRow
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: Self.sectionGap, trailing: 0))
                    .listRowSeparator(.hidden)
                    .themedRow()
            } else if let empty = emptyCard(section) {
                empty
                    .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: Self.sectionGap, trailing: margin))
                    .listRowSeparator(.hidden)
                    .themedRow()
            }
        case .recipes:
            if let empty = emptyCard(section) {
                empty
                    .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: Self.sectionGap, trailing: margin))
                    .listRowSeparator(.hidden)
                    .themedRow()
            } else {
            if isHome {
                recipesHeader(count: total)
                    .listRowInsets(EdgeInsets(top: 4, leading: margin, bottom: 8, trailing: margin))
                    .listRowSeparator(.hidden)
                    .themedRow()
            }
                ForEach(items) { recipe in
                    Group {
                        switch style {
                        case .cards: RecipeCard(recipe: recipe)
                        case .list: RecipeRow(recipe: recipe)
                        }
                    }
                    .tag(recipe.id)
                    .themedRow()
                    .listRowSeparator(style == .cards || recipe.id == items.first?.id ? .hidden : .automatic, edges: .top)
                    .listRowSeparator(style == .cards ? .hidden : .automatic, edges: .bottom)
                    .listRowInsets(style == .cards ? EdgeInsets(top: 12, leading: margin, bottom: 20, trailing: margin) : EdgeInsets(top: 8, leading: margin, bottom: 8, trailing: margin))
                    .recipeSwipeActions(for: recipe)
                    .draggable(RecipeDragItem(id: recipe.id))
                    .contextMenu { recipeMenu(recipe) }
                }
                if items.isEmpty { noMatches.listRowSeparator(.hidden).themedRow() }
            }
        }
    }

    private var grid: some View {
        let all = items
        let items = isHome ? Array(all.prefix(Self.homeRecipeLimit)) : all
        return ScrollView {
            VStack(alignment: .leading, spacing: Self.sectionGap) {
                header(count: all.count).padding(.horizontal, margin)
                if isHome, !homeTipDismissed { customizeTip.padding(.horizontal, margin) }
                ForEach(sections) { section in
                    gridSection(section, items: items, total: all.count)
                }
            }
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.immediately)
        .onScrollPhaseChange { _, phase in if phase == .interacting { onScroll?() } }
        .refreshable { await refresh() }
        .animation(.snappy, value: items.map(\.id))
        .reviewPromptInset()
    }

    @ViewBuilder
    private func gridSection(_ section: HomeSection, items: [Recipe], total: Int) -> some View {
        switch section {
        case .today, .upNext, .favorites:
            let picks = picks(for: section)
            if !picks.isEmpty { heroSection(section, picks: picks) }
            else if let empty = emptyCard(section) { empty.padding(.horizontal, margin) }
        case .tags:
            if showsTags { tagsRow }
        case .discover:
            if !discover.sources.isEmpty { discoverSection.padding(.horizontal, margin) }
        case .feeds:
            if showsFeedShelf { feedsRow } else if let empty = emptyCard(section) { empty.padding(.horizontal, margin) }
        case .recipes:
            if let empty = emptyCard(section) { empty.padding(.horizontal, margin) } else {
            if isHome { recipesHeader(count: total).padding(.horizontal, margin) }
            GridSection(title: nil, minimum: 260, spacing: 24) {
                ForEach(items) { recipe in
                    Button { selection = recipe.id } label: { RecipeCard(recipe: recipe) }
                        .buttonStyle(.plain)
                        .draggable(RecipeDragItem(id: recipe.id))
                        .contextMenu { recipeMenu(recipe) }
                }
            }
            .padding(.horizontal, margin)
            if items.isEmpty { noMatches }
            }
        }
    }

    private var customizeTip: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "house")
                .appFont(.title3)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text("Make Home yours").appFont(.headline)
                    Spacer(minLength: 8)
                    Button {
                        withAnimation(.snappy) { homeTipDismissed = true }
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(.body, weight: .semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .padding(.vertical, -6)
                    .accessibilityLabel("Dismiss")
                }
                Text("Reorder sections or turn off the ones you don't use.")
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    homeTipDismissed = true
                    openRoute(.homeSettings)
                } label: {
                    HStack(spacing: 4) {
                        Text("Customize Home")
                        Image(systemName: "chevron.right").appFont(.caption, weight: .semibold)
                    }
                    .appFont(.subheadline, weight: .medium)
                    .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func heroSection(_ section: HomeSection, picks: [HeroPick]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                if section == .upNext {
                    Button { openRoute(.upNext) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            sectionTitle(section.title)
                            Image(systemName: "chevron.right").appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Up Next to reorder it")
                } else if section == .favorites {
                    sectionTitle(section.title)
                    Spacer()
                    sectionLink("View All") { openRoute(.collection(.favorites)) }
                        .accessibilityLabel("View All Favorites")
                } else {
                    sectionTitle(section.title)
                }
                Spacer()
                if section == .today { sectionLink("View Plan") { router.destination = .plan } }
            }
            .padding(.horizontal, margin)
            HeroCarousel(picks: picks, margin: margin) { id in
                if library.recipe(id: id) != nil { selection = id } else { router.destination = .plan }
            }
        }
    }


    private func shows(_ tab: MainTab) -> Bool { !AppSettings.hiddenTabs(hiddenTabsRaw).contains(tab) }

    /// What a Home section says when it has nothing to show yet, and where its tap leads.
    private func emptyCard(_ section: HomeSection) -> AnyView? {
        guard isHome else { return nil }
        switch section {
        case .today where shows(.plan):
            return AnyView(emptyCard(section, symbol: "calendar.badge.plus", heading: "Nothing planned for today",
                                     message: "Plan a meal, or create a plan for the whole week.") { router.destination = .plan })
        case .upNext where shows(.upNext):
            return AnyView(emptyCard(section, symbol: "text.line.first.and.arrowtriangle.forward", heading: "Line up what to cook",
                                     message: "Swipe a recipe left, or use its ⋯ menu, to add it to Up Next. Planning it takes it off.") { openRoute(.upNext) })
        case .favorites where !library.recipes.isEmpty:
            return AnyView(emptyCard(section, symbol: "heart", heading: "Keep your favorites close",
                                     message: "Long-press a recipe, or use its ⋯ menu, and choose Favorite.", action: nil))
        case .feeds where library.feeds.isEmpty:
            return AnyView(emptyCard(section, symbol: "dot.radiowaves.up.forward", heading: "Follow recipe sites",
                                     message: "Discover blogs, magazines and YouTube channels and see their newest recipes here.") { openRoute(.feeds) })
        case .recipes where library.recipes.isEmpty:
            return AnyView(emptyCard(section, symbol: "plus.circle", heading: "Add your first recipe",
                                     message: "Tap + to paste a link or scan a page, or share one from Safari or YouTube.", action: nil))
        default:
            return nil
        }
    }

    private func emptyCard(_ section: HomeSection, symbol: String, heading: String, message: String, action: (() -> Void)?) -> some View {
        let card = HStack(spacing: 12) {
            Image(systemName: symbol).appFont(.title2).foregroundStyle(accent).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(heading).appFont(.headline)
                Text(message).appFont(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if action != nil {
                Image(systemName: "chevron.right").appFont(.footnote, weight: .semibold).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(section.title)
            if let action {
                Button(action: action) { card }.buttonStyle(.plain)
            } else {
                card
            }
        }
    }

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(HomeSection.discover.title)
            DiscoverEntryTile(sources: discover.sources)
        }
    }

    private var tagNodes: [CategoryNode] {
        guard let tag else { return library.categoryTree }
        return CategoryTree.node(at: tag, in: library.categoryTree)?.children ?? []
    }

    /// Searching hides the tags unless one is already narrowing the results.
    private var showsTags: Bool {
        !tagNodes.isEmpty && (!showsQuickFilters || filter.scope != .all)
    }

    private var tagColumns: Int {
        max(1, Int((tagShelfWidth - 2 * margin + TagTile.spacing) / (TagTile.minWidth + TagTile.spacing)))
    }

    /// Tiles grow to fill the row, so each page spans the full width.
    private var tagWidth: CGFloat {
        let columns = CGFloat(tagColumns)
        return max(TagTile.minWidth, (tagShelfWidth - 2 * margin - (columns - 1) * TagTile.spacing) / columns)
    }

    private var tagRows: [[CategoryNode]] {
        let tree = tagNodes, columns = tagColumns
        return stride(from: 0, to: tree.count, by: columns).map { Array(tree[$0..<min($0 + columns, tree.count)]) }
    }

    /// Two rows a page once the tags overflow one row.
    private var tagPages: [[[CategoryNode]]] {
        let rows = tagRows
        return stride(from: 0, to: rows.count, by: 2).map { Array(rows[$0..<min($0 + 2, rows.count)]) }
    }

    private var tagsRow: some View {
        let pages = tagPages
        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                tagsTitle
                Spacer()
                if pages.count > 1 {
                    Button { toggleTags() } label: {
                        HStack(spacing: 4) {
                            Text(tagsExpanded ? "Show Less" : "Show All")
                            Image(systemName: "chevron.down")
                                .appFont(.caption, weight: .semibold)
                                .rotationEffect(.degrees(tagsExpanded ? 180 : 0))
                        }
                        .appFont(.subheadline, weight: .medium)
                        .foregroundStyle(.tint)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(tagsExpanded ? "Show Fewer Tags" : "Show All Tags")
                }
            }
            .padding(.horizontal, margin)
            if tagsExpanded {
                tagGrid(tagRows)
                    .padding(.horizontal, margin)
                    .transition(.opacity)
            } else {
                VStack(spacing: 14) {
                    tagPager(pages)
                    if pages.count > 1 { TagPageDots(count: pages.count, current: tagPage ?? 0) }
                }
                .transition(.opacity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tagShelfWidth = $0 }
        .clipped()
    }

    private func tagPager(_ pages: [[[CategoryNode]]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: TagTile.spacing) {
                ForEach(pages.indices, id: \.self) { index in
                    tagGrid(pages[index])
                        .frame(width: max(tagShelfWidth - 2 * margin, 0), alignment: .topLeading)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $tagPage)
        .scrollDisabled(pages.count < 2)
        .scrollClipDisabled()
    }

    private func tagGrid(_ rows: [[CategoryNode]]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(rows, id: \.first?.id) { row in
                HStack(alignment: .top, spacing: TagTile.spacing) {
                    ForEach(row) { tagTile($0) }
                }
            }
        }
    }

    /// Expanding starts from the first page, so its rows stay put while the rest open beneath them.
    private func toggleTags() {
        if tagsExpanded {
            withAnimation(.smooth(duration: 0.4)) { tagsExpanded = false }
            tagPage = 0
        } else {
            tagPage = 0
            withAnimation(.smooth(duration: 0.4)) { tagsExpanded = true }
        }
    }

    private var showsFeedShelf: Bool { isHome && !library.feeds.isEmpty }

    private var feedsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(HomeSection.feeds.title)
                Spacer()
                Button { openRoute(.feeds) } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                        Image(systemName: "chevron.right").appFont(.caption, weight: .semibold)
                    }
                    .appFont(.subheadline, weight: .medium)
                    .foregroundStyle(.tint)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("View All Feeds")
            }
            .padding(.horizontal, margin)
            FeedShelf(margin: margin, cardWidth: isRegular ? 300 : 260)
        }
    }

    private var tagsTitle: some View {
        sectionTitle("Tags")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).appFont(.title3, weight: .semibold).foregroundStyle(.primary).accessibilityAddTraits(.isHeader)
    }

    private func recipesHeader(count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            sectionTitle("Recipes")
            Spacer()
            if count > Self.homeRecipeLimit {
                sectionLink("View All") { openRoute(.allRecipes) }
                    .accessibilityLabel("View All Recipes")
            }
        }
    }

    private func sectionLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "chevron.right").appFont(.caption, weight: .semibold)
            }
            .appFont(.subheadline, weight: .medium)
            .foregroundStyle(.tint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func countLabel(_ count: Int) -> some View {
        Text(Self.countText(count))
            .appFont(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private func tagTile(_ node: CategoryNode) -> some View {
        let collection = RecipeCollection.category(node.path)
        return TagTile(title: node.name, collection: collection, symbol: node.children.isEmpty ? "tag" : "folder",
                       count: count(in: collection), isOn: isWithin(node), width: tagWidth, route: .tag(node.path))
    }

    private func isWithin(_ node: CategoryNode) -> Bool {
        guard case .category(let path) = filter.scope else { return false }
        return CategoryTree.tag(path, isIn: node.path)
    }

    private func count(in collection: RecipeCollection) -> Int {
        var narrowed = filter
        narrowed.scope = collection
        return narrowed.apply(library.recipes, style: ratingStyle).count
    }

    /// Chosen filters shrink to icons pinned at the leading edge; the rest scroll under them and fade out.
    private var quickFilterBar: some View {
        let shown = QuickChip.parse(quickChipsRaw)
        let extra = filter.quick.map(QuickChip.filter).sorted { $0.token < $1.token } + filter.tags.sorted().map(QuickChip.tag)
        let chosen = (shown + extra.filter { !shown.contains($0) }).filter { filter.contains($0) }
        let others = shown.filter { !filter.contains($0) }
        let inset = margin + pinnedWidth + 8
        return ZStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(others, id: \.self) { quick in
                            Button { filter.toggle(quick) } label: {
                                Label(quick.title(ratingStyle), systemImage: quick.symbol(ratingStyle))
                            }
                            .glassButton(isOn: false)
                        }
                    }
                }
            }
            .contentMargins(.leading, inset, for: .scrollContent)
            .contentMargins(.trailing, margin, for: .scrollContent)
            .scrollClipDisabled()
            .mask {
                HStack(spacing: 0) {
                    Color.clear.frame(width: max(inset - 20, 0))
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 20)
                    Color.black
                }
                .padding(.vertical, -20)
            }
            Group {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button { choosingFilter = true } label: {
                            Label("Filters", systemImage: "line.3.horizontal.decrease")
                                .labelStyle(.iconOnly)
                                .frame(width: chipLine, height: chipLine)
                        }
                        .glassButton(isOn: filter.limitsTime || filter.scope != .all)
                        .buttonBorderShape(.circle)
                        .tint(filter.limitsTime || filter.scope != .all ? accent : nil)
                        ForEach(chosen, id: \.self) { quick in
                            Button { filter.toggle(quick) } label: {
                                Label(quick.title(ratingStyle), systemImage: quick.symbol(ratingStyle))
                                    .labelStyle(.iconOnly)
                                    .frame(width: chipLine, height: chipLine)
                            }
                            .glassButton(isOn: true)
                            .buttonBorderShape(.circle)
                            .tint(accent)
                            .accessibilityAddTraits(.isSelected)
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pinnedWidth = $0 }
                .padding(.leading, margin)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 6)
        // The open search field floats over the bottom safe area instead of shrinking it.
        .padding(.bottom, isSearching ? 70 : 6)
        .animation(.snappy, value: filter)
        .animation(.snappy, value: isSearching)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: sortBinding) {
                ForEach(RecipeSort.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            if sort == .shuffle {
                Button("Shuffle Again", systemImage: "arrow.trianglehead.2.clockwise") { choose(.shuffle) }
            }
        } label: {
            Label("Sort", systemImage: sort.symbol)
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityValue(sort.title)
    }

    private var styleButton: some View {
        let other: RecipeListStyle = style == .cards ? .list : .cards
        return Button { withAnimation(.snappy) { style = other } } label: {
            Label("Show \(other.title)", systemImage: other.symbol)
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    static func countText(_ count: Int) -> String { count == 1 ? "1 recipe" : "\(count) recipes" }

    /// The page title sits here; once it scrolls under the bar, the bar shows it instead.
    private func header(count: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(.largeTitle, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                if !isHome { countLabel(count) }
            }
            Spacer(minLength: 0)
        }
        .onGeometryChange(for: Bool.self) { $0.frame(in: .scrollView).midY < 0 } action: { hidden in
            withAnimation(.easeInOut(duration: 0.2)) { titleInBar = hidden }
        }
    }

    @ViewBuilder
    private var noMatches: some View {
        if !filter.isActive, !query.isEmpty {
            ContentUnavailableView.search(text: query).frame(maxWidth: .infinity)
        } else {
            filteredOut
        }
    }

    private var filteredOut: some View {
        ContentUnavailableView {
            Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("No recipes match these filters.")
        } actions: {
            Button("Clear Filters") { filter = HomeFilter() }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func recipeMenu(_ recipe: Recipe) -> some View {
        RecipeQuickActions(recipe: recipe)
        Button("Edit", systemImage: "pencil") { editing = recipe }
    }

    private func refresh() async {
        await library.reload()
        if sort == .shuffle { withAnimation(.snappy) { shuffleSeed = .random(in: .min ... .max) } }
    }

    private func choose(_ newSort: RecipeSort) {
        if newSort == .shuffle { shuffleSeed = .random(in: .min ... .max) }
        if remembersSort { savedSort = newSort } else { chosenSort = newSort }
    }

}

private extension View {
    @ViewBuilder
    func glassButton(isOn: Bool) -> some View {
        if isOn { buttonStyle(.glassProminent) } else { buttonStyle(.glass).foregroundStyle(.primary) }
    }
}

struct HeroPick: Identifiable {
    let recipe: Recipe
    let kicker: String

    var id: String { "\(kicker)-\(recipe.id)" }
}

/// The Today section: large photo cards a page at a time, with dots when there's more than one.
private struct HeroCarousel: View {
    let picks: [HeroPick]
    let margin: CGFloat
    let open: (Recipe.ID) -> Void
    @State private var page: Int?
    @State private var width: CGFloat = 0

    var body: some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TagTile.spacing) {
                    ForEach(picks.indices, id: \.self) { index in
                        Button { open(picks[index].recipe.id) } label: { HeroCard(pick: picks[index]) }
                            .buttonStyle(.plain)
                            .frame(width: max(width - 2 * margin, 0))
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $page)
            .scrollDisabled(picks.count < 2)
            .scrollClipDisabled()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            if picks.count > 1 { TagPageDots(count: picks.count, current: page ?? 0) }
        }
    }
}

private struct HeroCard: View {
    let pick: HeroPick

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { RecipeImageView(recipe: pick.recipe) }
            .overlay {
                LinearGradient(colors: [.clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pick.kicker.uppercased())
                        .appFont(.caption, weight: .bold)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(pick.recipe.title)
                        .appFont(.title2, weight: .bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let minutes = pick.recipe.totalMinutes {
                        Label(HomeFilter.minutes(minutes), systemImage: "clock")
                            .appFont(.subheadline, weight: .medium)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }
}

private struct TagPageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// A tag as a photo tile, from the newest recipe in it that has one, badged with how many recipes choosing it shows.
private struct TagTile: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    @Environment(\.openRecipesRoute) private var openRoute
    let title: String
    let collection: RecipeCollection
    let symbol: String
    let count: Int
    var isOn = false
    var width: CGFloat = 76
    var route: RecipesRoute?
    var action: () -> Void = {}

    static let minWidth: CGFloat = 84
    static let spacing: CGFloat = 16

    private var cover: Recipe? {
        collection.filter(library.recipes)
            .sorted { $0.createdAt > $1.createdAt }
            .first { library.hasImage($0.id) }
    }

    var body: some View {
        Button { if let route { openRoute(route) } else { action() } } label: { label }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count == 1 ? "1 recipe" : "\(count) recipes")")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var label: some View {
        VStack(spacing: 4) {
            Group {
                if let cover {
                    RecipeImageView(recipe: cover)
                } else {
                    Image(systemName: symbol)
                        .appFont(.title2)
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .frame(width: width - 8, height: width - 8)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isOn ? accent : .clear, lineWidth: 3)
            }
            .overlay(alignment: .topTrailing) {
                if count > 0 { badge.padding(6) }
            }
            .padding(.bottom, 2)
            Text(title)
                .appFont(.footnote, weight: isOn ? .semibold : .regular)
                .foregroundStyle(isOn ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: width)
        .opacity(count == 0 && !isOn ? 0.45 : 1)
    }

    private var badge: some View {
        Text(count, format: .number)
            .appFont(.caption, weight: .bold)
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 22)
            .background(accent, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}

/// Every way to narrow the home, applied as it changes, with the count of what's left.
private struct HomeFilterSheet: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: HomeFilter
    let ratingStyle: RatingStyle

    private var remaining: Int { filter.apply(library.recipes, style: ratingStyle).count }

    var body: some View {
        NavigationStack {
            Form {
                if !library.categoryTree.isEmpty {
                    Section("Tags") {
                        ForEach(tagLevels.indices, id: \.self) { level in
                            tagRow(tagLevels[level], showsUncategorized: level == 0)
                                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        }
                    }
                }
                Section {
                    TimeHistogram(recipes: timeCandidates, filter: filter)
                        .frame(height: 72)
                        .listRowSeparator(.hidden)
                    Slider(value: maxMinutes, in: Double(HomeFilter.timeStep)...Double(HomeFilter.timeLimit), step: Double(HomeFilter.timeStep)) {
                        Text("Maximum time")
                    } minimumValueLabel: {
                        Text(HomeFilter.minutes(HomeFilter.timeStep)).appFont(.caption).foregroundStyle(.secondary)
                    } maximumValueLabel: {
                        Text("Any").appFont(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityValue(filter.timeTitle)
                } header: {
                    HStack {
                        Text("Total time")
                        Spacer()
                        Text(filter.timeTitle).foregroundStyle(filter.limitsTime ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                }
                Section("Show only") {
                    ForEach(QuickFilter.allCases, id: \.self) { quick in
                        Toggle(isOn: Binding(
                            get: { filter.quick.contains(quick) },
                            set: { if $0 { filter.quick.insert(quick) } else { filter.quick.remove(quick) } }
                        )) {
                            Label(quick.title(ratingStyle), systemImage: quick.symbol(ratingStyle))
                        }
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                Button { dismiss() } label: {
                    Text(remaining == 0 ? "No Recipes Match" : remaining == 1 ? "Show 1 Recipe" : "Show \(remaining) Recipes")
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .disabled(remaining == 0)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("Filters")
            .navigationSubtitle("\(remaining) of \(library.recipes.count) recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") { withAnimation(.snappy) { filter = HomeFilter(query: filter.query) } }
                        .disabled(!filter.isActive)
                }
            }
            .animation(.snappy, value: remaining)
        }
    }

    private var maxMinutes: Binding<Double> {
        Binding(get: { Double(filter.maxMinutes) }, set: { filter.maxMinutes = Int($0) })
    }

    /// The top-level tags, then the subtags of each chosen one.
    private var tagLevels: [[CategoryNode]] {
        var levels = [library.categoryTree]
        while let chosen = levels.last?.first(where: { isOn($0) }), !chosen.children.isEmpty {
            levels.append(chosen.children)
        }
        return levels
    }

    private func isOn(_ node: CategoryNode) -> Bool {
        guard case .category(let path) = filter.scope else { return false }
        return CategoryTree.tag(path, isIn: node.path)
    }

    private func tagRow(_ nodes: [CategoryNode], showsUncategorized: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(nodes) { node in
                    let collection = RecipeCollection.category(node.path)
                    TagTile(title: node.name, collection: collection, symbol: node.children.isEmpty ? "tag" : "folder",
                            count: count(in: collection), isOn: isOn(node)) {
                        withAnimation(.snappy) { filter.scope = filter.scope == collection ? parent(of: node) : collection }
                    }
                }
                if showsUncategorized, !RecipeCollection.uncategorized.filter(library.recipes).isEmpty {
                    TagTile(title: RecipeCollection.uncategorized.title, collection: .uncategorized, symbol: RecipeCollection.uncategorized.symbol,
                            count: count(in: .uncategorized), isOn: filter.scope == .uncategorized) {
                        withAnimation(.snappy) { filter.scope = filter.scope == .uncategorized ? .all : .uncategorized }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func parent(of node: CategoryNode) -> RecipeCollection {
        let parts = CategoryTree.components(node.path)
        return parts.count > 1 ? .category(parts.dropLast().joined(separator: "/")) : .all
    }

    private func count(in collection: RecipeCollection) -> Int {
        var narrowed = filter
        narrowed.scope = collection
        return narrowed.apply(library.recipes, style: ratingStyle).count
    }

    /// The recipes the other filters leave, so the histogram shows what the time limit would choose from.
    private var timeCandidates: [Recipe] {
        var others = filter
        others.maxMinutes = HomeFilter.timeLimit
        return others.apply(library.recipes, style: ratingStyle)
    }
}

/// How many recipes take each stretch of time, with the time limit's share in the accent color.
private struct TimeHistogram: View {
    @Environment(\.appAccent) private var accent
    let recipes: [Recipe]
    let filter: HomeFilter

    private static let binCount = HomeFilter.timeLimit / HomeFilter.timeStep + 1

    private var bins: [Int] {
        var bins = Array(repeating: 0, count: Self.binCount)
        for minutes in recipes.compactMap(\.totalMinutes) { bins[min(minutes / HomeFilter.timeStep, Self.binCount - 1)] += 1 }
        return bins
    }

    var body: some View {
        let bins = bins
        let tallest = max(bins.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(bins.indices, id: \.self) { index in
                let start = index * HomeFilter.timeStep
                let inRange = !filter.limitsTime || start < filter.maxMinutes
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(inRange ? accent : accent.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(4, 72 * CGFloat(bins[index]) / CGFloat(tallest)))
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 14)
        .animation(.snappy, value: filter)
        .accessibilityHidden(true)
    }
}

#endif
