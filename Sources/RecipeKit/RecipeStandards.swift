import Foundation

public enum RecipeStandards {
    /// The house style, handed to language models and agents so they write recipes the app doesn't have to fix.
    public static let rules = """
    Recipe format:
    - title: the dish name in title case, with no site name or "Recipe" suffix.
    - summary: one sentence describing the dish.
    - ingredients: one per ingredient, written "quantity unit item" such as "1 1/2 cups flour" or "2 cloves garlic, minced". \
    Use digits and fractions like 1/2 (no ½ or words). Units come from: \(IngredientUnit.allCases.map(\.abbreviation).joined(separator: ", ")). \
    Leave the unit out for whole items ("3 eggs"). Put preparation after a comma. Never list equipment or repeat quantities in the item.
    - steps: each one a short imperative sentence or two ("Whisk the eggs."), with no numbering, bullets or "Step 1".
    - tags: only generic words, at most four: the main ingredient (\(RecipeTags.groups[0].tags.joined(separator: ", "))), \
    the diet (Vegetarian, Vegan) and the course (\(RecipeTags.groups[2].tags.joined(separator: ", "))). \
    Never use ingredient lists, cuisines, adjectives or site keywords as tags.
    """

    private static let stepPrefix = try! NSRegularExpression(pattern: #"^\s*(?:(?:step\s*)?\d+\s*[.):\-–]+\s*|[-–•*]\s+)"#, options: .caseInsensitive)

    /// A page or video title without the site name tacked on: "Best Cookies | Preppy Kitchen", "Cookies Recipe by Tasty".
    public static func importedTitle(_ text: String) -> String {
        var title = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let bar = title.range(of: " | ") { title = String(title[..<bar.lowerBound]) }
        if let by = title.range(of: #" Recipe by [^|]+$"#, options: [.regularExpression, .caseInsensitive]) { title.removeSubrange(by) }
        return title.isEmpty ? text : title
    }

    public static func standardStep(_ text: String) -> String {
        var step = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let range = NSRange(step.startIndex..., in: step)
        if let match = stepPrefix.firstMatch(in: step, range: range), let swiftRange = Range(match.range, in: step) {
            step.removeSubrange(swiftRange)
        }
        guard let first = step.first else { return "" }
        if first.isLowercase { step = first.uppercased() + step.dropFirst() }
        if let last = step.last, last.isLetter || last.isNumber || last == ")" { step += "." }
        return step
    }
}

extension Recipe {
    /// This recipe with ingredients, steps and tags written in the standard form. Safe to apply more than once.
    public func standardized() -> Recipe {
        var recipe = self
        recipe.title = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        recipe.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.ingredients = ingredients.map { Ingredient(parsing: $0).text }.filter { !$0.isEmpty }

        let cleaned = steps.map(RecipeStandards.standardStep)
        let kept = cleaned.indices.filter { !cleaned[$0].isEmpty }
        recipe.steps = kept.map { cleaned[$0] }
        if kept.count != cleaned.count {
            if !stepTimestamps.isEmpty { recipe.stepTimestamps = kept.map { timestamp(forStep: $0) } }
            if !stepImages.isEmpty { recipe.stepImages = kept.map { stepImage(forStep: $0) } }
        }
        if recipe.stepImages.allSatisfy({ $0 == nil }) { recipe.stepImages = [] }

        recipe.rating = rating.flatMap { (1...5).contains($0) ? $0 : nil }
        if !wantToCook { recipe.queuedAt = nil }
        recipe.tags = RecipeTags.standardized(tags)
        return recipe
    }
}
