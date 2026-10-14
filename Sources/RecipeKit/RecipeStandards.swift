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

    /// The part of the rules the on-device model needs when writing a recipe from captions, kept short for its small context window.
    public static let extractionRules = """
    - ingredients: one per ingredient, with an amount and a unit from the list when the cook says them, such as "1 1/2 cups flour". \
    Use digits and fractions like 1/2. Put preparation after a comma in the item.
    - steps: short imperative sentences, with no numbering.
    """

    private static let stepPrefix = try! NSRegularExpression(pattern: #"^\s*(?:(?:step\s*)?\d+\s*[.):\-–]+\s*|[-–•*]\s+)"#, options: .caseInsensitive)

    /// A page or video title without the site name tacked on: "Best Cookies | Preppy Kitchen", "Cookies Recipe by Tasty".
    public static func importedTitle(_ text: String) -> String {
        var title = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let bar = title.range(of: " | ") { title = String(title[..<bar.lowerBound]) }
        if let by = title.range(of: #" Recipe by [^|]+$"#, options: [.regularExpression, .caseInsensitive]) { title.removeSubrange(by) }
        return title.isEmpty ? text : title
    }

    /// Sections in order, with blank titles and sections that hold no ingredients dropped; a later heading at the same spot wins.
    public static func standardSections(_ sections: [IngredientSection], ingredientCount: Int) -> [IngredientSection] {
        var result: [IngredientSection] = []
        for section in sections.sorted(by: { $0.start < $1.start }) {
            let title = section.title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            let trimmed = title.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespaces))
            guard !trimmed.isEmpty, section.start >= 0, section.start < ingredientCount else { continue }
            if result.last?.start == section.start { result.removeLast() }
            result.append(IngredientSection(title: trimmed, start: section.start))
        }
        return result
    }

    /// "DRESSING:" or "For the sauce" on a line of its own inside an ingredient list.
    static func ingredientHeading(_ text: String) -> String? {
        let trimmed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !trimmed.isEmpty, trimmed.count <= 40, !trimmed.contains(where: \.isNumber) else { return nil }
        let name = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespaces))
        guard !name.isEmpty, trimmed.hasSuffix(":") || name.lowercased().hasPrefix("for the ") else { return nil }
        let isShouting = name == name.uppercased() && name.contains(where: \.isLetter)
        return isShouting ? name.capitalized : name
    }

    /// A step that really holds several numbered ones ("... 1. Brown the beef. 2. Add the peppers. 3. ..."), and any text
    /// before the first number. Nil unless the numbers run 1, 2, 3 in order.
    static func splitNumberedSteps(_ text: String) -> (preamble: String, steps: [String])? {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![^\s])(\d{1,2})[.)]\s+(?=[A-Z"“(])"#) else { return nil }
        var markers: [NSTextCheckingResult] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range(at: 1), in: text), Int(text[range]) == markers.count + 1 else { continue }
            markers.append(match)
        }
        guard markers.count >= 3 else { return nil }
        func piece(_ from: Int, _ to: Int) -> String {
            guard let low = Range(NSRange(location: from, length: to - from), in: text) else { return "" }
            return text[low].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let preamble = piece(0, markers[0].range.location)
        let steps = markers.indices.map { index in
            piece(markers[index].range.location + markers[index].range.length, index + 1 < markers.count ? markers[index + 1].range.location : (text as NSString).length)
        }
        return (preamble, steps.filter { !$0.isEmpty })
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
        var cleanedIngredients: [String] = []
        var headings: [IngredientSection] = []
        var landing: [Int] = []
        for text in ingredients {
            landing.append(cleanedIngredients.count)
            let parsed = Ingredient(parsing: text).text
            if parsed.isEmpty { continue }
            if let title = RecipeStandards.ingredientHeading(parsed) {
                headings.append(IngredientSection(title: title, start: cleanedIngredients.count))
            } else {
                cleanedIngredients.append(parsed)
            }
        }
        recipe.ingredients = cleanedIngredients
        let moved = ingredientSections.map { IngredientSection(title: $0.title, start: landing.indices.contains($0.start) ? landing[$0.start] : cleanedIngredients.count) }
        recipe.ingredientSections = RecipeStandards.standardSections(moved + headings, ingredientCount: cleanedIngredients.count)

        var expanded: [(text: String, origin: Int, isFirst: Bool)] = []
        var preface: [String] = []
        for (index, step) in steps.enumerated() {
            if let split = RecipeStandards.splitNumberedSteps(step) {
                if !split.preamble.isEmpty { preface.append(split.preamble) }
                expanded += split.steps.enumerated().map { ($1, index, $0 == 0) }
            } else {
                expanded.append((step, index, true))
            }
        }
        let cleaned = expanded.map { RecipeStandards.standardStep($0.text) }
        let kept = cleaned.indices.filter { !cleaned[$0].isEmpty }
        recipe.steps = kept.map { cleaned[$0] }
        if kept.count != steps.count || expanded.count != steps.count {
            if !stepTimestamps.isEmpty { recipe.stepTimestamps = kept.map { expanded[$0].isFirst ? timestamp(forStep: expanded[$0].origin) : nil } }
            if !stepImages.isEmpty { recipe.stepImages = kept.map { expanded[$0].isFirst ? stepImage(forStep: expanded[$0].origin) : nil } }
        }
        if recipe.stepImages.allSatisfy({ $0 == nil }) { recipe.stepImages = [] }
        if !preface.isEmpty {
            let extra = preface.joined(separator: "\n")
            if !notes.contains(extra) { recipe.notes = notes.isEmpty ? extra : notes + "\n\n" + extra }
        }

        recipe.rating = rating.flatMap { (1...5).contains($0) ? $0 : nil }
        if !wantToCook { recipe.queuedAt = nil }
        recipe.tags = RecipeTags.standardized(tags)
        return recipe
    }
}
