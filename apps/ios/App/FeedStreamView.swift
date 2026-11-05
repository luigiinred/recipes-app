import RecipeKit
import SwiftUI

struct PopularFeed: Identifiable {
    enum Kind: String, CaseIterable {
        case publications = "Magazines & Newspapers"
        case weeknight = "Weeknight & Family"
        case baking = "Baking & Desserts"
        case vegetarian = "Vegetarian & Vegan"
        case healthy = "Healthy & Low-Carb"
        case asian = "Asian & Indian"
        case latin = "Latin American"
        case mediterranean = "Mediterranean & Middle Eastern"
        case grilling = "Grilling & BBQ"
        case reddit = "Reddit"
    }

    let name: String
    let detail: String
    let url: String
    let kind: Kind
    var id: String { url }

    /// Feeds that load with images. Some blogs block non-browser imports, so their posts may only open in the browser.
    static let all: [PopularFeed] = [
        PopularFeed(name: "Bon Appétit", detail: "Recipes", url: "https://www.bonappetit.com/feed/recipes-rss-feed/rss", kind: .publications),
        PopularFeed(name: "Epicurious", detail: "Recipes and cooking", url: "https://www.epicurious.com/feed/rss", kind: .publications),
        PopularFeed(name: "BBC Good Food", detail: "Recipes and guides", url: "https://www.bbcgoodfood.com/rss", kind: .publications),
        PopularFeed(name: "Delish", detail: "Recipes and food news", url: "https://www.delish.com/rss/all.xml/", kind: .publications),
        PopularFeed(name: "Taste of Home", detail: "Home-style recipes", url: "https://www.tasteofhome.com/feed/", kind: .publications),
        PopularFeed(name: "The Guardian", detail: "Food", url: "https://www.theguardian.com/food/rss", kind: .publications),
        PopularFeed(name: "Saveur", detail: "Recipes and food culture", url: "https://www.saveur.com/feed/", kind: .publications),
        PopularFeed(name: "Tasting Table", detail: "Recipes and cooking tips", url: "https://www.tastingtable.com/feed/", kind: .publications),
        PopularFeed(name: "olive", detail: "BBC olive magazine", url: "https://www.olivemagazine.com/feed/", kind: .publications),
        PopularFeed(name: "RecipeTin Eats", detail: "Nagi Maehashi", url: "https://www.recipetineats.com/feed/", kind: .weeknight),
        PopularFeed(name: "Pinch of Yum", detail: "Lindsay Ostrom", url: "https://pinchofyum.com/feed", kind: .weeknight),
        PopularFeed(name: "Once Upon a Chef", detail: "Jennifer Segal", url: "https://www.onceuponachef.com/feed", kind: .weeknight),
        PopularFeed(name: "Half Baked Harvest", detail: "Tieghan Gerard", url: "https://www.halfbakedharvest.com/feed/", kind: .weeknight),
        PopularFeed(name: "Spend With Pennies", detail: "Budget comfort food", url: "https://www.spendwithpennies.com/feed/", kind: .weeknight),
        PopularFeed(name: "Cafe Delites", detail: "Karina Carrington", url: "https://cafedelites.com/feed/", kind: .weeknight),
        PopularFeed(name: "Tastes Better From Scratch", detail: "Lauren Allen", url: "https://tastesbetterfromscratch.com/feed/", kind: .weeknight),
        PopularFeed(name: "The Recipe Critic", detail: "Alyssa Rivers", url: "https://therecipecritic.com/feed/", kind: .weeknight),
        PopularFeed(name: "Jo Cooks", detail: "Jo Bourne", url: "https://www.jocooks.com/feed/", kind: .weeknight),
        PopularFeed(name: "Mel's Kitchen Cafe", detail: "Family dinners", url: "https://www.melskitchencafe.com/feed/", kind: .weeknight),
        PopularFeed(name: "Dinner at the Zoo", detail: "Easy family meals", url: "https://www.dinneratthezoo.com/feed/", kind: .weeknight),
        PopularFeed(name: "Dinner, then Dessert", detail: "Copycat and comfort food", url: "https://dinnerthendessert.com/feed/", kind: .weeknight),
        PopularFeed(name: "Iowa Girl Eats", detail: "Kristin Porter", url: "https://iowagirleats.com/feed/", kind: .weeknight),
        PopularFeed(name: "Nicky's Kitchen Sanctuary", detail: "British family cooking", url: "https://www.kitchensanctuary.com/feed/", kind: .weeknight),
        PopularFeed(name: "foodiecrush", detail: "Heidi Larsen", url: "https://www.foodiecrush.com/feed/", kind: .weeknight),
        PopularFeed(name: "Two Peas & Their Pod", detail: "Maria Lichty", url: "https://www.twopeasandtheirpod.com/feed/", kind: .weeknight),
        PopularFeed(name: "Bowl of Delicious", detail: "Quick weeknight meals", url: "https://www.bowlofdelicious.com/feed/", kind: .weeknight),
        PopularFeed(name: "Kevin Is Cooking", detail: "Kevin Lynch", url: "https://www.keviniscooking.com/feed/", kind: .weeknight),
        PopularFeed(name: "Platings + Pairings", detail: "Dinners and drinks", url: "https://www.platingsandpairings.com/feed/", kind: .weeknight),
        PopularFeed(name: "King Arthur Baking", detail: "Baking blog", url: "https://www.kingarthurbaking.com/blog/feed", kind: .baking),
        PopularFeed(name: "Handle the Heat", detail: "Tessa Arias", url: "https://handletheheat.com/feed/", kind: .baking),
        PopularFeed(name: "Broma Bakery", detail: "Sarah Fennel", url: "https://bromabakery.com/feed", kind: .baking),
        PopularFeed(name: "Joy the Baker", detail: "Joy Wilson", url: "https://joythebaker.com/feed/", kind: .baking),
        PopularFeed(name: "Baker by Nature", detail: "Ashley Manila", url: "https://www.bakerbynature.com/feed/", kind: .baking),
        PopularFeed(name: "Live Well Bake Often", detail: "Lindsay Grimes", url: "https://www.livewellbakeoften.com/feed/", kind: .baking),
        PopularFeed(name: "Love and Olive Oil", detail: "Lindsay and Taylor", url: "https://www.loveandoliveoil.com/feed", kind: .baking),
        PopularFeed(name: "David Lebovitz", detail: "Desserts from Paris", url: "https://www.davidlebovitz.com/feed/", kind: .baking),
        PopularFeed(name: "Love and Lemons", detail: "Vegetarian", url: "https://www.loveandlemons.com/feed/", kind: .vegetarian),
        PopularFeed(name: "Minimalist Baker", detail: "Simple plant-based", url: "https://minimalistbaker.com/feed/", kind: .vegetarian),
        PopularFeed(name: "Rainbow Plant Life", detail: "Nisha Vora", url: "https://rainbowplantlife.com/feed/", kind: .vegetarian),
        PopularFeed(name: "Oh She Glows", detail: "Angela Liddon", url: "https://ohsheglows.com/feed/", kind: .vegetarian),
        PopularFeed(name: "Vegan Richa", detail: "Richa Hingle", url: "https://www.veganricha.com/feed/", kind: .vegetarian),
        PopularFeed(name: "Nora Cooks", detail: "Vegan comfort food", url: "https://www.noracooks.com/feed/", kind: .vegetarian),
        PopularFeed(name: "Connoisseurus Veg", detail: "Alissa Saenz", url: "https://www.connoisseurusveg.com/feed/", kind: .vegetarian),
        PopularFeed(name: "101 Cookbooks", detail: "Heidi Swanson", url: "https://www.101cookbooks.com/feed", kind: .vegetarian),
        PopularFeed(name: "Skinnytaste", detail: "Lighter recipes", url: "https://www.skinnytaste.com/feed/", kind: .healthy),
        PopularFeed(name: "Well Plated", detail: "Erin Clarke", url: "https://www.wellplated.com/feed/", kind: .healthy),
        PopularFeed(name: "Ambitious Kitchen", detail: "Monique Volz", url: "https://www.ambitiouskitchen.com/feed/", kind: .healthy),
        PopularFeed(name: "Eating Bird Food", detail: "Brittany Mullins", url: "https://www.eatingbirdfood.com/feed/", kind: .healthy),
        PopularFeed(name: "Fit Foodie Finds", detail: "Lee Funke", url: "https://fitfoodiefinds.com/feed/", kind: .healthy),
        PopularFeed(name: "Wholesome Yum", detail: "Low-carb and keto", url: "https://www.wholesomeyum.com/feed/", kind: .healthy),
        PopularFeed(name: "Low Carb Yum", detail: "Keto recipes", url: "https://www.lowcarbyum.com/feed/", kind: .healthy),
        PopularFeed(name: "Thinlicious", detail: "Low-carb family meals", url: "https://www.ditchthecarbs.com/feed/", kind: .healthy),
        PopularFeed(name: "Just One Cookbook", detail: "Japanese home cooking", url: "https://www.justonecookbook.com/feed/", kind: .asian),
        PopularFeed(name: "The Woks of Life", detail: "Chinese home cooking", url: "https://thewoksoflife.com/feed/", kind: .asian),
        PopularFeed(name: "Red House Spice", detail: "Sichuan and Chinese", url: "https://redhousespice.com/feed/", kind: .asian),
        PopularFeed(name: "Hot Thai Kitchen", detail: "Pailin Chongchitnant", url: "https://hot-thai-kitchen.com/feed/", kind: .asian),
        PopularFeed(name: "Rasa Malaysia", detail: "Asian weeknight dishes", url: "https://rasamalaysia.com/feed/", kind: .asian),
        PopularFeed(name: "Hebbar's Kitchen", detail: "Indian vegetarian", url: "https://hebbarskitchen.com/feed/", kind: .asian),
        PopularFeed(name: "Tea for Turmeric", detail: "Pakistani and Indian", url: "https://www.teaforturmeric.com/feed/", kind: .asian),
        PopularFeed(name: "Isabel Eats", detail: "Mexican home cooking", url: "https://www.isabeleats.com/feed/", kind: .latin),
        PopularFeed(name: "Muy Bueno", detail: "Mexican family recipes", url: "https://muybuenoblog.com/feed/", kind: .latin),
        PopularFeed(name: "Dominican Cooking", detail: "Dominican recipes", url: "https://www.dominicancooking.com/feed", kind: .latin),
        PopularFeed(name: "The Mediterranean Dish", detail: "Suzy Karadsheh", url: "https://www.themediterraneandish.com/feed/", kind: .mediterranean),
        PopularFeed(name: "Feel Good Foodie", detail: "Yumna Jawad", url: "https://feelgoodfoodie.net/feed/", kind: .mediterranean),
        PopularFeed(name: "Cleobuttera", detail: "Egyptian and Middle Eastern", url: "https://cleobuttera.com/feed/", kind: .mediterranean),
        PopularFeed(name: "Hey Grill, Hey", detail: "Susie Bulloch", url: "https://heygrillhey.com/feed/", kind: .grilling),
        PopularFeed(name: "Girls Can Grill", detail: "Christie Vanover", url: "https://girlscangrill.com/feed/", kind: .grilling),
        PopularFeed(name: "Vindulge", detail: "Smoking and wine pairing", url: "https://www.vindulge.com/feed/", kind: .grilling),
        PopularFeed(name: "r/recipes", detail: "Recipes shared on Reddit", url: "https://www.reddit.com/r/recipes/.rss", kind: .reddit),
        PopularFeed(name: "r/Cooking", detail: "Home cooking questions and wins", url: "https://www.reddit.com/r/Cooking/.rss", kind: .reddit),
        PopularFeed(name: "r/EatCheapAndHealthy", detail: "Budget-friendly healthy eating", url: "https://www.reddit.com/r/EatCheapAndHealthy/.rss", kind: .reddit),
        PopularFeed(name: "r/MealPrepSunday", detail: "Cooking for the week ahead", url: "https://www.reddit.com/r/MealPrepSunday/.rss", kind: .reddit),
        PopularFeed(name: "r/Baking", detail: "Bakes and how they turned out", url: "https://www.reddit.com/r/Baking/.rss", kind: .reddit),
        PopularFeed(name: "r/slowcooking", detail: "Slow cooker recipes", url: "https://www.reddit.com/r/slowcooking/.rss", kind: .reddit),
        PopularFeed(name: "r/veganrecipes", detail: "Plant-based recipes", url: "https://www.reddit.com/r/veganrecipes/.rss", kind: .reddit),
        PopularFeed(name: "r/AsianEats", detail: "Asian home cooking", url: "https://www.reddit.com/r/AsianEats/.rss", kind: .reddit),
    ]
}

