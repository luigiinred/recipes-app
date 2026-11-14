import RecipeKit
import SwiftUI
import WebKit

/// Features still being tried out, each with its own switch in Developer Tools. A source switch only matters with its parent on.
enum FeatureFlag: String, CaseIterable, Identifiable {
    case discoverSearch, searchWeb, searchGoogle, searchFollowedSites, searchYouTube

    var id: String { rawValue }
    var key: String { "feature.\(rawValue)" }

    var parent: FeatureFlag? { self == .discoverSearch ? nil : .discoverSearch }
    var defaultValue: Bool { parent != nil }

    var isOn: Bool {
        let value = UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
        return value && (parent?.isOn ?? true)
    }

    var title: String {
        switch self {
        case .discoverSearch: "Discover Search"
        case .searchWeb: "Web Results"
        case .searchGoogle: "Search Google in a Browser"
        case .searchFollowedSites: "Sites You Follow"
        case .searchYouTube: "YouTube"
        }
    }

    var detail: String {
        switch self {
        case .discoverSearch: "A search box on Discover for finding new recipes."
        case .searchWeb: "Google's results, read in a hidden browser, shown as a clean list. DuckDuckGo fills in when Google gives none."
        case .searchGoogle: "A row that opens Google; tapping a result shows it as a recipe."
        case .searchFollowedSites: "Posts from the WordPress sites in your feeds."
        case .searchYouTube: "Recipe videos, with Find Recipe Later."
        }
    }
}

/// What a search on Discover found: a way into the web, then the sites you follow, then YouTube.
struct DiscoverSearchResults: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.appAccent) private var accent
    let query: String
    private let seeded: Bool

    @State private var web: [RecipeSearchResult] = []
    @State private var sites: [RecipeSearchResult]
    @State private var videos: [RecipeSearchResult]
    @State private var isSearching = false
    @AppStorage(FeatureFlag.searchWeb.key) private var showsWeb = true
    @AppStorage(FeatureFlag.searchGoogle.key) private var showsGoogle = true
    @AppStorage(FeatureFlag.searchFollowedSites.key) private var showsSites = true
    @AppStorage(FeatureFlag.searchYouTube.key) private var showsYouTube = true

    /// `seed` shows fixed results without searching, for previews and snapshots.
    init(query: String, seed: (web: [RecipeSearchResult], sites: [RecipeSearchResult], videos: [RecipeSearchResult])? = nil) {
        self.query = query
        seeded = seed != nil
        _web = State(initialValue: seed?.web ?? [])
        _sites = State(initialValue: seed?.sites ?? [])
        _videos = State(initialValue: seed?.videos ?? [])
    }

    var body: some View {
        List {
            if showsWeb, !web.isEmpty {
                Section("From the Web") { ForEach(web) { row($0) } }
            }
            if showsGoogle, let url = RecipeSearch.webSearchURL(query) {
                Section {
                    NavigationLink { RecipeWebBrowser(start: url, title: "“\(query)”") } label: {
                        Label("Search Google for “\(query)”", systemImage: "globe")
                    }
                } footer: {
                    Text("Tap a result to see it as a recipe you can add.")
                }
            }
            if !sites.isEmpty {
                Section("From Sites You Follow") { ForEach(sites) { row($0) } }
            }
            if !videos.isEmpty {
                Section("YouTube") { ForEach(videos) { row($0) } }
            }
            if isSearching {
                Section { HStack { ProgressView().controlSize(.small); Text("Searching…").foregroundStyle(.secondary) } }
            } else if web.isEmpty, sites.isEmpty, videos.isEmpty {
                Section { Text("No recipes found.").foregroundStyle(.secondary) }
            }
        }
        .task(id: query) { await search() }
    }

    private func row(_ result: RecipeSearchResult) -> some View {
        NavigationLink {
            FeedEntryPreview(entry: FeedEntry(title: result.title, link: result.link, imageURL: result.imageURL))
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: result.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    accent.opacity(0.12).overlay(Image(systemName: result.kind == .video ? "play.rectangle" : "fork.knife").foregroundStyle(accent))
                }
                .frame(width: 64, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title).lineLimit(2)
                    Text(result.source).appFont(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .contextMenu {
            if result.kind == .video {
                Button("Find Recipe Later", systemImage: "play.rectangle.on.rectangle") {
                    Task { await VideoRecipeFinder.saveForLater(title: result.title, link: result.link, imageURL: result.imageURL, library: library) }
                }
            }
            Link(destination: result.link) { Label("Open in Browser", systemImage: "safari") }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !seeded else { return }
        isSearching = true
        web = []
        sites = []
        videos = []
        let (wantsWeb, wantsSites, wantsYouTube) = (showsWeb, showsSites, showsYouTube)
        let followed = wantsSites ? Array(Set(library.feeds.compactMap { RecipeSearch.site(ofFeed: $0.url) })).prefix(12) : []
        enum Found { case web([RecipeSearchResult]), sites([RecipeSearchResult]), videos([RecipeSearchResult]) }
        await withTaskGroup(of: Found.self) { group in
            if wantsWeb { group.addTask { .web(await GoogleResults.search(text)) } }
            if wantsYouTube { group.addTask { .videos(await RecipeSearch.youTube(text)) } }
            if !followed.isEmpty {
                group.addTask {
                    await withTaskGroup(of: [RecipeSearchResult].self) { sites in
                        for site in followed { sites.addTask { await RecipeSearch.wordPress(site: site, query: text) } }
                        var all: [RecipeSearchResult] = []
                        for await results in sites { all += results }
                        return .sites(all)
                    }
                }
            }
            for await found in group {
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) {
                    switch found {
                    case .web(let results): web = results
                    case .sites(let results): sites = results
                    case .videos(let results): videos = results
                    }
                }
            }
        }
        if !Task.isCancelled { isSearching = false }
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

struct FeatureFlagToggle: View {
    let flag: FeatureFlag
    @AppStorage private var isOn: Bool
    @AppStorage private var parentIsOn: Bool

    init(flag: FeatureFlag) {
        self.flag = flag
        _isOn = AppStorage(wrappedValue: flag.defaultValue, flag.key)
        let parent = flag.parent ?? flag
        _parentIsOn = AppStorage(wrappedValue: parent.defaultValue, parent.key)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(flag.title)
                Text(flag.detail).appFont(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.leading, flag.parent == nil ? 0 : 16)
        .disabled(flag.parent != nil && !parentIsOn)
    }
}
