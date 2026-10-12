import Foundation

/// The `recipes://recipe/<id>` link the share extension uses to open a saved recipe in the app.
enum RecipeLink {
    static func url(for id: UUID) -> URL { URL(string: "recipes://recipe/\(id.uuidString.lowercased())")! }

    static func recipeID(from url: URL) -> UUID? {
        guard url.scheme == "recipes", url.host == "recipe" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
