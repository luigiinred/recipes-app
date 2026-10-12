import Foundation

public enum RecipeTextParser {
    private enum Section { case header, ingredients, steps }

    private static let ingredientHeadings: Set<String> = ["ingredients", "ingredient"]
    private static let stepHeadings: Set<String> = ["method", "directions", "instructions", "steps", "preparation", "procedure"]

    /// With `requiresHeadings`, text without Ingredients/Method headings yields no ingredients or steps.
    public static func parse(_ text: String, requiresHeadings: Bool = false) -> Recipe {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let hasHeadings = lines.contains { heading(of: $0) != nil }
        let skipBody = requiresHeadings && !hasHeadings

        var title: String?
        var summary: [String] = []
        var ingredients: [String] = []
        var sections: [IngredientSection] = []
        var steps: [String] = []
        var servings: Int?
        var prep: Int?
        var cook: Int?
        var section = Section.header

        for line in lines {
            if let found = heading(of: line) {
                section = found
                continue
            }
            if let value = meta(line, keys: ["serves", "servings", "makes", "yield"]) {
                servings = servings ?? firstInt(in: value)
                continue
            }
            if let value = meta(line, keys: ["prep time", "prep", "preparation time"]) {
                prep = prep ?? DurationDetector.find(in: value).first.map { $0.seconds / 60 }
                continue
            }
            if let value = meta(line, keys: ["cook time", "cooking time", "cook", "bake"]) {
                cook = cook ?? DurationDetector.find(in: value).first.map { $0.seconds / 60 }
                continue
            }
            if title == nil {
                title = line
                continue
            }
            if skipBody { continue }
            let effective: Section = hasHeadings ? section : (looksLikeIngredient(line) ? .ingredients : .steps)
            switch effective {
            case .header:
                summary.append(line)
            case .ingredients:
                if let name = subheading(line) {
                    sections.append(IngredientSection(title: name, start: ingredients.count))
                } else {
                    ingredients.append(stripBullet(line))
                }
            case .steps:
                appendStep(line, to: &steps)
            }
        }

        return Recipe(
            title: title ?? "Scanned Recipe",
            summary: summary.joined(separator: " "),
            servings: servings,
            prepMinutes: prep,
            cookMinutes: cook,
            ingredients: ingredients,
            ingredientSections: RecipeStandards.standardSections(sections, ingredientCount: ingredients.count),
            steps: steps
        )
    }

    private static func heading(of line: String) -> Section? {
        let key = line.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":-–— ").union(.whitespaces))
        if ingredientHeadings.contains(key) { return .ingredients }
        if stepHeadings.contains(key) { return .steps }
        guard key.count < 40 else { return nil }
        if key.hasPrefix("ingredients") { return .ingredients }
        if ["instructions", "directions", "method", "how to make", "preparation"].contains(where: { key.hasPrefix($0) }) { return .steps }
        return nil
    }

    /// "For the sauce:" or "Cinnamon sugar" on a line of its own, between ingredients.
    static func subheading(_ line: String) -> String? {
        let text = stripBullet(line).trimmingCharacters(in: .whitespaces)
        guard text.count <= 40, !text.contains(where: \.isNumber), IngredientParser.split(text).quantity.isEmpty else { return nil }
        let name = text.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespaces))
        let lowered = name.lowercased()
        if text.hasSuffix(":") || lowered.hasPrefix("for the ") || lowered.hasPrefix("for ") { return name }
        return nil
    }

    private static func meta(_ line: String, keys: [String]) -> String? {
        let lowered = line.lowercased()
        for key in keys {
            guard lowered.hasPrefix(key) else { continue }
            let rest = line.dropFirst(key.count)
            if let first = rest.first, first.isLetter { continue }
            let value = rest.trimmingCharacters(in: CharacterSet(charactersIn: ": -").union(.whitespaces))
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func looksLikeIngredient(_ line: String) -> Bool {
        let stripped = stripBullet(line)
        return stripped.count < 70 && !IngredientParser.split(stripped).quantity.isEmpty && !startsWithStepNumber(stripped)
    }

    private static func startsWithStepNumber(_ line: String) -> Bool {
        line.range(of: #"^(step\s*)?\d+\s*[.):]\s"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func stripBullet(_ line: String) -> String {
        line.replacingOccurrences(of: #"^[•\-\*·●▪︎]\s*"#, with: "", options: .regularExpression)
    }

    private static func appendStep(_ line: String, to steps: inout [String]) {
        let numbered = startsWithStepNumber(line)
        let cleaned = line.replacingOccurrences(of: #"^(step\s*)?\d+\s*[.):]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
        if !numbered, let last = steps.last, let end = last.last, !".!?".contains(end) {
            steps[steps.count - 1] = last + " " + cleaned
        } else {
            steps.append(cleaned)
        }
    }

    private static func firstInt(in text: String) -> Int? {
        text.range(of: #"\d+"#, options: .regularExpression).flatMap { Int(text[$0]) }
    }
}
