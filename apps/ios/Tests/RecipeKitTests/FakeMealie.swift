import Foundation
@testable import RecipeKit

/// Mealie in memory, with the behaviors the sync depends on: a new recipe starts with placeholder content, renaming changes
/// the slug, and ratings and photos bump `updatedAt` like every other edit.
final class FakeMealie: MealieAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var clock = Date(timeIntervalSince1970: 1_700_000_000)
    private var recipes: [String: MealieObject] = [:]
    private var images: [String: Data] = [:]
    private var tagObjects: [MealieObject] = []
    private var ratingByRecipe: [String: MealieRating] = [:]
    private var plan: [Int: MealieObject] = [:]
    private var nextPlanID = 1
    private var lists: [MealieShoppingList] = []
    private var items: [String: [String: MealieObject]] = [:]
    var userID = "user-1"
    var failRecipeUpdates = false

    private func now() -> String {
        clock.addTimeInterval(1)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: clock)
    }

    private func slug(_ name: String) -> String {
        name.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
    }

    // MARK: Test access

    var recipeNames: [String] { lock.withLock { recipes.values.compactMap { $0.string("name") }.sorted() } }
    var planCount: Int { lock.withLock { plan.count } }
    var shoppingNotes: [String] { lock.withLock { items.values.flatMap { $0.values.compactMap { $0.string("note") } }.sorted() } }

    func remote(named name: String) -> MealieObject? { lock.withLock { recipes.values.first { $0.string("name") == name } } }

    /// Edits a recipe the way someone using Mealie would.
    func edit(_ name: String, _ change: (inout MealieObject) -> Void) {
        lock.withLock {
            guard let key = recipes.first(where: { $0.value.string("name") == name })?.key else { return }
            var object = recipes[key]!
            change(&object)
            object["slug"] = slug(object.string("name") ?? "")
            object["updatedAt"] = now()
            recipes[key] = object
        }
    }

    func add(name: String, ingredients: [String] = [], steps: [String] = []) {
        lock.withLock {
            let id = UUID().uuidString.lowercased()
            recipes[id] = [
                "id": id, "slug": slug(name), "name": name, "description": "", "updatedAt": now(), "createdAt": now(), "extras": MealieObject(),
                "recipeIngredient": ingredients.map { ["note": $0, "display": $0, "quantity": 0] as MealieObject },
                "recipeInstructions": steps.map { ["text": $0, "title": ""] as MealieObject },
                "tags": [MealieObject](), "recipeCategory": [MealieObject](), "notes": [MealieObject](),
            ]
        }
    }

    func remove(_ name: String) {
        lock.withLock {
            if let key = recipes.first(where: { $0.value.string("name") == name })?.key {
                recipes[key] = nil
                images[key] = nil
            }
        }
    }

    func setPhoto(_ name: String, _ data: Data) {
        lock.withLock {
            guard let key = recipes.first(where: { $0.value.string("name") == name })?.key else { return }
            images[key] = data
            recipes[key]?["image"] = UUID().uuidString.prefix(4).lowercased()
            recipes[key]?["updatedAt"] = now()
        }
    }

    func rating(of name: String) -> MealieRating? {
        lock.withLock { recipes.values.first { $0.string("name") == name }?.string("id").flatMap { ratingByRecipe[$0] } }
    }

    func addShoppingItem(note: String, checked: Bool = false) {
        lock.withLock {
            if lists.isEmpty { lists = [MealieShoppingList(id: "list-1", name: "Recipes")] }
            let id = UUID().uuidString.lowercased()
            items[lists[0].id, default: [:]][id] = ["id": id, "note": note, "quantity": 0, "checked": checked, "shoppingListId": lists[0].id]
        }
    }

    func addPlanEntry(date: String, type: String, title: String) {
        lock.withLock {
            plan[nextPlanID] = ["id": nextPlanID, "date": date, "entryType": type, "title": title, "text": "", "groupId": "g", "userId": userID]
            nextPlanID += 1
        }
    }

    // MARK: MealieAPI

    func currentUser() async throws -> MealieUser { MealieUser(id: userID, username: "tester") }

    func recipeList() async throws -> [MealieRecipeSummary] {
        lock.withLock {
            recipes.values.map { object in
                MealieRecipeSummary(
                    id: object.string("id")!, slug: object.string("slug")!,
                    updatedAt: MealieDate.parse(object.string("updatedAt")!)!, imageToken: object.string("image")
                )
            }
        }
    }

    func recipe(slug: String) async throws -> MealieObject {
        try lock.withLock {
            guard let object = recipes.values.first(where: { $0.string("slug") == slug }) else { throw MealieError.server(404, "Not found") }
            return object
        }
    }

    func createRecipe(name: String) async throws -> String {
        lock.withLock {
            let id = UUID().uuidString.lowercased()
            recipes[id] = [
                "id": id, "slug": slug(name), "name": name, "description": "", "updatedAt": now(), "createdAt": now(), "extras": MealieObject(),
                "recipeIngredient": [["note": "1 Cup Flour", "display": "1 Cup Flour", "quantity": 0] as MealieObject],
                "recipeInstructions": [["text": "Recipe steps as well as other fields", "title": ""] as MealieObject],
                "tags": [MealieObject](), "recipeCategory": [MealieObject](), "notes": [MealieObject](),
            ]
            return slug(name)
        }
    }

    func updateRecipe(slug: String, _ body: MealieObject) async throws -> MealieObject {
        try lock.withLock {
            if failRecipeUpdates { throw MealieError.server(500, "boom") }
            guard let key = recipes.first(where: { $0.value.string("slug") == slug })?.key else { throw MealieError.server(404, "Not found") }
            var object = body
            object["slug"] = self.slug(body.string("name") ?? "")
            object["updatedAt"] = now()
            if let image = recipes[key]?["image"] { object["image"] = image }
            recipes[key] = object
            return object
        }
    }

    func deleteRecipe(slug: String) async throws {
        lock.withLock {
            if let key = recipes.first(where: { $0.value.string("slug") == slug })?.key {
                recipes[key] = nil
                images[key] = nil
            }
        }
    }

    func recipeImage(id: String) async throws -> Data? { lock.withLock { images[id] } }

    func setRecipeImage(slug: String, data: Data) async throws {
        lock.withLock {
            guard let key = recipes.first(where: { $0.value.string("slug") == slug })?.key else { return }
            images[key] = data
            recipes[key]?["image"] = UUID().uuidString.prefix(4).lowercased()
            recipes[key]?["updatedAt"] = now()
        }
    }

    func deleteRecipeImage(slug: String) async throws {
        lock.withLock {
            guard let key = recipes.first(where: { $0.value.string("slug") == slug })?.key else { return }
            images[key] = nil
            recipes[key]?["image"] = nil
            recipes[key]?["updatedAt"] = now()
        }
    }

    func tags() async throws -> [MealieObject] { lock.withLock { tagObjects } }

    func createTag(name: String) async throws -> MealieObject {
        lock.withLock {
            let tag: MealieObject = ["id": UUID().uuidString.lowercased(), "name": name, "slug": slug(name)]
            tagObjects.append(tag)
            return tag
        }
    }

    func categories() async throws -> [MealieObject] { [] }

    func ratings() async throws -> [String: MealieRating] { lock.withLock { ratingByRecipe } }

    func setRating(userID: String, slug: String, rating: Double?, isFavorite: Bool) async throws {
        lock.withLock {
            guard let key = recipes.first(where: { $0.value.string("slug") == slug })?.key else { return }
            ratingByRecipe[key] = MealieRating(rating: rating.flatMap { $0 > 0 ? $0 : nil }, isFavorite: isFavorite)
            recipes[key]?["updatedAt"] = now()
        }
    }

    func mealPlanEntries() async throws -> [MealieObject] { lock.withLock { plan.values.sorted { ($0["id"] as! Int) < ($1["id"] as! Int) } } }

    func createMealPlanEntry(_ body: MealieObject) async throws -> MealieObject {
        lock.withLock {
            var entry = body
            entry["id"] = nextPlanID
            plan[nextPlanID] = entry
            nextPlanID += 1
            return entry
        }
    }

    func updateMealPlanEntry(id: Int, _ body: MealieObject) async throws -> MealieObject {
        lock.withLock {
            plan[id] = body
            return body
        }
    }

    func deleteMealPlanEntry(id: Int) async throws { _ = lock.withLock { plan.removeValue(forKey: id) } }

    func shoppingLists() async throws -> [MealieShoppingList] { lock.withLock { lists } }

    func createShoppingList(name: String) async throws -> MealieShoppingList {
        lock.withLock {
            let list = MealieShoppingList(id: "list-\(lists.count + 1)", name: name)
            lists.append(list)
            return list
        }
    }

    func shoppingItems(list: String) async throws -> [MealieObject] {
        lock.withLock { (items[list] ?? [:]).values.sorted { $0.string("id")! < $1.string("id")! } }
    }

    func createShoppingItem(_ body: MealieObject) async throws -> MealieObject {
        lock.withLock {
            var item = body
            let id = UUID().uuidString.lowercased()
            item["id"] = id
            items[body.string("shoppingListId") ?? "", default: [:]][id] = item
            return item
        }
    }

    func updateShoppingItem(id: String, _ body: MealieObject) async throws -> MealieObject {
        lock.withLock {
            items[body.string("shoppingListId") ?? "", default: [:]][id] = body
            return body
        }
    }

    func deleteShoppingItem(id: String) async throws {
        lock.withLock { for key in items.keys { items[key]?[id] = nil } }
    }
}
