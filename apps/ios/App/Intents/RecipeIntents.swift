import AppIntents
import RecipeKit

struct SaveRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Recipe"
    static let description = IntentDescription(
        "Saves a recipe from a web page or YouTube video link, such as one someone sent you.",
        categoryName: "Recipes"
    )

    @Parameter(title: "Link", description: "A recipe page or YouTube video.")
    var url: URL

    static var parameterSummary: some ParameterSummary {
        Summary("Save the recipe at \(\.$url)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<RecipeEntity> & ProvidesDialog {
        let result = try await RecipeImporter.importResult(from: url)
        let library = IntentLibrary.current()
        let saved = try await Task.detached { try library.add(result) }.value
        let dialog: IntentDialog = result.isComplete
            ? "Saved \(saved.title)."
            : IntentDialog(stringLiteral: "Saved \(saved.title), but I couldn't find the full recipe. Open Recipes to finish it. \(result.message ?? "")")
        return .result(value: RecipeEntity(saved), dialog: dialog)
    }
}

struct FindRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Recipe"
    static let description = IntentDescription("Finds a recipe in your library.", categoryName: "Recipes")

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$recipe)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<RecipeEntity> & ProvidesDialog {
        .result(value: recipe, dialog: "Here's \(recipe.title).")
    }
}

struct OpenRecipeIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Recipe"

    @Parameter(title: "Recipe")
    var target: RecipeEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.recipeID = target.id
        return .result()
    }
}

struct StartCookingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Cooking"
    static let description = IntentDescription("Opens a recipe in cook mode.", categoryName: "Recipes")
    static let openAppWhenRun = true

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start cooking \(\.$recipe)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.cookRecipeID = recipe.id
        return .result()
    }
}

struct AddRecipeToGroceriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Ingredients to Groceries"
    static let description = IntentDescription("Adds a recipe's ingredients to your grocery list.", categoryName: "Groceries")

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add the ingredients of \(\.$recipe) to my groceries")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let library = IntentLibrary.current()
        let id = recipe.id
        let count = try await Task.detached { () -> Int in
            guard let found = try library.recipes.list().first(where: { $0.id == id }) else { return 0 }
            let existing = try library.groceries.list().filter { !$0.isChecked }
            var added = 0
            for text in found.ingredients {
                let item = GroceryItem(parsing: text, recipeID: found.id)
                if existing.contains(where: { $0.name.lowercased() == item.name.lowercased() && $0.quantity == item.quantity }) { continue }
                try library.groceries.save(item)
                added += 1
            }
            return added
        }.value
        return .result(dialog: count == 0 ? "Those ingredients are already on your list." : "Added \(count) items to your groceries.")
    }
}

struct RecipesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveRecipeIntent(),
            phrases: ["Save a recipe in \(.applicationName)", "Save this recipe in \(.applicationName)"],
            shortTitle: "Save Recipe", systemImageName: "square.and.arrow.down"
        )
        AppShortcut(
            intent: FindRecipeIntent(),
            phrases: ["Find \(\.$recipe) in \(.applicationName)", "Find a recipe in \(.applicationName)"],
            shortTitle: "Find Recipe", systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: StartCookingIntent(),
            phrases: ["Start cooking \(\.$recipe) in \(.applicationName)"],
            shortTitle: "Start Cooking", systemImageName: "flame"
        )
        AppShortcut(
            intent: AddRecipeToGroceriesIntent(),
            phrases: ["Add \(\.$recipe) to my groceries in \(.applicationName)"],
            shortTitle: "Add to Groceries", systemImageName: "checklist"
        )
    }
}
