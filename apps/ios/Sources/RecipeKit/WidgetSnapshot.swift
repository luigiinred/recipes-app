import Foundation

/// What the home screen widgets show, written by the app into the shared app group and read by the widget extension.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public struct Dish: Codable, Equatable, Identifiable, Sendable {
        public var id: UUID
        public var title: String
        public var minutes: Int?
        public var hasImage: Bool

        public init(id: UUID, title: String, minutes: Int? = nil, hasImage: Bool = false) {
            self.id = id
            self.title = title
            self.minutes = minutes
            self.hasImage = hasImage
        }
    }

    public struct PlannedMeal: Codable, Equatable, Identifiable, Sendable {
        public var id: UUID
        public var recipeID: UUID?
        public var title: String
        public var day: String
        public var meal: Meal

        public init(id: UUID, recipeID: UUID?, title: String, day: String, meal: Meal) {
            self.id = id
            self.recipeID = recipeID
            self.title = title
            self.day = day
            self.meal = meal
        }
    }

    public struct Item: Codable, Equatable, Identifiable, Sendable {
        public var id: UUID
        public var name: String
        public var quantity: String

        public init(id: UUID, name: String, quantity: String = "") {
            self.id = id
            self.name = name
            self.quantity = quantity
        }
    }

    public static let maxUpNext = 8
    public static let maxToBuy = 24
    public static let maxPool = 24
    public static let planDays = 14

    public var meals: [PlannedMeal]
    public var upNext: [Dish]
    public var toBuy: [Item]
    public var checkedCount: Int
    /// The recipes the random-recipe widget draws from.
    public var pool: [Dish]
    /// The accent color chosen in Settings, as a hex string.
    public var accentHex: String?

    public init(
        meals: [PlannedMeal] = [], upNext: [Dish] = [], toBuy: [Item] = [], checkedCount: Int = 0, pool: [Dish] = [],
        accentHex: String? = nil
    ) {
        self.meals = meals
        self.upNext = upNext
        self.toBuy = toBuy
        self.checkedCount = checkedCount
        self.pool = pool
        self.accentHex = accentHex
    }

    public static let empty = WidgetSnapshot()

    /// Every dish the widgets can show a photo for.
    public var dishes: [Dish] { upNext + pool }

    public static func make(
        recipes: [Recipe], mealPlan: [MealPlanEntry], groceries: [GroceryItem], imageIDs: Set<UUID>,
        today: Date = Date(), calendar: Calendar = .current
    ) -> WidgetSnapshot {
        func dish(_ recipe: Recipe) -> Dish {
            Dish(id: recipe.id, title: recipe.title, minutes: recipe.totalMinutes, hasImage: imageIDs.contains(recipe.id))
        }
        let start = calendar.startOfDay(for: today)
        let first = DayKey.string(from: start, calendar: calendar)
        let last = DayKey.string(from: calendar.date(byAdding: .day, value: planDays, to: start) ?? start, calendar: calendar)
        let meals = mealPlan
            .filter { $0.day >= first && $0.day < last }
            .sorted { ($0.day, $0.meal.order, $0.title) < ($1.day, $1.meal.order, $1.title) }
            .map { PlannedMeal(id: $0.id, recipeID: $0.recipeID, title: $0.title, day: $0.day, meal: $0.meal) }
        let upNext = RecipeCollection.wantToCook.filter(recipes).prefix(maxUpNext).map(dish)
        let toBuy = groceries
            .filter { !$0.isChecked }
            .sorted { ($0.createdAt, $0.name) < ($1.createdAt, $1.name) }
            .prefix(maxToBuy)
            .map { Item(id: $0.id, name: $0.name, quantity: $0.quantity) }
        let pool = recipes
            .filter { !$0.isIdea }
            .sorted { (imageIDs.contains($0.id) ? 0 : 1, $0.id.uuidString) < (imageIDs.contains($1.id) ? 0 : 1, $1.id.uuidString) }
            .prefix(maxPool)
            .map(dish)
        return WidgetSnapshot(meals: meals, upNext: Array(upNext), toBuy: Array(toBuy), checkedCount: groceries.filter(\.isChecked).count, pool: Array(pool))
    }

    public func meals(on day: Date, calendar: Calendar = .current) -> [PlannedMeal] {
        let key = DayKey.string(from: day, calendar: calendar)
        return meals.filter { $0.day == key }
    }

    /// A pool recipe that stays the same for `hours` at a time, so the widget changes on a rhythm instead of at every refresh.
    public func randomDish(at date: Date, hours: Int = 6, calendar: Calendar = .current) -> Dish? {
        guard !pool.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let slot = day * (24 / max(hours, 1)) + calendar.component(.hour, from: date) / max(hours, 1)
        return pool[Self.scramble(slot) % pool.count]
    }

    private static func scramble(_ value: Int) -> Int {
        var x = UInt64(truncatingIfNeeded: value) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 29
        return Int(x % UInt64(Int.max))
    }
}

/// The app group folder holding the snapshot and the photos that go with it.
public struct WidgetStore: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    /// `RECIPES_APP_GROUP`, else the `RecipesAppGroup` Info.plist key the app and widget targets set from `.env`.
    public static var groupIdentifier: String? {
        if let id = ProcessInfo.processInfo.environment["RECIPES_APP_GROUP"], !id.isEmpty { return id }
        let id = Bundle.main.object(forInfoDictionaryKey: "RecipesAppGroup") as? String
        return id?.hasPrefix("$(") == false && id?.isEmpty == false ? id : nil
    }

    public static var shared: WidgetStore? {
        groupIdentifier
            .flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
            .map { WidgetStore(directory: $0.appendingPathComponent("Widgets", isDirectory: true)) }
    }

    private var snapshotURL: URL { directory.appendingPathComponent("snapshot.json") }
    private var imagesDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }

    public func imageURL(for id: UUID) -> URL { imagesDirectory.appendingPathComponent("\(id.uuidString).jpg") }

    public func load() -> WidgetSnapshot {
        (try? Data(contentsOf: snapshotURL)).flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) } ?? .empty
    }

    public func save(_ snapshot: WidgetSnapshot) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: snapshotURL, options: .atomic)
    }

    public func hasImage(for id: UUID) -> Bool { FileManager.default.fileExists(atPath: imageURL(for: id).path) }

    public func saveImage(_ data: Data, for id: UUID) throws {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try data.write(to: imageURL(for: id), options: .atomic)
    }

    /// Drops the photos of recipes the widgets no longer show.
    public func pruneImages(keeping ids: Set<UUID>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where UUID(uuidString: file.deletingPathExtension().lastPathComponent).map({ !ids.contains($0) }) ?? true {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
