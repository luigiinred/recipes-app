import Foundation

public struct DocumentStore<Item: Codable & Identifiable & Sendable>: Sendable where Item.ID == UUID {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Reading a file iCloud hasn't downloaded yet waits for it, so `progress` reports each file as it finishes.
    public func list(progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) throws -> [Item] {
        try ensureDirectory()
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
            .filter { $0.pathExtension == "json" || FileIO.isPlaceholder($0) }
        let decoder = RecipeCoding.makeDecoder()
        var items: [Item] = []
        progress(0, urls.count)
        for (index, url) in urls.enumerated() {
            defer { progress(index + 1, urls.count) }
            if FileIO.startDownloadIfPlaceholder(url, in: directory) { continue }
            guard let data = try? FileIO.read(url),
                  let item = try? decoder.decode(Item.self, from: data) else { continue }
            items.append(item)
        }
        return items
    }

    public func save(_ item: Item) throws {
        try ensureDirectory()
        try FileIO.write(try RecipeCoding.makeEncoder().encode(item), to: fileURL(for: item.id))
    }

    public func delete(_ item: Item) throws {
        try FileIO.remove(fileURL(for: item.id))
    }

    public func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
