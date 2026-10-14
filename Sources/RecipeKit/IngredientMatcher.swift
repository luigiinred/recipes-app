import Foundation

/// Works out which ingredients a step uses by looking for their names in the step's text.
public enum IngredientMatcher {
    private static let fillers: Set<String> = [
        "fresh", "large", "small", "medium", "dried", "dry", "ground", "whole", "extra", "virgin", "plain", "unsalted", "salted",
        "cold", "hot", "warm", "good", "quality", "freshly", "finely", "roughly", "coarsely", "thinly", "boneless", "skinless",
        "ripe", "firm", "optional", "chopped", "diced", "sliced", "minced", "grated", "crushed",
    ]

    /// Positions in `ingredients` that the step mentions, in list order.
    public static func indices(in step: String, ingredients: [String]) -> [Int] {
        let stepWords = words(in: step)
        guard !stepWords.isEmpty, !ingredients.isEmpty else { return [] }

        let names = ingredients.map { nameWords(of: $0) }
        var headCount: [String: Int] = [:]
        for name in names { if let head = name.last { headCount[head, default: 0] += 1 } }

        var matched = Set<Int>()
        var claimed = Set<Int>()
        // Longer names go first so "tomato paste" claims its words before "tomatoes" can.
        let longestFirst = names.indices.sorted { names[$0].count > names[$1].count }
        for index in longestFirst where !names[index].isEmpty {
            let name = names[index]
            let range = phraseRange(stepWords, name, blocked: claimed)
                ?? (name.count >= 3 ? phraseRange(stepWords, Array(name.suffix(2)), blocked: claimed) : nil)
            if let range {
                matched.insert(index)
                claimed.formUnion(range)
            }
        }
        // Words already part of a longer match ("tomato" in "tomato paste") don't point at another ingredient.
        let remaining = Set(stepWords.indices.filter { !claimed.contains($0) }.map { stepWords[$0] })
        let matchedHeads = Set(matched.compactMap { names[$0].last })
        for (index, name) in names.enumerated() where !matched.contains(index) {
            guard let head = name.last, head.count >= 3, !matchedHeads.contains(head),
                  (headCount[head] ?? 0) <= 2, remaining.contains(head) else { continue }
            matched.insert(index)
        }
        return matched.sorted()
    }

    /// Where the step names the ingredients it uses, for highlighting: the longest form of each name that appears.
    public static func mentions(in step: String, ingredients: [String]) -> [Range<String.Index>] {
        var taken: [Range<String.Index>] = []
        let candidates = indices(in: step, ingredients: ingredients).flatMap { index -> [(Int, [String])] in
            let name = rawNameWords(of: ingredients[index])
            return [name, Array(name.suffix(2)), Array(name.suffix(1))].enumerated().compactMap { $0.element.isEmpty ? nil : ($0.offset, $0.element) }
        }
        for (_, words) in candidates.sorted(by: { $0.1.count > $1.1.count }) {
            let pattern = "\\b" + words.map(wordPattern).joined(separator: "\\s+") + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for match in regex.matches(in: step, range: NSRange(step.startIndex..., in: step)) {
                guard let range = Range(match.range, in: step), !taken.contains(where: { $0.overlaps(range) }) else { continue }
                taken.append(range)
            }
        }
        return taken.sorted { $0.lowerBound < $1.lowerBound }
    }

    private static func rawNameWords(of ingredient: String) -> [String] {
        let name = Ingredient(parsing: ingredient).name
            .replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        let all = name.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 2 }
        let meaningful = all.filter { !fillers.contains($0) }
        return meaningful.isEmpty ? all : meaningful
    }

    private static func wordPattern(_ word: String) -> String {
        let stem = singular(word)
        if stem.hasSuffix("y"), stem.count > 2 { return NSRegularExpression.escapedPattern(for: String(stem.dropLast())) + "(?:y|ies)" }
        return NSRegularExpression.escapedPattern(for: stem) + "(?:e?s)?"
    }

    private static func nameWords(of ingredient: String) -> [String] {
        let name = Ingredient(parsing: ingredient).name
            .replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        let all = words(in: name)
        let meaningful = all.filter { !fillers.contains($0) }
        return meaningful.isEmpty ? all : meaningful
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map { singular(String($0)) }.filter { $0.count >= 2 }
    }

    private static func singular(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.count > 4, word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.count > 4, ["ches", "shes", "sses", "xes"].contains(where: { word.hasSuffix($0) }) { return String(word.dropLast(2)) }
        if word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") { return String(word.dropLast()) }
        return word
    }

    private static func phraseRange(_ words: [String], _ phrase: [String], blocked: Set<Int>) -> Range<Int>? {
        guard !phrase.isEmpty, words.count >= phrase.count else { return nil }
        for start in 0...(words.count - phrase.count) {
            let range = start..<(start + phrase.count)
            if Array(words[range]) == phrase, blocked.isDisjoint(with: range) { return range }
        }
        return nil
    }
}
