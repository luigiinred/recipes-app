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
        case .searchWeb: "Recipe pages from across the web, from DuckDuckGo."
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
        async let found = withTaskGroup(of: [RecipeSearchResult].self) { group in
            for site in followed { group.addTask { await RecipeSearch.wordPress(site: site, query: text) } }
            var all: [RecipeSearchResult] = []
            for await results in group { all += results }
            return all
        }
        async let youTube = wantsYouTube ? RecipeSearch.youTube(text) : []
        async let fromWeb = wantsWeb ? RecipeSearch.web(text) : []
        let (webResults, siteResults, videoResults) = await (fromWeb, found, youTube)
        guard !Task.isCancelled else { return }
        withAnimation(.snappy) {
            web = webResults
            sites = siteResults
            videos = videoResults
            isSearching = false
        }
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
        .disabled(!parentIsOn)
    }
}
