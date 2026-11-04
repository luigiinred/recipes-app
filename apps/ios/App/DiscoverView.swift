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
        PopularFeed(name: "Smitten Kitchen", detail: "Deb Perelman", url: "https://smittenkitchen.com/feed/", kind: .weeknight),
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
    ]
}

private enum DiscoverRoute: Hashable {
    case entry(FeedEntry)
    case feeds
}

struct DiscoverItem: Identifiable {
    let entry: FeedEntry
    let source: String
    var id: String { entry.id }
}

struct DiscoverTab: View {
    var body: some View {
        NavigationStack { DiscoverView() }
    }
}

/// Every subscribed feed merged into one stream, newest first.
struct DiscoverView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var loader: FeedLoader
    @Environment(\.appAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @State private var source: UUID?

    private var shownFeeds: [Feed] {
        library.feeds.filter { source == nil || $0.id == source }
    }

    private var items: [DiscoverItem] { loader.items(for: shownFeeds) }

    private var failedFeeds: [Feed] {
        shownFeeds.filter { if case .failed? = loader.states[$0.id] { true } else { false } }
    }

    private var isLoading: Bool {
        shownFeeds.contains { if case .loaded? = loader.states[$0.id] { false } else if case .failed? = loader.states[$0.id] { false } else { true } }
    }

    var body: some View {
        Group {
            if library.feeds.isEmpty {
                ContentUnavailableView {
                    Label("No feeds yet", systemImage: "dot.radiowaves.up.forward")
                } description: {
                    Text("Follow recipe sites and blogs to see their newest recipes here.")
                } actions: {
                    NavigationLink("Browse Popular Feeds", value: DiscoverRoute.feeds)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                stream
            }
        }
        .themedCanvas()
        .navigationTitle("Discover")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: DiscoverRoute.feeds) { Label("Feeds", systemImage: "dot.radiowaves.up.forward") }
            }
        }
        .navigationDestination(for: DiscoverRoute.self) { route in
            switch route {
            case .entry(let entry): FeedEntryPreview(entry: entry)
            case .feeds: DiscoverFeedsPage()
            }
        }
        .task(id: library.feeds.map(\.id)) { await loader.loadAll(library.feeds) }
        .refreshable { await loader.loadAll(library.feeds, force: true) }
        .onChange(of: library.feeds) { _, feeds in
            if let source, !feeds.contains(where: { $0.id == source }) { self.source = nil }
        }
    }

    private var stream: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sourceChips
                if items.isEmpty, isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                } else {
                    GridSection(title: nil, minimum: 300, spacing: 20) {
                        ForEach(items) { item in
                            NavigationLink(value: DiscoverRoute.entry(item.entry)) {
                                DiscoverCard(entry: item.entry, source: item.source)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                if !failedFeeds.isEmpty {
                    Text("Couldn't load \(failedFeeds.map(\.title).formatted()).")
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private var sourceChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isOn: source == nil) { source = nil }
                ForEach(library.feeds) { feed in
                    chip(feed.title, isOn: source == feed.id) { source = feed.id }
                }
            }
            .padding(.horizontal)
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(.subheadline, weight: .medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOn ? accent : accent.opacity(colorScheme == .dark ? 0.24 : 0.12), in: Capsule())
                .foregroundStyle(isOn ? .white : accent.mix(with: colorScheme == .dark ? .white : .black, by: 0.35))
        }
        .buttonStyle(.plain)
    }

}

extension FeedLoader {
    /// Posts from `feeds` merged newest first, without repeats.
    func items(for feeds: [Feed]) -> [DiscoverItem] {
        var seen = Set<String>()
        return feeds
            .flatMap { feed -> [DiscoverItem] in
                guard case .loaded(let entries)? = states[feed.id] else { return [] }
                return entries.map { DiscoverItem(entry: $0, source: feed.title) }
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

/// The newest followed posts as a swipeable row, for the Recipes home.
struct DiscoverShelf: View {
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
                    ProgressView().frame(width: cardWidth, height: cardWidth * 10 / 16)
                }
                ForEach(items) { item in
                    Button { openRoute(.discoverPost(item.entry)) } label: {
                        DiscoverCard(entry: item.entry, source: item.source).frame(width: cardWidth)
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

struct DiscoverCard: View {
    let entry: FeedEntry
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .aspectRatio(16 / 10, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    AsyncImage(url: entry.imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            Color.secondary.opacity(0.12)
                            Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.tertiary)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).appFont(.title3, weight: .semibold).lineLimit(2)
                HStack(spacing: 4) {
                    Text(source)
                    if let date = entry.published {
                        Text("·")
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
struct DiscoverFeedsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var adding = false

    private var customFeeds: [Feed] {
        let popular = Set(PopularFeed.all.map(\.url))
        return library.feeds.filter { !popular.contains($0.url) }
    }

    var body: some View {
        Form {
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
                Text("Tap a feed to preview its newest posts. Paste any recipe site's address and Recipes finds its RSS feed.")
            }
            ForEach(PopularFeed.Kind.allCases, id: \.self) { kind in
                Section(kind.rawValue) {
                    ForEach(PopularFeed.all.filter { $0.kind == kind }) { row($0) }
                }
            }
        }
        .formStyle(.grouped)
        .settingsSpacing()
        .themedCanvas()
        .navigationTitle("Discover Feeds")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

/// Follows or unfollows a feed.
struct FollowFeedButton: View {
    @EnvironmentObject private var library: RecipeLibrary
    let url: String
    let title: String
    var onFollow: (() -> Void)?

    private var subscribed: Feed? { library.feeds.first { $0.url == url } }

    var body: some View {
        Button {
            Task {
                if let subscribed { await library.remove(subscribed) }
                else {
                    await library.add(Feed(url: url, title: title))
                    onFollow?()
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
    }
}

/// A feed's newest posts, to look at before following it.
struct FeedPreviewPage: View {
    let url: String
    let title: String
    var onFollow: (() -> Void)?
    @State private var state: FeedLoader.State

    init(url: String, title: String, seed: [FeedEntry]? = nil, onFollow: (() -> Void)? = nil) {
        self.url = url
        self.title = title
        self.onFollow = onFollow
        _state = State(initialValue: seed.map { .loaded($0) } ?? .loading)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView("Couldn't load feed", systemImage: "exclamationmark.triangle", description: Text(message))
            case .loaded(let entries):
                ScrollView {
                    GridSection(title: nil, minimum: 300, spacing: 20) {
                        ForEach(entries) { entry in
                            NavigationLink { FeedEntryPreview(entry: entry) } label: { DiscoverCard(entry: entry, source: title) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding()
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
        .task(id: url) {
            if case .loaded = state { return }
            await load()
        }
    }

    private func load() async {
        guard let feedURL = URL(string: url) else {
            state = .failed("Bad feed address.")
            return
        }
        do {
            state = .loaded(try await FeedService.fetch(feedURL).entries)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
