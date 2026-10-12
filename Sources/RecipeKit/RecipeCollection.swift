import Foundation

/// How recipes are marked as liked: a heart, or one to five stars.
public enum RatingStyle: String, CaseIterable, Sendable {
    case favorites, stars

    public var title: String { self == .favorites ? "Favorites" : "Star Ratings" }
}

public enum RecipeCollection: Hashable, Sendable {
    case all, recent, wantToCook, favorites, topRated, uncategorized
    case category(String)

    /// The built-in collections, with the liked-recipes one following the rating style. The queue lives in the planner.
    public static func smart(for style: RatingStyle) -> [RecipeCollection] {
        [.recent, style == .stars ? .topRated : .favorites, .uncategorized]
    }

    public var title: String {
        switch self {
        case .all: "All Recipes"
        case .recent: "Most Recent"
        case .wantToCook: "Up Next"
        case .favorites: "Favorites"
        case .topRated: "Top Rated"
        case .uncategorized: "Uncategorized"
        case .category(let name): CategoryTree.components(name).last ?? name
        }
    }

    public var symbol: String {
        switch self {
        case .all: "book.closed"
        case .recent: "clock"
        case .wantToCook: "text.line.first.and.arrowtriangle.forward"
        case .favorites: "heart"
        case .topRated: "star"
        case .uncategorized: "questionmark.folder"
        case .category: "tag"
        }
    }

    public func filter(_ recipes: [Recipe]) -> [Recipe] {
        switch self {
        case .all: recipes
        case .recent: Array(recipes.sorted { $0.createdAt > $1.createdAt }.prefix(20))
        case .wantToCook: recipes.filter(\.wantToCook).sorted { ($0.queuedAt ?? $0.createdAt) < ($1.queuedAt ?? $1.createdAt) }
        case .favorites: recipes.filter(\.isFavorite)
        case .topRated: recipes.filter { ($0.rating ?? 0) >= 4 }.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .uncategorized: recipes.filter { $0.tags.isEmpty }
        case .category(let name):
            recipes.filter { $0.tags.contains { CategoryTree.tag($0, isIn: name) } }
        }
    }
}
