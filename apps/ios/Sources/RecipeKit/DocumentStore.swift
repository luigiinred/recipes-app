import Foundation

public struct DocumentStore<Item: Codable & Identifiable & Sendable>: Sendable where Item.ID == UUID {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func list() throws -> [Item] {
        try ensureDirectory()
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
        let decoder = RecipeCoding.makeDecoder()
        var items: [Item] = []
        for url in urls {
            if FileIO.startDownloadIfPlaceholder(url, in: directory) { continue }
            guard url.pathExtension == "json",
                  let data = try? FileIO.read(url),
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
