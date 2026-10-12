import Foundation

/// Gathers what a picture of a dish would show: its name, main ingredients, how it's cooked, and how it's served.
public enum RecipeImagePrompt {
    private static let pantryStaples: Set<String> = [
        "salt", "pepper", "black pepper", "water", "oil", "olive oil", "vegetable oil", "canola oil", "sugar", "flour",
        "butter", "baking powder", "baking soda", "vanilla", "vanilla extract", "cooking spray", "ice",
    ]

    private static let cookingMethods: [(word: String, phrase: String)] = [
        ("bake", "baked"), ("roast", "roasted"), ("grill", "grilled"), ("fry", "fried"), ("sauté", "sautéed"), ("saute", "sautéed"),
        ("simmer", "simmered"), ("poach", "poached"), ("braise", "braised"), ("steam", "steamed"), ("boil", "boiled"),
        ("sear", "seared"), ("broil", "broiled"), ("smoke", "smoked"), ("whisk", "whisked"), ("blend", "blended"),
        ("stew", "stewed"), ("toast", "toasted"), ("caramelize", "caramelized"), ("marinate", "marinated"),
    ]

    public static func description(for recipe: Recipe) -> String {
        var parts = ["\(recipe.title)."]
        let summary = recipe.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty { parts.append(summary) }

        let ingredients = mainIngredients(of: recipe)
        if !ingredients.isEmpty { parts.append("Made with " + ingredients.joined(separator: ", ") + ".") }

        let methods = cooking(in: recipe)
        if !methods.isEmpty { parts.append("The dish is " + methods.joined(separator: " and ") + ".") }

        if let serving = serving(in: recipe) { parts.append(serving) }

        let categories = recipe.tags.map(CategoryTree.displayName).filter { $0.caseInsensitiveCompare("YouTube") != .orderedSame }
        if !categories.isEmpty { parts.append("Category: " + categories.joined(separator: ", ") + ".") }
        return parts.joined(separator: " ")
    }

    static func mainIngredients(of recipe: Recipe, limit: Int = 8) -> [String] {
        var names: [String] = []
        for text in recipe.ingredients {
            var name = IngredientParser.split(text).name.lowercased()
            name = name.replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
            name = name.split(separator: ",").first.map(String.init) ?? name
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !pantryStaples.contains(name), !name.hasPrefix("to taste"), !names.contains(name) else { continue }
            names.append(name)
            if names.count == limit { break }
        }
        return names
    }

    static func cooking(in recipe: Recipe) -> [String] {
        let steps = recipe.steps.joined(separator: " ").lowercased()
        var found: [String] = []
        for method in cookingMethods where steps.contains(method.word) && !found.contains(method.phrase) {
            found.append(method.phrase)
            if found.count == 2 { break }
        }
        return found
    }

    static func serving(in recipe: Recipe) -> String? {
        for step in recipe.steps.reversed() {
            let sentences = step.split(whereSeparator: { ".!".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }
            if let sentence = sentences.first(where: { s in
                ["serve", "garnish", "top with", "scatter", "sprinkle", "drizzle"].contains { s.lowercased().contains($0) }
            }) {
                return "Presented: " + sentence + "."
            }
        }
        return nil
    }
}
