import Foundation

public enum RecipeError: LocalizedError, Equatable {
    case notFound(String)
    case ambiguous(String, [String])
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let query):
            return "No recipe matches \"\(query)\"."
        case .ambiguous(let query, let matches):
            return "\"\(query)\" matches several recipes:\n" + matches.map { "  \($0)" }.joined(separator: "\n")
        case .invalid(let reason):
            return reason
        }
    }
}

public struct RecipeStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func list() throws -> [Recipe] {
        try ensureDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: []
        )
        var recipes: [Recipe] = []
        let decoder = RecipeCoding.makeDecoder()
        for url in urls {
            let name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                let real = String(name.dropFirst().dropLast(".icloud".count))
                try? FileManager.default.startDownloadingUbiquitousItem(
                    at: directory.appendingPathComponent(real)
                )
                continue
            }
            guard url.pathExtension == "json",
                  let data = try? coordinatedRead(url),
                  let recipe = try? decoder.decode(Recipe.self, from: data) else { continue }
            recipes.append(recipe)
        }
        return recipes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @discardableResult
    public func save(_ recipe: Recipe) throws -> Recipe {
        var recipe = recipe
        recipe.title = recipe.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipe.title.isEmpty else { throw RecipeError.invalid("A recipe needs a title.") }
        recipe.updatedAt = Date()
        try ensureDirectory()
        let data = try RecipeCoding.makeEncoder().encode(recipe)
        try coordinatedWrite(data, to: fileURL(for: recipe.id))
        return recipe
    }

    public func delete(_ recipe: Recipe) throws {
        let url = fileURL(for: recipe.id)
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError, byAccessor: { (url: URL) in
            result = Result { try FileManager.default.removeItem(at: url) }
        })
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    public func find(_ query: String) throws -> Recipe {
        let recipes = try list()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = q.lowercased()

        if let exact = recipes.first(where: { $0.id.uuidString.lowercased() == lowered }) { return exact }
        let titleMatches = recipes.filter { $0.title.lowercased() == lowered }
        if titleMatches.count == 1 { return titleMatches[0] }

        let idPrefix = recipes.filter { $0.id.uuidString.lowercased().hasPrefix(lowered) }
        let candidates = titleMatches.isEmpty
            ? (idPrefix.isEmpty ? recipes.filter { $0.title.localizedCaseInsensitiveContains(q) } : idPrefix)
            : titleMatches
        switch candidates.count {
        case 0: throw RecipeError.notFound(query)
        case 1: return candidates[0]
        default:
            throw RecipeError.ambiguous(query, candidates.map { "\($0.id.uuidString.prefix(8).lowercased())  \($0.title)" })
        }
    }

    public func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString.lowercased()).json")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func coordinatedRead(_ url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError, byAccessor: { (url: URL) in
            result = Result { try Data(contentsOf: url) }
        })
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError, byAccessor: { (url: URL) in
            result = Result { try data.write(to: url, options: .atomic) }
        })
        if let coordinationError { throw coordinationError }
        try result.get()
    }
}
