import AppIntents
import CoreSpotlight
import RecipeKit

struct RecipeEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    static let defaultQuery = RecipeEntityQuery()

    let id: UUID

    @Property(title: "Title") var title: String
    @Property(title: "Summary") var summary: String
    @Property(title: "Categories") var categories: [String]

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: summary.isEmpty ? nil : "\(summary)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .content)
        set.title = title
        set.contentDescription = summary
        set.keywords = categories
        return set
    }

    init(_ recipe: Recipe) {
        id = recipe.id
        title = recipe.title
        summary = recipe.summary
        categories = recipe.tags
    }
}

struct RecipeEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [RecipeEntity] {
        try await recipes().filter { identifiers.contains($0.id) }.map(RecipeEntity.init)
    }

    func entities(matching string: String) async throws -> [RecipeEntity] {
        try await recipes().filter { $0.matches(string) }.map(RecipeEntity.init)
    }

    func suggestedEntities() async throws -> [RecipeEntity] {
        try await recipes().sorted { $0.updatedAt > $1.updatedAt }.prefix(10).map(RecipeEntity.init)
    }

    private func recipes() async throws -> [Recipe] {
        let library = IntentLibrary.current()
        return try await Task.detached { try library.recipes.list() }.value
    }
}

enum IntentLibrary {
    /// Same folder the app uses, so intents see the same recipes with or without the app running.
    static func current() -> Library { RecipeLocation.resolveForApp().library }
}
