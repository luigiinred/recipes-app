import ArgumentParser
import Foundation
import RecipeKit

private func resolveID<Item: Identifiable>(_ items: [Item], _ query: String, label: (Item) -> String) throws -> Item where Item.ID == UUID {
    let lowered = query.lowercased()
    let matches = items.filter { $0.id.uuidString.lowercased().hasPrefix(lowered) }
    switch matches.count {
    case 0: throw RecipeError.notFound(query)
    case 1: return matches[0]
    default: throw RecipeError.ambiguous(query, matches.map { "\($0.id.uuidString.prefix(8).lowercased())  \(label($0))" })
    }
}

private func parseDay(_ text: String) throws -> String {
    let calendar = Calendar.current
    switch text.lowercased() {
    case "today": return DayKey.string(from: Date())
    case "tomorrow": return DayKey.string(from: calendar.date(byAdding: .day, value: 1, to: Date())!)
    default:
        guard DayKey.date(from: text) != nil else {
            throw ValidationError("Use YYYY-MM-DD, today, or tomorrow (got \"\(text)\").")
        }
        return text
    }
}

private func short(_ id: UUID) -> String { String(id.uuidString.prefix(8)).lowercased() }

struct PlanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plan",
        abstract: "Read and edit the meal calendar.",
        subcommands: [PlanList.self, PlanAdd.self, PlanRemove.self],
        defaultSubcommand: PlanList.self
    )
}

struct PlanList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List planned meals, soonest first.")
    @OptionGroup var library: LibraryOptions
    @Option(name: .long, help: "First day (YYYY-MM-DD, today, tomorrow). Default: today.") var from = "today"
    @Option(name: .long, help: "How many days to show.") var days = 14
    @Flag(name: .long) var json = false

    func run() throws {
        let start = try parseDay(from)
        let end = DayKey.string(from: Calendar.current.date(byAdding: .day, value: days, to: DayKey.date(from: start)!)!)
        let entries = try library.library.mealPlan.list()
            .filter { $0.day >= start && $0.day < end }
            .sorted { ($0.day, $0.meal.order) < ($1.day, $1.meal.order) }
        if json { try printJSON(entries); return }
        if entries.isEmpty { print("Nothing planned."); return }
        for entry in entries { print("\(entry.day)  \(entry.meal.title.padding(toLength: 9, withPad: " ", startingAt: 0))\(entry.title)  (\(short(entry.id)))") }
    }
}

struct PlanAdd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Put a recipe on a day.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String
    @Option(name: .long, help: "YYYY-MM-DD, today, or tomorrow.") var date: String
    @Option(name: .long, help: "breakfast, lunch, dinner, or snack.") var meal: Meal = .dinner
    @Flag(name: .long) var json = false

    func run() throws {
        let found = try library.store.find(recipe)
        let entry = MealPlanEntry(recipeID: found.id, title: found.title, day: try parseDay(date), meal: meal)
        try library.library.mealPlan.save(entry)
        if json { try printJSON(entry) } else { print("Planned \(entry.day) \(meal.title): \(found.title)  (\(short(entry.id)))") }
    }
}

struct PlanRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove a planned meal by id.")
    @OptionGroup var library: LibraryOptions
    @Argument var id: String

    func run() throws {
        let store = library.library.mealPlan
        let entry = try resolveID(try store.list(), id) { $0.title }
        try store.delete(entry)
        print("Removed \(entry.day) \(entry.title)")
    }
}

extension Meal: ExpressibleByArgument {}

struct GroceriesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "groceries",
        abstract: "Read and edit the grocery list.",
        subcommands: [GroceryList.self, GroceryAdd.self, GroceryAddRecipe.self, GroceryCheck.self, GroceryRemove.self, GroceryClear.self],
        defaultSubcommand: GroceryList.self
    )
}

private func printGroceries(_ items: [GroceryItem]) {
    if items.isEmpty { print("Grocery list is empty."); return }
    for item in items {
        let quantity = item.quantity.isEmpty ? "" : " — \(item.quantity)"
        print("[\(item.isChecked ? "x" : " ")] \(item.name)\(quantity)  (\(short(item.id)))")
    }
}

private func sortedGroceries(_ items: [GroceryItem]) -> [GroceryItem] {
    items.sorted { ($0.isChecked ? 1 : 0, $0.createdAt) < ($1.isChecked ? 1 : 0, $1.createdAt) }
}

struct GroceryList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List groceries (unchecked first).")
    @OptionGroup var library: LibraryOptions
    @Flag(name: .long, help: "Output as JSON.") var json = false

    func run() throws {
        let items = sortedGroceries(try library.library.groceries.list())
        if json { try printJSON(items) } else { printGroceries(items) }
    }
}

struct GroceryAdd: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add items, e.g. `groceries add \"2 cups milk\" eggs`.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Item text; a leading quantity is split out automatically.") var items: [String]

    func run() throws {
        let store = library.library.groceries
        for text in items {
            let item = GroceryItem(parsing: text)
            try store.save(item)
            print("Added \(item.name)  (\(short(item.id)))")
        }
    }
}

struct GroceryAddRecipe: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add-recipe", abstract: "Add every ingredient of a recipe.")
    @OptionGroup var library: LibraryOptions
    @Argument(help: "Recipe id, id prefix, or title.") var recipe: String

    func run() throws {
        let found = try library.store.find(recipe)
        let store = library.library.groceries
        let existing = try store.list().filter { !$0.isChecked }
        var added = 0
        for text in found.ingredients {
            let item = GroceryItem(parsing: text, recipeID: found.id)
            if existing.contains(where: { $0.name.lowercased() == item.name.lowercased() && $0.quantity == item.quantity }) { continue }
            try store.save(item)
            added += 1
        }
        print("Added \(added) item(s) from \(found.title)")
    }
}

struct GroceryCheck: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "check", abstract: "Check off an item (or --undo).")
    @OptionGroup var library: LibraryOptions
    @Argument var id: String
    @Flag(name: .long) var undo = false

    func run() throws {
        let store = library.library.groceries
        var item = try resolveID(try store.list(), id) { $0.name }
        item.isChecked = !undo
        item.updatedAt = Date()
        try store.save(item)
        print("\(undo ? "Unchecked" : "Checked") \(item.name)")
    }
}

struct GroceryRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove an item by id.")
    @OptionGroup var library: LibraryOptions
    @Argument var id: String

    func run() throws {
        let store = library.library.groceries
        let item = try resolveID(try store.list(), id) { $0.name }
        try store.delete(item)
        print("Removed \(item.name)")
    }
}

struct GroceryClear: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "clear", abstract: "Remove all checked items.")
    @OptionGroup var library: LibraryOptions

    func run() throws {
        let store = library.library.groceries
        let done = try store.list().filter(\.isChecked)
        for item in done { try store.delete(item) }
        print("Cleared \(done.count) item(s)")
    }
}
