import RecipeKit
import SwiftUI
import WebKit

/// Online search, always on, and each of its sources, on unless switched off in Settings → Search.
enum SearchSetting: String, CaseIterable, Identifiable {
    case discoverSearch, searchWeb, searchGoogle, searchFollowedSites, searchYouTube

    var id: String { rawValue }
    var key: String { "feature.\(rawValue)" }

    var parent: SearchSetting? { self == .discoverSearch ? nil : .discoverSearch }

    var isOn: Bool {
        if self == .discoverSearch { return true }
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: key) == nil || defaults.bool(forKey: key)
        return value && (parent?.isOn ?? true)
    }

    var title: String {
        switch self {
        case .discoverSearch: "Search Recipes Online"
        case .searchWeb: "Web Results"
        case .searchGoogle: "Search the Web"
        case .searchFollowedSites: "Sites You Follow"
        case .searchYouTube: "YouTube"
        }
    }

    var detail: String {
        switch self {
        case .discoverSearch: "When you search Home, Recipes or Discover, recipes from the web show up under your own."
        case .searchWeb: "Google's results, read in a hidden browser, shown as a clean list. DuckDuckGo fills in when Google gives none."
        case .searchGoogle: "A last row that opens Google; tapping a result shows it as a recipe."
        case .searchFollowedSites: "Posts from the WordPress sites in your feeds."
        case .searchYouTube: "Recipe videos, with Find Recipe Later."
        }
    }
}

struct SearchSettingsPage: View {
    var body: some View {
        ThemedForm {
            Section {
                ForEach(SearchSetting.allCases.filter { $0.parent != nil }) { SearchSettingToggle(setting: $0) }
            } header: {
                Text("Sources")
            } footer: {
                Text("None of these need an account or a key.")
            }
        }
        .formStyle(.grouped)
        .themedCanvas()
        .navigationTitle("Search")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Online recipes for a query, from each source that's switched on; each list fills in as its source answers.
@MainActor @Observable
final class OnlineRecipeSearch {
    enum Group: String, CaseIterable, Identifiable {
        case web = "From the Web"
        case videos = "YouTube"
        case sites = "From Sites You Follow"
        var id: Self { self }
    }

    private(set) var results: [Group: [RecipeSearchResult]] = [:]
    private(set) var isSearching = false
    /// The last query searched to the end, so coming back to the page from a result doesn't search it again.
    private var finished: String?

    init(seed: [Group: [RecipeSearchResult]] = [:]) {
        results = seed
    }

    var isEmpty: Bool { results.values.allSatisfy(\.isEmpty) }

    func results(in group: Group) -> [RecipeSearchResult] { results[group] ?? [] }

    func clear() {
        results = [:]
        isSearching = false
        finished = nil
    }

    /// Call from a `.task(id:)` so a newer query cancels this one.
    func run(_ query: String, feeds: [Feed]) async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != finished else { return }
        results = [:]
        guard !text.isEmpty, SearchSetting.discoverSearch.isOn else {
            isSearching = false
            finished = nil
            return
        }
        isSearching = true
        let wantsWeb = SearchSetting.searchWeb.isOn, wantsYouTube = SearchSetting.searchYouTube.isOn
        let followed = SearchSetting.searchFollowedSites.isOn ? Array(Set(feeds.compactMap { RecipeSearch.site(ofFeed: $0.url) })).prefix(12) : []
        await withTaskGroup(of: (Group, [RecipeSearchResult]).self) { group in
            if wantsWeb { group.addTask { (.web, await GoogleResults.search(text)) } }
            if wantsYouTube { group.addTask { (.videos, await RecipeSearch.youTube(text)) } }
            if !followed.isEmpty {
                group.addTask {
                    await withTaskGroup(of: [RecipeSearchResult].self) { sites in
                        for site in followed { sites.addTask { await RecipeSearch.wordPress(site: site, query: text) } }
                        var all: [RecipeSearchResult] = []
                        for await found in sites { all += found }
                        return (.sites, all)
                    }
                }
            }
            for await (kind, found) in group {
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) { results[kind] = found }
            }
        }
        if !Task.isCancelled {
            finished = text
            withAnimation(.snappy) { isSearching = false }
        }
    }
}

