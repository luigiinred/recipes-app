#if os(iOS) && !SHARE_EXTENSION
import Foundation
import RecipeKit
import WidgetKit

/// Keeps the Feeds widget's copy of followed feeds and their newest posts current.
enum FeedWidgetSync {
    static let kind = "FeedsWidget"

    static func publish(_ feeds: [Feed], entries: [String: [FeedEntry]]) async {
        guard let store = WidgetStore.shared else { return }
        var snapshot = FeedWidgetSnapshot.make(feeds: feeds, entries: entries, updatedAt: Date())
        snapshot.accentHex = ColorTheme.currentAccentHex()
        let cache = FeedCache.standard
        let saved = await Task.detached { () -> Bool in
            let current = store.loadFeeds()
            guard current.feeds != snapshot.feeds || current.posts != snapshot.posts || current.accentHex != snapshot.accentHex else { return false }
            return (try? await store.saveFeeds(snapshot) { cache.photo(for: $0) }) != nil
        }.value
        if saved { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }

    /// Each feed's posts as last fetched, from memory when there and otherwise from the offline copy.
    static func publish(_ feeds: [Feed], loaded: [String: [FeedEntry]] = [:]) async {
        let cache = FeedCache.standard
        let entries = await Task.detached {
            Dictionary(uniqueKeysWithValues: feeds.map { ($0.url, loaded[$0.url] ?? cache.snapshot(for: $0.url)?.entries ?? []) })
        }.value
        await publish(feeds, entries: entries)
    }
}
#endif
