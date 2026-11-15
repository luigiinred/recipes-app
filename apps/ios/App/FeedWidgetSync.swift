#if os(iOS) && !SHARE_EXTENSION
import Foundation
import RecipeKit
import WidgetKit

/// Keeps the Feeds widget's copy of followed feeds and their newest posts current.
enum FeedWidgetSync {
    static let kind = "FeedsWidget"

    static func publish(_ feeds: [Feed], entries: [String: [FeedEntry]], viewed: ViewedPosts? = nil) async {
        guard let store = WidgetStore.shared else { return }
        let showViewed = UserDefaults.standard.bool(forKey: AppSettings.Key.feedShowViewed)
        let hidden = showViewed ? [] : (viewed ?? ViewedPostsStore.standard.load()).ids
        var snapshot = FeedWidgetSnapshot.make(feeds: feeds, entries: entries, viewed: hidden, updatedAt: Date())
        snapshot.accentHex = ColorTheme.currentAccentHex()
        let cache = FeedCache.standard
        let saved = await Task.detached { () -> Bool in
            let current = store.loadFeeds()
            guard current.feeds != snapshot.feeds || current.posts != snapshot.posts || current.viewed != snapshot.viewed || current.accentHex != snapshot.accentHex else { return false }
            return (try? await store.saveFeeds(snapshot) { cache.photo(for: $0) }) != nil
        }.value
        if saved { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }

    /// Each feed's posts as last fetched, from memory when there and otherwise from the offline copy.
    static func publish(_ feeds: [Feed], loaded: [String: [FeedEntry]] = [:], viewed: ViewedPosts? = nil) async {
        let cache = FeedCache.standard
        let entries = await Task.detached {
            Dictionary(uniqueKeysWithValues: feeds.map { ($0.url, loaded[$0.url] ?? cache.snapshot(for: $0.url)?.entries ?? []) })
        }.value
        await publish(feeds, entries: entries, viewed: viewed)
    }
}
#endif