/// The app's one search: your recipes that match, then what each online source found, with Google at the end.
/// An empty query lists all your recipes. Your recipes drag onto the Plan board.
struct DiscoverSearchResults: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    @Environment(\.appearance) private var appearance
    let query: String
    /// Opens one of your recipes; without it a recipe pushes onto the surrounding stack.
    var openRecipe: ((UUID) -> Void)?
    @State private var search: OnlineRecipeSearch
    private let seeded: Bool

    /// `seed` shows fixed results without searching, for previews and snapshots.
    init(query: String, openRecipe: ((UUID) -> Void)? = nil, seed: [OnlineRecipeSearch.Group: [RecipeSearchResult]]? = nil) {
        self.query = query
        self.openRecipe = openRecipe
        seeded = seed != nil
        _search = State(initialValue: OnlineRecipeSearch(seed: seed ?? [:]))
    }

    private var text: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var mine: [Recipe] {
        library.recipes.filter { $0.matches(text) }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            if !mine.isEmpty {
                Section("My Recipes") {
                    ForEach(mine) { recipeLink($0).themedRow() }
                }
            }
            if !text.isEmpty {
                ForEach(OnlineRecipeSearch.Group.allCases) { group in
                    let results = search.results(in: group)
                    if !results.isEmpty {
                        Section(group.rawValue) {
                            ForEach(results) { OnlineResultLink(result: $0).themedRow() }
                        }
                    }
                }
                if search.isSearching {
                    Section { OnlineSearchProgress().themedRow() }
                } else if search.isEmpty, mine.isEmpty {
                    Section { Text("No recipes found.").foregroundStyle(.secondary).themedRow() }
                }
                Section { SearchTheWebLink(query: text).themedRow() }
            }
        }
        .listStyle(.plain)
        .overlay { if text.isEmpty, library.recipes.isEmpty { EmptyLibraryView() } }
        .task(id: text) { if !seeded { await search.run(text, feeds: library.feeds) } }
    }

    @ViewBuilder
    private func recipeLink(_ recipe: Recipe) -> some View {
        Group {
            if let openRecipe {
                // A tap, not a Button: a Mac button holds the mouse and the row never starts dragging.
                RecipeRow(recipe: recipe)
                    .contentShape(Rectangle())
                    .onTapGesture { openRecipe(recipe.id) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { openRecipe(recipe.id) }
            } else {
                PushLink { RecipeDetailView(recipe: recipe) } label: { RecipeRow(recipe: recipe) }
            }
        }
        .accessibilityIdentifier("search.recipe.\(recipe.title)")
        .draggable(RecipeDragItem(id: recipe.id)) {
            RecipeRow(recipe: recipe).padding(8).dragPreviewEnvironment(library, accent: accent, appearance: appearance)
        }
    }
}

/// An online result laid out like a recipe in the library list, opening in the app's recipe preview.
struct OnlineResultLink: View {
    @EnvironmentObject private var library: RecipeLibrary
    let result: RecipeSearchResult
    var asCard = false
    /// In a shelf every result is a row, videos too, and each row is its own link.
    var inShelf = false

