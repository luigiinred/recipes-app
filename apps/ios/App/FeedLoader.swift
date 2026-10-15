import Foundation
import RecipeKit

@MainActor
final class FeedLoader: ObservableObject {
    enum State {
        case loading
        case loaded([FeedEntry])
        case failed(String)
    }

    @Published private(set) var states: [UUID: State] = [:]
    @Published private(set) var results: [String: ImportResult] = [:]

    init(seed: [UUID: State] = [:], results: [String: ImportResult] = [:]) {
        states = seed
        self.results = results
    }

    func loadRecipe(for entry: FeedEntry) async throws {
        if results[entry.id] != nil { return }
        results[entry.id] = try await RecipeImporter.importResult(from: entry.link)
    }

    func load(_ feed: Feed, force: Bool = false) async {
        if !force, case .loaded = states[feed.id] { return }
        guard let url = URL(string: feed.url) else {
            states[feed.id] = .failed("Bad feed address.")
            return
        }
        if states[feed.id] == nil { states[feed.id] = .loading }
        do {
            states[feed.id] = .loaded(try await FeedService.fetch(url).entries)
        } catch {
            states[feed.id] = .failed(error.localizedDescription)
        }
    }
}
