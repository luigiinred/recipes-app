import Foundation

/// Words in Up Next that aren't a recipe yet, such as "eggs", until they're made an idea or a recipe is found for them.
public struct UpNextNote: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var queuedAt: Date
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, queuedAt: Date = Date(), createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.queuedAt = queuedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// One line of Up Next: a queued recipe or a note.
public enum UpNextItem: Identifiable, Hashable, Sendable {
    case recipe(Recipe)
    case note(UpNextNote)

    public var id: UUID {
        switch self {
        case .recipe(let recipe): recipe.id
        case .note(let note): note.id
        }
    }

    public var title: String {
        switch self {
        case .recipe(let recipe): recipe.title
        case .note(let note): note.title
        }
    }

    public var queuedAt: Date {
        switch self {
        case .recipe(let recipe): recipe.queuedAt ?? recipe.createdAt
        case .note(let note): note.queuedAt
        }
    }

    /// Queued recipes and notes together, in the order they joined.
    public static func queue(recipes: [Recipe], notes: [UpNextNote]) -> [UpNextItem] {
        let queued = RecipeCollection.wantToCook.filter(recipes).map(UpNextItem.recipe)
        return (queued + notes.map(UpNextItem.note)).enumerated()
            .sorted { ($0.element.queuedAt, $0.offset) < ($1.element.queuedAt, $1.offset) }
            .map(\.element)
    }
}