    var body: some View {
        PushLink(inList: !asCard && !inShelf) {
            FeedEntryPreview(entry: FeedEntry(title: result.title, link: result.link, imageURL: result.imageURL))
        } label: {
            if inShelf { OnlineResultRow(result: result) }
            else if result.kind == .video { VideoResultCard(result: result) }
            else if asCard { OnlineResultCard(result: result) }
            else { OnlineResultRow(result: result) }
        }
        .contextMenu {
            if result.kind == .video {
                Button("Find Recipe Later", systemImage: "play.rectangle.on.rectangle") {
                    Task { await VideoRecipeFinder.saveForLater(title: result.title, link: result.link, imageURL: result.imageURL, library: library) }
                }
            }
            Link(destination: result.link) { Label("Open in Browser", systemImage: "safari") }
        }
        .draggable(BoardCard.web(result.link, result.title)) {
            Label(result.title, systemImage: "globe")
                .appFont(.subheadline, weight: .semibold)
                .lineLimit(2)
                .padding(12)
                .frame(width: 220, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// A link that pushes its page; in a list it leaves out the disclosure chevron, as library rows do.
struct PushLink<Label: View, Destination: View>: View {
    var inList = true
    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let label: () -> Label

    var body: some View {
        if inList {
            label().background { NavigationLink(destination: destination) { EmptyView() }.opacity(0) }
        } else {
            NavigationLink(destination: destination, label: label).buttonStyle(.plain)
        }
    }
}

/// Each result's page, read once as its row appears, for the photo and time a search engine leaves out.
@MainActor
final class OnlineResultPreviews {
    static let shared = OnlineResultPreviews()
    private var loading: [URL: Task<PagePreview?, Never>] = [:]

    func preview(for result: RecipeSearchResult) async -> PagePreview? {
        guard result.kind != .video else { return nil }
        if let task = loading[result.link] { return await task.value }
        let task = Task { await PagePreview.load(result.link) }
        loading[result.link] = task
        return await task.value
    }
}

struct OnlineResultRow: View {
    let result: RecipeSearchResult
    @State private var preview: PagePreview?

    var body: some View {
        ThumbnailRow(title: result.title) {
            OnlineResultImage(result: result, preview: preview)
        } subtitle: {
            OnlineResultSource(result: result, preview: preview)
        }
        .task(id: result.link) { preview = await OnlineResultPreviews.shared.preview(for: result) }
    }
}

struct OnlineResultCard: View {
    let result: RecipeSearchResult
    @State private var preview: PagePreview?

    var body: some View {
        PhotoCard(title: result.title) {
            OnlineResultImage(result: result, preview: preview)
        } detail: {
            OnlineResultSource(result: result, preview: preview)
        }
        .task(id: result.link) { preview = await OnlineResultPreviews.shared.preview(for: result) }
    }
}

/// A video as YouTube shows it: the picture first, at 16:9, with its running time, then the title and channel.
struct VideoResultCard: View {
    @Environment(\.appAccent) private var accent
    let result: RecipeSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The thumbnail is 4:3 with the video letterboxed inside; filling 16:9 crops the bars away.
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    AsyncImage(url: result.imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            accent.opacity(0.12)
                            Image(systemName: "play.rectangle").appFont(.largeTitle).foregroundStyle(accent.opacity(0.45))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if let duration = result.duration {
                        Text(duration)
                            .appFont(.caption, weight: .semibold)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(8)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title).appFont(.headline).lineLimit(2)
                Label {
                    Text([result.source, result.detail].compactMap { $0 }.joined(separator: "  ·  "))
                } icon: {
                    Image(systemName: "play.rectangle")
                }
                .labelStyle(.titleAndIcon)
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

/// Where a result came from, with a mark for its kind, in the same style as a library recipe's facts.
private struct OnlineResultSource: View {
    let result: RecipeSearchResult
    let preview: PagePreview?

    var body: some View {
        Label {
            Text([result.source.isEmpty ? (result.link.host ?? "") : result.source, preview?.minutes.map { "\($0) min" }]
                .compactMap { $0 }.joined(separator: "  ·  "))
        } icon: {
            Image(systemName: symbol)
        }
        .labelStyle(.titleAndIcon)
        .appFont(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var symbol: String {
        switch result.kind {
        case .web: "globe"
        case .site: "dot.radiowaves.up.forward"
        case .video: "play.rectangle"
        }
    }
}

private struct OnlineResultImage: View {
    @Environment(\.appAccent) private var accent
    let result: RecipeSearchResult
    let preview: PagePreview?

    var body: some View {
        AsyncImage(url: result.imageURL ?? preview?.imageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                accent.opacity(0.12)
                Image(systemName: result.kind == .video ? "play.rectangle" : "fork.knife")
                    .appFont(.title2)
                    .foregroundStyle(accent.opacity(0.45))
            }
        }
    }
}

struct OnlineSearchProgress: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Searching online…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

/// Google in the app's browser, at the end of every online search.
struct SearchTheWebLink: View {
    @AppStorage(SearchSetting.searchGoogle.key) private var enabled = true
    @Environment(\.appAccent) private var accent
    let query: String
    var inList = true

    var body: some View {
        if enabled, let url = RecipeSearch.webSearchURL(query) {
            PushLink(inList: inList) { RecipeWebBrowser(start: url, title: "“\(query)”") } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe").foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search the Web for “\(query)”").foregroundStyle(.primary)
                        Text("Tap a result to see it as a recipe you can add.").appFont(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
            }
        }
    }
}

/// Google's results for a query, read from the page after it runs in a browser no one sees, since Google only builds them with JavaScript.
@MainActor
enum GoogleResults {
    static func search(_ query: String) async -> [RecipeSearchResult] {
        async let fallback = RecipeSearch.web(query)
        var found: [RecipeSearchResult] = []
        if let url = RecipeSearch.webSearchURL(query) {
            let page = WebPage()
            if (try? await finishLoading(page, url)) != nil {
                for _ in 0..<12 {
                    if let results = try? await results(on: page), !results.isEmpty { found = results; break }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
        }
        guard found.count < 8 else { return found }
        let pages = Set(found.map(Self.pageKey))
        return found + (await fallback).filter { !pages.contains(Self.pageKey($0)) }
    }

    private static func pageKey(_ result: RecipeSearchResult) -> String {
        (result.link.host?.replacingOccurrences(of: "www.", with: "") ?? "") + result.link.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func finishLoading(_ page: WebPage, _ url: URL) async throws {
        for try await _ in page.load(URLRequest(url: url, timeoutInterval: 15)) {}
    }

    /// Groups the result cards' links by where they go, taking each card's first lines of text and its first picture.
    private static let script = """
    const groups = new Map();
    for (const a of document.querySelectorAll('#rso a[href], #search a[href]')) {
      if (!a.href.startsWith('http')) continue;
      const u = new URL(a.href);
      if (/(^|\\.)google\\./.test(u.hostname) && u.pathname !== '/goto' && u.pathname !== '/url') continue;
      let group = groups.get(a.href);
      if (!group) { group = { url: a.href, lines: [], image: '' }; groups.set(a.href, group); }
      const lines = (a.innerText || '').split('\\n').map(t => t.trim()).filter(Boolean);
      if (!group.lines.length && lines.length) group.lines = lines.slice(0, 3);
      if (!group.image) {
        const img = a.querySelector('img');
        const src = img && (img.currentSrc || img.src);
        if (src && (src.startsWith('http') || src.startsWith('data:image'))) group.image = src;
      }
    }
    return [...groups.values()].filter(g => g.lines.length).map(g => ({ title: g.lines[0], detail: g.lines.slice(1).join(' '), url: g.url, image: g.image }));
    """

    private static func results(on page: WebPage) async throws -> [RecipeSearchResult] {
        guard let rows = try await page.callJavaScript(script) as? [[String: Any]], !rows.isEmpty else { return [] }
        let cards: [(title: String, detail: String, link: URL, image: URL?)] = rows.compactMap { row in
            guard let title = row["title"] as? String, !title.isEmpty, let link = (row["url"] as? String).flatMap(URL.init(string:)) else { return nil }
            let image = (row["image"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            return (title, row["detail"] as? String ?? "", link, image)
        }
        let resolved = await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, card) in cards.enumerated() { group.addTask { (index, await destination(of: card.link)) } }
            var found: [Int: URL] = [:]
            for await (index, url) in group { if let url { found[index] = url } }
            return found
        }
        var seen = Set<String>()
        return cards.indices.compactMap { index in
            guard let link = resolved[index], link.scheme?.hasPrefix("http") == true, !RecipeSearch.isSearchEnginePage(link),
                  seen.insert(link.absoluteString).inserted else { return nil }
            let card = cards[index]
            let host = link.host?.replacingOccurrences(of: "www.", with: "") ?? ""
            let rating = card.detail.range(of: #"^\d(\.\d)? \([\d.,]+K?\)"#, options: .regularExpression).map { "★ " + card.detail[$0] }
            return RecipeSearchResult(title: card.title, link: link, source: [host, rating].compactMap { $0 }.joined(separator: " · "),
                                      imageURL: card.image, kind: .web)
        }
    }

    /// Google's mobile links go through `/goto`, which answers with a redirect to the page; this reads it without following.
    nonisolated private static func destination(of url: URL) async -> URL? {
        guard RecipeSearch.isSearchEnginePage(url) else { return url }
        guard url.path == "/goto" else {
            let target = RecipeSearch.destination(of: url)
            return target == url ? nil : target
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        guard let response = try? await URLSession.shared.data(for: request, delegate: StopAtRedirect()).1 as? HTTPURLResponse,
              let location = response.value(forHTTPHeaderField: "Location") else { return nil }
        return URL(string: location, relativeTo: url)?.absoluteURL
    }
}

private final class StopAtRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        nil
    }
}

/// Google in the app. Tapping a result opens it in the app's own recipe layout, with Add to My Recipes, instead of the site.
struct RecipeWebBrowser: View {
    let start: URL
    let title: String

    @State private var page: WebPage?
    @State private var opened: OpenedPage?

    private struct OpenedPage: Identifiable, Hashable {
        let url: URL
        var id: String { url.absoluteString }
    }

    var body: some View {
        Group {
            if let page {
                WebView(page).ignoresSafeArea(edges: .bottom)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $opened) { opened in
            FeedEntryPreview(entry: FeedEntry(title: opened.url.host?.replacingOccurrences(of: "www.", with: "") ?? "", link: opened.url))
        }
        .task {
            guard page == nil else { return }
            let page = WebPage(navigationDecider: ResultLinks { opened = OpenedPage(url: $0) })
            page.load(URLRequest(url: start))
            self.page = page
        }
    }
}

/// Keeps searching inside the browser, and hands any page away from the search engine to the recipe preview.
private struct ResultLinks: WebPage.NavigationDeciding {
    let open: @MainActor (URL) -> Void

    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        guard let url = action.request.url, action.target?.isMainFrame ?? true, url.scheme?.hasPrefix("http") == true else { return .allow }
        let destination = RecipeSearch.destination(of: url)
        guard !RecipeSearch.isSearchEnginePage(destination) else { return .allow }
        await open(destination)
        return .cancel
    }
}

struct SearchSettingToggle: View {
    let setting: SearchSetting
    @AppStorage private var isOn: Bool

    init(setting: SearchSetting) {
        self.setting = setting
        _isOn = AppStorage(wrappedValue: true, setting.key)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(setting.title)
                Text(setting.detail).appFont(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension View {
    /// A search box whose submitted query swaps the page for the app's search results. A Mac window has one search for every page instead.
    func discoverSearch() -> some View { modifier(DiscoverSearchModifier()) }
}

private struct DiscoverSearchModifier: ViewModifier {
    @State private var query = ""
    @State private var submitted = ""

    func body(content: Content) -> some View {
        #if os(iOS)
        Group {
            if submitted.isEmpty { content } else { DiscoverSearchResults(query: submitted) }
        }
        .searchable(text: $query, prompt: "Search")
        .onSubmit(of: .search) { submitted = query.trimmingCharacters(in: .whitespacesAndNewlines) }
        .onChange(of: query) { _, text in if text.isEmpty { submitted = "" } }
        #else
        content
        #endif
    }
}
