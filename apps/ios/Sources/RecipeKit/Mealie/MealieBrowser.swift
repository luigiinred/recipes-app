import Foundation

/// Reads someone else's Mealie recipes to browse in Discover. Nothing is ever written back. Ratings, favorites and the
/// Up Next queue belong to whoever made the token, so they're left out.
public struct MealieBrowser: Sendable {
    public struct Entry: Sendable, Equatable {
        public var recipe: Recipe
        public var slug: String
        public var hasImage: Bool
    }

    private let client: MealieClient

    public init(server: URL, token: String) {
        client = MealieClient(server: server, token: token)
    }

    public func currentUser() async throws -> MealieUser { try await client.currentUser() }

    /// Every recipe without its ingredients and steps, which `recipe(slug:)` fills in.
    public func recipes() async throws -> [Entry] {
        try await client.recipeSummaries().compactMap(Self.entry)
    }

    public func recipe(slug: String) async throws -> Recipe? {
        Self.entry(from: try await client.recipe(slug: slug))?.recipe
    }

    public func image(for id: UUID, thumbnail: Bool) async -> Data? {
        try? await client.recipeImage(id: id.uuidString.lowercased(), file: thumbnail ? "min-original.webp" : "original.webp")
    }

    /// A browsed recipe keeps Mealie's id, so its photo can be found from it.
    static func entry(from remote: MealieObject) -> Entry? {
        guard let id = remote.string("id").flatMap(UUID.init(uuidString:)), let slug = remote.string("slug") else { return nil }
        var recipe = MealieRecipeMapping.recipe(from: remote, rating: nil, existing: nil, id: id)
        recipe.wantToCook = false
        recipe.queuedAt = nil
        return Entry(recipe: recipe, slug: slug, hasImage: remote.string("image")?.trimmed.nonEmpty != nil)
    }

    /// The recipe as a new one of your own, unlinked from the server it was browsed on.
    public static func copy(of recipe: Recipe, now: Date = Date()) -> Recipe {
        var copy = recipe
        copy.id = UUID()
        copy.createdAt = now
        copy.updatedAt = now
        copy.timeline = []
        copy.rating = nil
        copy.isFavorite = false
        copy.wantToCook = false
        copy.queuedAt = nil
        copy.stepImages = []
        return copy
    }
}
