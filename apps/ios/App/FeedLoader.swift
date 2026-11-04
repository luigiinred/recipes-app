import Foundation
import RecipeKit

/// Feed posts by feed address, so a feed can be browsed before it's followed.
@MainActor
final class FeedLoader: ObservableObject {
    enum State {
        case loading
        case loaded([FeedEntry])
        case failed(String)
    }

    @Published private(set) var states: [String: State] = [:]
    @Published private(set) var results: [String: ImportResult] = [:]
    /// Feeds with no older posts to page in.
    @Published private(set) var exhausted: Set<String> = []
    private var pages: [String: Int] = [:]
    private var loadingMore: Set<String> = []
    private let fetches: Bool

    /// A seeded loader never fetches, so previews and snapshots stay offline.
    init(seed: [String: State]? = nil, results: [String: ImportResult] = [:]) {
        fetches = seed == nil
        states = seed ?? [:]
        exhausted = Set(states.keys)
        self.results = results
    }

    func loadRecipe(for entry: FeedEntry) async throws {
        if results[entry.id] != nil { return }
        results[entry.id] = try await RecipeImporter.importResult(from: entry.link)
    }

    func load(_ feed: Feed, force: Bool = false) async {
        await load(url: feed.url, force: force)
    }

    func load(url address: String, force: Bool = false) async {
        guard fetches else { return }
        if !force, let state = states[address], !state.isFailed { return }
        guard let url = URL(string: address) else {
            states[address] = .failed("Bad feed address.")
            return
        }
        if states[address]?.entries == nil { states[address] = .loading }
        do {
            states[address] = .loaded(try await FeedService.fetch(url).entries)
            pages[address] = 1
            exhausted.remove(address)
        } catch {
            states[address] = .failed(error.localizedDescription)
        }
    }

    /// Appends the feed's next page of older posts.
    func loadMore(url address: String) async {
        guard fetches, let entries = states[address]?.entries, !exhausted.contains(address), !loadingMore.contains(address),
              let url = URL(string: address) else { return }
        loadingMore.insert(address)
        defer { loadingMore.remove(address) }
        let page = (pages[address] ?? 1) + 1
        let known = Set(entries.map(\.id))
        let older = (try? await FeedService.fetch(FeedService.pageURL(url, page: page)).entries)?.filter { !known.contains($0.id) } ?? []
        guard !older.isEmpty, let current = states[address]?.entries else {
            exhausted.insert(address)
            return
        }
        states[address] = .loaded(current + older)
        pages[address] = page
    }
}

extension FeedLoader.State {
    var isFailed: Bool { if case .failed = self { true } else { false } }
    var entries: [FeedEntry]? { if case .loaded(let entries) = self { entries } else { nil } }
}
