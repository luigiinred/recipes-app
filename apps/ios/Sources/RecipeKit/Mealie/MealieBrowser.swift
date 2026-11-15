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
    private let group: String?

    /// With a `group` and no token, reads that group's public recipes, as anyone without an account can.
    public init(server: URL, token: String, group: String? = nil, session: URLSession = .shared) {
        client = MealieClient(server: server, token: token, session: session)
        self.group = group
    }

    public func currentUser() async throws -> MealieUser { try await client.currentUser() }

    /// The signed-in user's name, or nil for a public group, once the server has answered.
    public func check() async throws -> String? {
        if let group {
            _ = try await client.publicRecipeSummaries(group: group)
            return nil
        }
        return try await client.currentUser().username
    }

    /// Every recipe without its ingredients and steps, which `recipe(slug:)` fills in.
    public func recipes() async throws -> [Entry] {
        let summaries = if let group { try await client.publicRecipeSummaries(group: group) } else { try await client.recipeSummaries() }
        return summaries.compactMap(Self.entry)
    }

    public func recipe(slug: String) async throws -> Recipe? {
        let remote = if let group { try await client.publicRecipe(group: group, slug: slug) } else { try await client.recipe(slug: slug) }
        return Self.entry(from: remote)?.recipe
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