struct FeedStreamItem: Identifiable {
    let entry: FeedEntry
    let source: String
    var id: String { entry.id }
}

struct FeedStreamTab: View {
    var body: some View {
        NavigationStack { FeedStreamView() }
    }
}

enum FeedLayout: String, CaseIterable {
    case stream, swipe, grouped

    var title: String {
        switch self {
        case .stream: "All Posts"
        case .swipe: "One at a Time"
        case .grouped: "By Feed"
        }
    }

    var symbol: String {
        switch self {
        case .stream: "list.bullet"
        case .swipe: "rectangle.portrait.on.rectangle.portrait"
        case .grouped: "rectangle.split.1x2"
        }
    }
}

/// Followed posts merged newest first, one at a time, or each feed as its own row, with Discover a tap away.
struct FeedStreamView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    @Environment(\.appAccent) private var accent
    @AppStorage(AppSettings.Key.feedLayout) private var layout = FeedLayout.stream

    var body: some View {
        content
            .themedCanvas()
            .navigationTitle("Feeds")
            .toolbar {
                if layout == .swipe {
                    ToolbarItem(placement: .navigation) {
                        NavigationLink { FeedDiscoverPage() } label: { Label("Discover", systemImage: "sparkle.magnifyingglass") }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("View", selection: $layout) {
                            ForEach(FeedLayout.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                        }
                    } label: {
                        Label("View", systemImage: layout.symbol)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    // Destination links, so this page works inside any stack, including Home's typed path.
                    NavigationLink { RecipeFeedsPage() } label: { Label("Manage Feeds", systemImage: "slider.horizontal.3") }
                }
            }
            .refreshable {
                await withTaskGroup(of: Void.self) { group in
                    for feed in library.feeds { group.addTask { await loader.load(feed, force: true) } }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if layout == .swipe, !library.feeds.isEmpty {
            FeedSwipeStream()
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 36) {
                discoverLink
                if library.feeds.isEmpty {
                    Text("Follow recipe sites, blogs and YouTube channels from Discover and their newest posts show up here.")
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                } else {
                    Text("Following")
                        .appFont(.title2, weight: .bold)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal)
                        .padding(.bottom, -20)
                    if layout == .grouped {
                        ForEach(library.feeds) { FeedRow(url: $0.url, title: $0.title) }
                    } else {
                        FeedStream().padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var discoverLink: some View {
        NavigationLink { FeedDiscoverPage() } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkle.magnifyingglass").appFont(.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Discover").appFont(.headline)
                    Text("Popular recipe sites by kind of cooking").appFont(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").appFont(.footnote, weight: .semibold).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

/// Popular feeds a kind of cooking at a time: tap a tab or swipe between them.
struct FeedDiscoverPage: View {
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var kind = PopularFeed.Kind.allCases[0]

    var body: some View {
        pages
            .safeAreaBar(edge: .top) { tabs }
            .themedCanvas()
            .navigationTitle("Discover")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    @ViewBuilder
    private var pages: some View {
        #if os(iOS)
        TabView(selection: $kind) {
            ForEach(PopularFeed.Kind.allCases, id: \.self) { kind in
                page(kind).tag(kind)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        page(kind).id(kind)
        #endif
    }

    private func page(_ kind: PopularFeed.Kind) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 36) {
                ForEach(PopularFeed.all.filter { $0.kind == kind }) { FeedRow(url: $0.url, title: $0.name, detail: $0.detail) }
            }
            .padding(.vertical)
        }
    }

    private var tabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PopularFeed.Kind.allCases, id: \.self) { kind in
                        tab(kind).id(kind)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onChange(of: kind) { _, kind in withAnimation(.snappy) { proxy.scrollTo(kind, anchor: .center) } }
        }
    }

    private func tab(_ kind: PopularFeed.Kind) -> some View {
        let isOn = self.kind == kind
        return Button { withAnimation(.snappy) { self.kind = kind } } label: {
            Text(kind.rawValue)
                .appFont(.subheadline, weight: .medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? accent : accent.opacity(colorScheme == .dark ? 0.24 : 0.12), in: Capsule())
                .foregroundStyle(isOn ? .white : accent.mix(with: colorScheme == .dark ? .white : .black, by: 0.35))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Every followed feed's posts in one grid, newest first, paging in older posts at the end.
private struct FeedStream: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader

    var body: some View {
        let items = loader.items(for: library.feeds)
        GridSection(title: nil, minimum: 300, spacing: 20) {
            ForEach(items) { item in
                NavigationLink { FeedEntryPreview(entry: item.entry) } label: {
                    FeedCard(entry: item.entry, source: item.source)
                }
                .buttonStyle(.plain)
            }
            if items.isEmpty ? loader.isLoading(library.feeds) : loader.hasMore(library.feeds) {
                ForEach(0..<2, id: \.self) { FeedCard(entry: .placeholder($0), source: "Recipe site").loadingPlaceholder() }
                    .onAppear {
                        guard !items.isEmpty else { return }
                        Task { await loader.loadMore(library.feeds) }
                    }
                    .id(items.count)
            } else if items.isEmpty {
                Text("No posts yet.").appFont(.subheadline).foregroundStyle(.secondary)
            }
        }
        .task(id: library.feeds.map(\.id)) { await loader.loadAll(library.feeds) }
    }
}

/// Followed posts newest first, a full page each, swiped up and down; tap one to open it.
private struct FeedSwipeStream: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader

    var body: some View {
        let items = loader.items(for: library.feeds)
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    NavigationLink { FeedEntryPreview(entry: item.entry) } label: { FeedSwipePage(item: item) }
                        .buttonStyle(.plain)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .onAppear {
                            guard items.suffix(3).contains(where: { $0.id == item.id }), loader.hasMore(library.feeds) else { return }
                            Task { await loader.loadMore(library.feeds) }
                        }
                }
                if items.isEmpty {
                    Group {
                        if loader.isLoading(library.feeds) {
                            FeedSwipePage(item: FeedStreamItem(entry: .placeholder(0), source: "Recipe site")).loadingPlaceholder()
                        } else {
                            ContentUnavailableView("No Posts Yet", systemImage: "dot.radiowaves.up.forward",
                                                   description: Text("New posts from the feeds you follow show up here."))
                        }
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .task(id: library.feeds.map(\.id)) { await loader.loadAll(library.feeds) }
    }
}

private struct FeedSwipePage: View {
    let item: FeedStreamItem

    var body: some View {
        Color.clear
            .overlay { FeedPhoto(url: item.entry.imageURL) }
            .overlay {
                LinearGradient(colors: [.clear, .clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    if !item.source.isEmpty {
                        Text(item.source.uppercased())
                            .appFont(.caption, weight: .bold)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(item.entry.title)
                        .appFont(.title, weight: .bold)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    if let date = item.entry.published {
                        Text(date, format: .relative(presentation: .named))
                            .appFont(.subheadline, weight: .medium)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
    }
}

/// One feed's posts, swiped sideways.
struct FeedRow: View {
    static let cardWidth: CGFloat = 240

    @EnvironmentObject private var loader: FeedLoader
    let url: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                NavigationLink { FeedPreviewPage(url: url, title: title) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(title).appFont(.headline).lineLimit(1)
                            Image(systemName: "chevron.right").appFont(.caption, weight: .semibold).foregroundStyle(.secondary)
                        }
                        if let detail { Text(detail).appFont(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                FollowFeedButton(url: url, title: title)
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) { cards }
                    .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
        .task { await loader.load(url: url) }
    }

    @ViewBuilder
    private var cards: some View {
        switch loader.states[url] {
        case .loaded(let entries):
            ForEach(entries) { entry in
                NavigationLink { FeedEntryPreview(entry: entry) } label: {
                    FeedCard(entry: entry, source: "").frame(width: Self.cardWidth)
                }
                .buttonStyle(.plain)
            }
            if entries.isEmpty {
                Text("No posts yet.").appFont(.subheadline).foregroundStyle(.secondary)
            } else if !loader.exhausted.contains(url) {
                FeedCard(entry: .placeholder(0), source: "")
                    .frame(width: Self.cardWidth)
                    .loadingPlaceholder()
                    .onAppear { Task { await loader.loadMore(url: url) } }
                    .id(entries.count)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
                .frame(height: Self.cardWidth * 10 / 16)
        case .loading, nil:
            ForEach(0..<3, id: \.self) { index in
                FeedCard(entry: .placeholder(index), source: "").frame(width: Self.cardWidth).loadingPlaceholder()
            }
        }
    }
}

extension FeedLoader {
    func isLoading(_ feeds: [Feed]) -> Bool {
        feeds.contains { feed in
            switch states[feed.url] {
            case .loading, nil: true
            default: false
            }
        }
    }

    func hasMore(_ feeds: [Feed]) -> Bool {
        feeds.contains { !exhausted.contains($0.url) }
    }

    /// Pages in older posts from every feed that has more.
    func loadMore(_ feeds: [Feed]) async {
        await withTaskGroup(of: Void.self) { group in
            for feed in feeds where !exhausted.contains(feed.url) {
                group.addTask { await self.loadMore(url: feed.url) }
            }
        }
    }

    /// Posts from `feeds` merged newest first, without repeats.
    func items(for feeds: [Feed]) -> [FeedStreamItem] {
        var seen = Set<String>()
        return feeds
            .flatMap { feed -> [FeedStreamItem] in
                guard let entries = states[feed.url]?.entries else { return [] }
                return entries.map { FeedStreamItem(entry: $0, source: feed.title) }
            }
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.entry.published ?? .distantPast) > ($1.entry.published ?? .distantPast) }
    }

    func loadAll(_ feeds: [Feed], force: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for feed in feeds {
                group.addTask { await self.load(feed, force: force) }
            }
        }
    }
}

#if os(iOS)
/// The newest followed posts as a swipeable row, for the Recipes home.
struct FeedShelf: View {
    static let limit = 10

    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    @Environment(\.openRecipesRoute) private var openRoute
    let margin: CGFloat
    var cardWidth: CGFloat = 260

    var body: some View {
        let items = Array(loader.items(for: library.feeds).prefix(Self.limit))
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                if items.isEmpty {
                    ForEach(0..<2, id: \.self) { index in
                        FeedCard(entry: .placeholder(index), source: "Recipe site").frame(width: cardWidth).loadingPlaceholder()
                    }
                }
                ForEach(items) { item in
                    Button { openRoute(.feedPost(item.entry)) } label: {
                        FeedCard(entry: item.entry, source: item.source).frame(width: cardWidth)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .task(id: library.feeds.map(\.id)) { await loader.loadAll(library.feeds) }
    }
}
#endif

extension FeedEntry {
    /// Stand-in post whose title gives a loading card its shape.
    static func placeholder(_ index: Int) -> FeedEntry {
        FeedEntry(title: index.isMultiple(of: 2) ? "A recipe title that wraps onto two lines" : "A shorter recipe title",
                  link: URL(string: "https://example.com/\(index)")!, published: .now)
    }
}

/// A post's photo, from the offline cache when it's saved there.
struct FeedPhoto: View {
    let url: URL?
    @State private var saved: CGImage?

    var body: some View {
        Group {
            if let saved {
                Image(decorative: saved, scale: 1).resizable().scaledToFill()
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .task(id: url) {
            guard let url else { return }
            saved = await Task.detached {
                FeedCache.standard.photo(for: url).flatMap { RecipeImageProcessing.thumbnail(from: $0, maxPixelSize: FeedCache.photoSize) }
            }.value
        }
    }
}

struct FeedCard: View {
    let entry: FeedEntry
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .aspectRatio(16 / 10, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    FeedPhoto(url: entry.imageURL)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).appFont(.title3, weight: .semibold).lineLimit(2)
                HStack(spacing: 4) {
                    if !source.isEmpty { Text(source) }
                    if let date = entry.published {
                        if !source.isEmpty { Text("·") }
                        Text(date, format: .relative(presentation: .named))
                    }
                }
                .appFont(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Pick popular recipe feeds with one tap, or add any site that has a feed.
struct RecipeFeedsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var adding = false
    var showsTabToggle = false

    private var customFeeds: [Feed] {
        let popular = Set(PopularFeed.all.map(\.url))
        return library.feeds.filter { !popular.contains($0.url) }
    }

    var body: some View {
        List {
            if showsTabToggle {
                TabVisibilitySection(tab: .feeds)
                OfflineFeedsSection()
            }
            Section {
                ForEach(customFeeds) { feed in
                    NavigationLink { FeedPreviewPage(url: feed.url, title: feed.title) } label: {
                        Label(feed.title, systemImage: "dot.radiowaves.up.forward")
                    }
                    .swipeActions {
                        Button("Unsubscribe", role: .destructive) { Task { await library.remove(feed) } }
                    }
                }
                Button { adding = true } label: { Label("Add a Site or Feed…", systemImage: "plus") }
            } header: {
                Text("Your Feeds")
            } footer: {
                Text("Tap a feed to preview its newest posts. Paste any recipe site's or YouTube channel's address and Recipes finds its feed.")
            }
            ForEach(PopularFeed.Kind.allCases, id: \.self) { kind in
                Section(kind.rawValue) {
                    ForEach(PopularFeed.all.filter { $0.kind == kind }) { row($0) }
                }
            }
        }
        .listStyle(.plain)
        .themedCanvas()
        .navigationTitle("Feeds")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add a Site or Feed", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $adding) { AddFeedSheet() }
    }

    private func row(_ popular: PopularFeed) -> some View {
        NavigationLink {
            FeedPreviewPage(url: popular.url, title: popular.name)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(popular.name)
                    Text(popular.detail).appFont(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                FollowFeedButton(url: popular.url, title: popular.name)
            }
        }
    }
}

/// Whether followed feeds are kept on the device, when they were last saved, and a way to free the space.
private struct OfflineFeedsSection: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    @AppStorage(AppSettings.Key.feedsOffline) private var savesOffline = true
    @State private var lastUpdated: Date?
    @State private var byteCount = 0

    var body: some View {
        Section {
            Toggle(isOn: $savesOffline) { Label("Save for Offline Reading", systemImage: "arrow.down.circle") }
            if savesOffline, let lastUpdated {
                LabeledContent("Last Saved") { Text(lastUpdated, format: .relative(presentation: .named)) }
            }
            if byteCount > 0 {
                Button("Remove Saved Posts (\(byteCount.formatted(.byteCount(style: .file))))", role: .destructive) {
                    FeedCache.standard.clear()
                    Task { await measure() }
                }
            }
        } header: {
            Text("Offline")
        } footer: {
            Text("Keeps the newest posts and photos from the feeds you follow on this device. They refresh when you open Recipes and now and then in the background.")
        }
        .task(id: savesOffline) {
            if savesOffline { await loader.refreshOffline(library.feeds) }
            #if os(iOS)
            FeedRefresh.schedule()
            #endif
            await measure()
        }
    }

    private func measure() async {
        let cache = FeedCache.standard
        let (date, bytes) = await Task.detached { (cache.lastUpdated, cache.byteCount) }.value
        lastUpdated = date
        byteCount = bytes
    }
}

/// Follows or unfollows a feed.
struct FollowFeedButton: View {
    @EnvironmentObject private var library: RecipeLibrary
    let url: String
    let title: String
    var onFollow: (() -> Void)?
    @State private var confirmingUnfollow = false

    private var subscribed: Feed? { library.feeds.first { $0.url == url } }

    var body: some View {
        Button {
            if subscribed != nil {
                confirmingUnfollow = true
            } else {
                Task {
                    let feed = Feed(url: url, title: title)
                    await library.add(feed)
                    onFollow?()
                    ToastCenter.shared.show("Following \(title)") { await library.remove(feed) }
                }
            }
        } label: {
            Image(systemName: subscribed == nil ? "plus.circle" : "checkmark.circle.fill")
                .foregroundStyle(subscribed == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.accent))
                .imageScale(.large)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(subscribed == nil ? "Follow \(title)" : "Unfollow \(title)")
        .sensoryFeedback(.selection, trigger: subscribed == nil)
        .confirmationDialog("Unfollow \(title)?", isPresented: $confirmingUnfollow, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) {
                guard let subscribed else { return }
                Task {
                    await library.remove(subscribed)
                    ToastCenter.shared.show("Unfollowed \(title)", symbol: "minus.circle.fill") { await library.add(subscribed) }
                }
            }
        } message: {
            Text("Its posts stop showing up in Feeds.")
        }
    }
}

/// A feed's newest posts, to look at before following it.
struct FeedPreviewPage: View {
    @EnvironmentObject private var loader: FeedLoader
    let url: String
    let title: String
    var onFollow: (() -> Void)?
    private let seed: [FeedEntry]?

    init(url: String, title: String, seed: [FeedEntry]? = nil, onFollow: (() -> Void)? = nil) {
        self.url = url
        self.title = title
        self.onFollow = onFollow
        self.seed = seed
    }

    var body: some View {
        Group {
            switch seed.map(FeedLoader.State.loaded) ?? loader.states[url] ?? .loading {
            case .loading:
                ScrollView {
                    GridSection(title: nil, minimum: 300, spacing: 20) {
                        ForEach(0..<6, id: \.self) { FeedCard(entry: .placeholder($0), source: "").loadingPlaceholder() }
                    }
                    .padding()
                }
                .scrollDisabled(true)
            case .failed(let message):
                ContentUnavailableView("Couldn't load feed", systemImage: "exclamationmark.triangle", description: Text(message))
            case .loaded(let entries):
                ScrollView {
                    GridSection(title: nil, minimum: 300, spacing: 20) {
                        ForEach(entries) { entry in
                            NavigationLink { FeedEntryPreview(entry: entry) } label: { FeedCard(entry: entry, source: "") }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    if seed == nil, !entries.isEmpty, !loader.exhausted.contains(url) {
                        GridSection(title: nil, minimum: 300, spacing: 20) {
                            ForEach(0..<2, id: \.self) { FeedCard(entry: .placeholder($0), source: "").loadingPlaceholder() }
                        }
                        .padding(.horizontal)
                        .onAppear { Task { await loader.loadMore(url: url) } }
                        .id(entries.count)
                    }
                }
            }
        }
        .themedCanvas()
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) { FollowFeedButton(url: url, title: title, onFollow: onFollow) }
        }
        .task(id: url) { if seed == nil { await loader.load(url: url) } }
    }
}
