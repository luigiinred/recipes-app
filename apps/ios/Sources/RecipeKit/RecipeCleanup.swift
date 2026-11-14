import Foundation

/// A tidier version of a recipe and a description of what changed, for the app to offer rather than apply on its own.
public struct RecipeCleanup: Sendable {
    public var recipe: Recipe
    public var changes: [String]
    /// Set when a step changed shape, so its video time and photo no longer line up.
    public var dropsStepExtras: Bool

    public var isEmpty: Bool { changes.isEmpty }

    /// "Tidy 3 ingredients and split the method into 6 steps."
    public var summary: String {
        guard let first = changes.first else { return "" }
        let sentence = changes.count == 1 ? first : changes.dropLast().joined(separator: ", ") + " and " + changes.last!
        return first.prefix(1).uppercased() + sentence.dropFirst() + "."
    }

    /// Standardizes the text, then uses Apple Intelligence, when it's on, to split long steps and group a long ingredient list.
    public static func suggest(for original: Recipe) async -> RecipeCleanup {
        var recipe = original.standardized()
        recipe.steps = await StepSplitter.split(recipe.steps)
        var grouped = false
        if recipe.ingredientSections.isEmpty,
           case .grouped(let list, let found) = await IngredientGrouper.group(title: recipe.title, ingredients: recipe.ingredients, steps: recipe.steps) {
            recipe.ingredients = list
            recipe.ingredientSections = found
            grouped = true
        }

        var changes: [String] = []
        let known = Set(original.ingredients)
        let tidied = recipe.ingredients.filter { !known.contains($0) }.count
        if tidied > 0 {
            changes.append("tidy \(tidied) \(tidied == 1 ? "ingredient" : "ingredients")")
        }
        let added = recipe.ingredientSections.count - original.ingredientSections.count
        if added > 0 {
            changes.append("\(grouped ? "group the ingredients into" : "add") \(added) \(added == 1 ? "section" : "sections")")
        }
        let originalSteps = original.steps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let resplit = recipe.steps.count != originalSteps.count
        if resplit {
            changes.append("split the method into \(recipe.steps.count) steps")
        } else if recipe.steps != original.steps {
            changes.append("tidy the steps")
        }
        if recipe.notes != original.notes { changes.append("move loose notes into Notes") }

        var dropsExtras = false
        if resplit, recipe.steps.count != recipe.stepTimestamps.count && !recipe.stepTimestamps.isEmpty
            || recipe.steps.count != recipe.stepImages.count && !recipe.stepImages.isEmpty {
            recipe.stepTimestamps = []
            recipe.stepImages = []
            dropsExtras = true
        }
        return RecipeCleanup(recipe: recipe, changes: changes, dropsStepExtras: dropsExtras)
    }
}

extension Recipe {
    /// A stable fingerprint of the parts a cleanup reads, so a recipe already checked isn't checked again until it changes.
    public var cleanupFingerprint: String {
        let sections = ingredientSections.map { "\($0.start):\($0.title)" }
        let parts = [title] + ingredients + ["§"] + sections + ["§"] + steps + ["§", notes]
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in parts.joined(separator: "\u{1F}").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return String(hash, radix: 36)
    }
}
