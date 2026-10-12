import Foundation

public struct Library: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var recipes: RecipeStore { RecipeStore(directory: root.appendingPathComponent("Recipes")) }
    public var mealPlan: DocumentStore<MealPlanEntry> { DocumentStore(directory: root.appendingPathComponent("Calendar")) }
    public var images: RecipeImageStore { RecipeImageStore(directory: root.appendingPathComponent("Images")) }
    public var feeds: DocumentStore<Feed> { DocumentStore(directory: root.appendingPathComponent("Feeds")) }
    public var groceries: DocumentStore<GroceryItem> { DocumentStore(directory: root.appendingPathComponent("Groceries")) }

    @discardableResult
    public func add(_ result: ImportResult) throws -> Recipe {
        let saved = try recipes.save(result.recipe)
        if let data = result.imageData { try images.save(data, for: saved.id) }
        return saved
    }

    public func deleteRecipe(_ recipe: Recipe) throws {
        try recipes.delete(recipe)
        try images.delete(for: recipe.id)
    }
}
