import CryptoKit
import Foundation

/// The newest posts and card photos of feeds, kept on disk so they read offline.
public struct FeedCache: Sendable {
    public static let photoSize = 800

    public struct Snapshot: Codable, Sendable {
        public var entries: [FeedEntry]
        public var fetchedAt: Date
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var standard: FeedCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FeedCache(directory: base.appendingPathComponent("FeedCache", isDirectory: true))
    }

    private var postsDirectory: URL { directory.appendingPathComponent("Posts", isDirectory: true) }
    private var photosDirectory: URL { directory.appendingPathComponent("Photos", isDirectory: true) }

    private static func key(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func postsFile(for feed: String) -> URL { postsDirectory.appendingPathComponent(Self.key(feed) + ".json") }
    private func photoFile(for image: URL) -> URL { photosDirectory.appendingPathComponent(Self.key(image.absoluteString) + ".jpg") }

    public func snapshot(for feed: String) -> Snapshot? {
        guard let data = try? Data(contentsOf: postsFile(for: feed)) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    public func save(_ entries: [FeedEntry], for feed: String, at date: Date = Date()) throws {
        try FileManager.default.createDirectory(at: postsDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(Snapshot(entries: entries, fetchedAt: date)).write(to: postsFile(for: feed), options: .atomic)
    }

    public func photo(for image: URL) -> Data? { try? Data(contentsOf: photoFile(for: image)) }

    public func hasPhoto(for image: URL) -> Bool { FileManager.default.fileExists(atPath: photoFile(for: image).path) }

    public func savePhoto(_ data: Data, for image: URL) throws {
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        try data.write(to: photoFile(for: image), options: .atomic)
    }

    /// The most recent time any feed was saved.
    public var lastUpdated: Date? {
        let files = (try? FileManager.default.contentsOfDirectory(at: postsDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }.max()
    }

    public var byteCount: Int {
        let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey])?.allObjects as? [URL] ?? []
        return files.compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }.reduce(0, +)
    }

    /// Drops posts for feeds not in `feeds`, and photos none of the kept posts show.
    public func prune(keeping feeds: [String]) {
        let keptPosts = Set(feeds.map { postsFile(for: $0).lastPathComponent })
        let posts = (try? FileManager.default.contentsOfDirectory(at: postsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in posts where !keptPosts.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
        let keptPhotos = Set(feeds.compactMap(snapshot(for:)).flatMap(\.entries).compactMap(\.imageURL).map { photoFile(for: $0).lastPathComponent })
        let photos = (try? FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in photos where !keptPhotos.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
    }

    public func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Fetches each feed's newest posts and their card photos, keeping what's already saved when a fetch fails.
    public func refresh(_ feeds: [Feed], photosPerFeed: Int = 12) async -> [String: [FeedEntry]] {
        await withTaskGroup(of: (String, [FeedEntry]?).self) { group in
            for feed in feeds {
                group.addTask {
                    guard let url = URL(string: feed.url), let entries = try? await FeedService.fetch(url).entries else { return (feed.url, nil) }
                    try? save(entries, for: feed.url)
                    for image in entries.prefix(photosPerFeed).compactMap(\.imageURL) where !hasPhoto(for: image) {
                        guard let (data, _) = try? await URLSession.shared.data(from: image),
                              let jpeg = RecipeImageProcessing.jpegData(from: data, maxPixelSize: Self.photoSize) else { continue }
                        try? savePhoto(jpeg, for: image)
                    }
                    return (feed.url, entries)
                }
            }
            var fetched: [String: [FeedEntry]] = [:]
            for await (url, entries) in group { if let entries { fetched[url] = entries } }
            prune(keeping: feeds.map(\.url))
            return fetched
        }
    }
}
