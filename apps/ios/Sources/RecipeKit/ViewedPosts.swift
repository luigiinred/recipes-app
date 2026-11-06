import Foundation

/// Feed posts that have been read, by post id, with when each was marked.
public struct ViewedPosts: Codable, Equatable, Sendable {
    public static let limit = 5000

    public private(set) var dates: [String: Date] = [:]

    public init() {}

    public var count: Int { dates.count }
    public var ids: Set<String> { Set(dates.keys) }

    public func contains(_ id: String) -> Bool { dates[id] != nil }

    /// Marks posts viewed, forgetting the oldest marks past `limit`.
    public mutating func insert(_ ids: some Sequence<String>, at date: Date = Date()) {
        for id in ids where dates[id] == nil { dates[id] = date }
        guard dates.count > Self.limit else { return }
        let oldest = dates.sorted { $0.value < $1.value }.prefix(dates.count - Self.limit)
        for (id, _) in oldest { dates[id] = nil }
    }

    public mutating func remove(_ ids: some Sequence<String>) {
        for id in ids { dates[id] = nil }
    }
}

public struct ViewedPostsStore: Sendable {
    public let file: URL

    public init(file: URL) {
        self.file = file
    }

    public static var standard: ViewedPostsStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ViewedPostsStore(file: base.appendingPathComponent("ViewedPosts.json"))
    }

    public func load() -> ViewedPosts {
        guard let data = try? Data(contentsOf: file) else { return ViewedPosts() }
        return (try? JSONDecoder().decode(ViewedPosts.self, from: data)) ?? ViewedPosts()
    }

    public func save(_ posts: ViewedPosts) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(posts).write(to: file, options: .atomic)
    }
}
