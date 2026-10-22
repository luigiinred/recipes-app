import Foundation

enum AppDestination { case plan, groceries }

/// The `recipes://recipe/<id>` link the share extension uses to open a saved recipe, and `recipes://cook/<id>` for cook mode.
enum RecipeLink {
    static func url(for id: UUID) -> URL { URL(string: "recipes://recipe/\(id.uuidString.lowercased())")! }

    static func cookURL(for id: UUID) -> URL { URL(string: "recipes://cook/\(id.uuidString.lowercased())")! }

    static func destination(from url: URL) -> AppDestination? {
        guard url.scheme == "recipes" else { return nil }
        switch url.host {
        case "plan": return .plan
        case "groceries": return .groceries
        default: return nil
        }
    }

    static func cookRecipeID(from url: URL) -> UUID? {
        guard url.scheme == "recipes", url.host == "cook" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    static func recipeID(from url: URL) -> UUID? {
        guard url.scheme == "recipes", url.host == "recipe" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
