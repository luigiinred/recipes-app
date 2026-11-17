import Foundation

public struct DocumentStore<Item: Codable & Identifiable & Sendable>: Sendable where Item.ID == UUID {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Files iCloud hasn't downloaded yet are fetched in the background and left out, so what's on this device lists without waiting.
    /// `found` gets what's been read so far, from the first file on, so a caller can show it before the rest arrive.
    /// Without `coordinated`, files are read without waiting on iCloud, for a first look at what's already on the device.
    public func list(progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }, found: ([Item]) -> Void = { _ in },
                     coordinated: Bool = true) throws -> [Item] {
        try ensureDirectory()
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey], options: [])
            .filter { $0.pathExtension == "json" || FileIO.isPlaceholder($0) }
        let decoder = RecipeCoding.makeDecoder()
        var items: [Item] = []
        progress(0, urls.count)
        for (index, url) in urls.enumerated() {
            defer { progress(index + 1, urls.count) }
            if FileIO.startDownloadIfPlaceholder(url, in: directory) || FileIO.startDownloadIfNotLocal(url) { continue }
            guard let data = try? (coordinated ? FileIO.read(url) : Data(contentsOf: url)),
                  let item = try? decoder.decode(Item.self, from: data) else { continue }
            items.append(item)
            if items.count == 1 || items.count.isMultiple(of: 10) { found(items) }
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
