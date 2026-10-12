import Foundation

public enum RecipeCollection: Hashable, Sendable {
    case all, recent, wantToCook, favorites, uncategorized
    case category(String)

    public static let smart: [RecipeCollection] = [.recent, .wantToCook, .favorites, .uncategorized]

    public var title: String {
        switch self {
        case .all: "All Recipes"
        case .recent: "Most Recent"
        case .wantToCook: "Want to Cook"
        case .favorites: "Favorites"
        case .uncategorized: "Uncategorized"
        case .category(let name): CategoryTree.components(name).last ?? name
        }
    }

    public var symbol: String {
        switch self {
        case .all: "book.closed"
        case .recent: "clock"
        case .wantToCook: "arrow.right.circle"
        case .favorites: "heart"
        case .uncategorized: "questionmark.folder"
        case .category: "tag"
        }
    }

    public func filter(_ recipes: [Recipe]) -> [Recipe] {
        switch self {
        case .all: recipes
        case .recent: Array(recipes.sorted { $0.createdAt > $1.createdAt }.prefix(20))
        case .wantToCook: recipes.filter(\.wantToCook)
        case .favorites: recipes.filter(\.isFavorite)
        case .uncategorized: recipes.filter { $0.tags.isEmpty }
        case .category(let name):
            recipes.filter { $0.tags.contains { CategoryTree.tag($0, isIn: name) } }
        }
    }
}
