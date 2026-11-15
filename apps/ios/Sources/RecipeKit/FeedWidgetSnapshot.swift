import CryptoKit
import Foundation

/// The followed feeds and their newest posts, for the Feeds home screen widget.
public struct FeedWidgetSnapshot: Codable, Equatable, Sendable {
    public struct Post: Codable, Equatable, Identifiable, Sendable {
        public var title: String
        public var link: URL
        public var feedURL: String
        public var source: String
        public var published: Date?
        public var imageURL: URL?

        public var id: String { link.absoluteString }
        public var entry: FeedEntry { FeedEntry(title: title, link: link, published: published, imageURL: imageURL) }

        public init(title: String, link: URL, feedURL: String, source: String, published: Date? = nil, imageURL: URL? = nil) {
            self.title = title
            self.link = link
            self.feedURL = feedURL
            self.source = source
            self.published = published
            self.imageURL = imageURL
        }
    }

    public static let postsPerFeed = 6
    public static let maxPosts = 60

    public var feeds: [Feed]
    public var posts: [Post]
    /// Viewed posts still in the feeds, so a refresh in the widget keeps them hidden.
    public var viewed: Set<String>
    public var accentHex: String?
    public var updatedAt: Date?

    public init(feeds: [Feed] = [], posts: [Post] = [], viewed: Set<String> = [], accentHex: String? = nil, updatedAt: Date? = nil) {
        self.feeds = feeds
        self.posts = posts
        self.viewed = viewed
        self.accentHex = accentHex
        self.updatedAt = updatedAt
    }

    public static let empty = FeedWidgetSnapshot()

    /// The newest unviewed posts of each feed, newest first across all of them.
    public static func make(feeds: [Feed], entries: [String: [FeedEntry]], viewed: Set<String> = [], updatedAt: Date? = nil) -> FeedWidgetSnapshot {
        let posts = feeds.flatMap { feed in
            (entries[feed.url] ?? []).filter { !viewed.contains($0.id) }.prefix(postsPerFeed).map {
                Post(title: $0.title, link: $0.link, feedURL: feed.url, source: feed.title, published: $0.published, imageURL: $0.imageURL)
            }
        }
        let order = Dictionary(feeds.enumerated().map { ($1.url, $0) }, uniquingKeysWith: { first, _ in first })
        let sorted = posts.enumerated().sorted { a, b in
            switch (a.element.published, b.element.published) {
            case let (x?, y?) where x != y: return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return (order[a.element.feedURL] ?? 0, a.offset) < (order[b.element.feedURL] ?? 0, b.offset)
            }
        }
        var seen = Set<String>()
        let unique = sorted.map(\.element).filter { seen.insert($0.id).inserted }
        let present = Set(feeds.flatMap { entries[$0.url] ?? [] }.map(\.id))
        return FeedWidgetSnapshot(feeds: feeds, posts: Array(unique.prefix(maxPosts)), viewed: viewed.intersection(present), updatedAt: updatedAt)
    }

    /// Posts from one feed, or from every feed when `feedURL` is nil.
    public func posts(from feedURL: String?) -> [Post] {
        guard let feedURL else { return posts }
        return posts.filter { $0.feedURL == feedURL }
    }

    /// Fetches every feed, keeping a feed's saved posts when its fetch fails.
    public func refreshed(at date: Date = Date()) async -> FeedWidgetSnapshot {
        let saved = Dictionary(grouping: posts, by: \.feedURL).mapValues { $0.map(\.entry) }
        let fetched = await withTaskGroup(of: (String, [FeedEntry]?).self) { group in
            for feed in feeds {
                group.addTask {
                    guard let url = URL(string: feed.url) else { return (feed.url, nil) }
                    return (feed.url, try? await FeedService.fetch(url).entries)
                }
            }
            var all: [String: [FeedEntry]] = [:]
            for await (url, entries) in group { all[url] = entries ?? saved[url] }
            return all
        }
        var snapshot = Self.make(feeds: feeds, entries: fetched, viewed: viewed, updatedAt: date)
        snapshot.accentHex = accentHex
        return snapshot
    }
}

public extension WidgetStore {
    static let feedPhotoSize = 360

    private var feedsURL: URL { directory.appendingPathComponent("feeds.json") }
    private var feedImagesDirectory: URL { directory.appendingPathComponent("FeedImages", isDirectory: true) }

    func feedImageURL(for image: URL) -> URL {
        let key = SHA256.hash(data: Data(image.absoluteString.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        return feedImagesDirectory.appendingPathComponent(key + ".jpg")
    }

    func loadFeeds() -> FeedWidgetSnapshot {
        (try? Data(contentsOf: feedsURL)).flatMap { try? JSONDecoder().decode(FeedWidgetSnapshot.self, from: $0) } ?? .empty
    }

    /// Saves the posts with a small photo for each of `photographed`, getting missing ones from `photo` and dropping unused ones.
    func saveFeeds(_ snapshot: FeedWidgetSnapshot, photographed: [FeedWidgetSnapshot.Post]? = nil, photo: @Sendable (URL) async -> Data?) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: feedImagesDirectory, withIntermediateDirectories: true)
        for image in (photographed ?? snapshot.posts).compactMap(\.imageURL) where !fm.fileExists(atPath: feedImageURL(for: image).path) {
            guard let data = await photo(image), let jpeg = RecipeImageProcessing.jpegData(from: data, maxPixelSize: Self.feedPhotoSize) else { continue }
            try? jpeg.write(to: feedImageURL(for: image), options: .atomic)
        }
        let kept = Set(snapshot.posts.compactMap(\.imageURL).map { feedImageURL(for: $0).lastPathComponent })
        for file in (try? fm.contentsOfDirectory(at: feedImagesDirectory, includingPropertiesForKeys: nil)) ?? [] where !kept.contains(file.lastPathComponent) {
            try? fm.removeItem(at: file)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: feedsURL, options: .atomic)
    }
}
