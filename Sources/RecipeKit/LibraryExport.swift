import Foundation

public struct LibraryExport: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var recipes: [Recipe]
    public var mealPlan: [MealPlanEntry]
    public var groceries: [GroceryItem]
    public var feeds: [Feed]
    /// JPEG photos (base64 in the JSON), keyed by the lowercased id of the recipe they belong to.
    public var images: [String: Data]
    /// JPEG step photos (base64 in the JSON), keyed by the lowercased id listed in a recipe's `stepImages`.
    public var stepImages: [String: Data]

    public init(
        version: Int = LibraryExport.currentVersion,
        exportedAt: Date = Date(),
        recipes: [Recipe] = [],
        mealPlan: [MealPlanEntry] = [],
        groceries: [GroceryItem] = [],
        feeds: [Feed] = [],
        images: [String: Data] = [:],
        stepImages: [String: Data] = [:]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.recipes = recipes
        self.mealPlan = mealPlan
        self.groceries = groceries
        self.feeds = feeds
        self.images = images
        self.stepImages = stepImages
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        recipes = try c.decode([Recipe].self, forKey: .recipes)
        mealPlan = try c.decode([MealPlanEntry].self, forKey: .mealPlan)
        groceries = try c.decode([GroceryItem].self, forKey: .groceries)
        feeds = try c.decode([Feed].self, forKey: .feeds)
        images = try c.decode([String: Data].self, forKey: .images)
        stepImages = try c.decodeIfPresent([String: Data].self, forKey: .stepImages) ?? [:]
    }

    public func jsonData() throws -> Data {
        try RecipeCoding.makeEncoder().encode(self)
    }
}

extension Library {
    public func export(at date: Date = Date()) throws -> LibraryExport {
        let recipes = try recipes.list()
        var images: [String: Data] = [:]
        for recipe in recipes {
            if let data = self.images.data(for: recipe.id) { images[recipe.id.uuidString.lowercased()] = data }
        }
        var stepImages: [String: Data] = [:]
        for id in recipes.flatMap(\.stepImages).compactMap({ $0 }) {
            if let data = self.stepImages.data(for: id) { stepImages[id.uuidString.lowercased()] = data }
        }
        return LibraryExport(
            exportedAt: date,
            recipes: recipes,
            mealPlan: try mealPlan.list().sorted { ($0.day, $0.meal.order) < ($1.day, $1.meal.order) },
            groceries: try groceries.list().sorted { $0.createdAt < $1.createdAt },
            feeds: try feeds.list().sorted { $0.createdAt < $1.createdAt },
            images: images,
            stepImages: stepImages
        )
    }
}
