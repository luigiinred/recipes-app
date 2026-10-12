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
    public var directory: URL { documents.directory }
    private let documents: DocumentStore<Recipe>

    public init(directory: URL) {
        documents = DocumentStore(directory: directory)
    }

    public func list() throws -> [Recipe] {
        try documents.list().sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @discardableResult
    public func save(_ recipe: Recipe) throws -> Recipe {
        var recipe = recipe.standardized()
        guard !recipe.title.isEmpty else { throw RecipeError.invalid("A recipe needs a title.") }
        recipe.updatedAt = Date()
        try documents.save(recipe)
        return recipe
    }

    public func delete(_ recipe: Recipe) throws {
        try documents.delete(recipe)
    }

    public func fileURL(for id: UUID) -> URL {
        documents.fileURL(for: id)
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
}
