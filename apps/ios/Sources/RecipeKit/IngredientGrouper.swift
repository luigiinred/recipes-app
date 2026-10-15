import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Splits an ingredient list into sections only where the recipe makes distinct parts, such as a salad and its dressing.
public enum IngredientGrouper {
    public struct Group: Sendable {
        public var title: String
        /// Zero-based positions in the original list.
        public var members: [Int]

        public init(title: String, members: [Int]) {
            self.title = title
            self.members = members
        }
    }

    public enum Outcome: Sendable {
        case grouped(ingredients: [String], sections: [IngredientSection])
        /// The ingredients all belong together; nothing to split.
        case unchanged
        case unavailable(AppleIntelligence.Status)
        case failed(String)
    }

    /// Puts each group's ingredients together, in their original order, and returns the headings. Ingredients nobody claimed
    /// land in a final "Other" group. Nil when there would be fewer than two sections.
    public static func apply(_ groups: [Group], to ingredients: [String]) -> (ingredients: [String], sections: [IngredientSection])? {
        var claimed = Set<Int>()
        var cleaned: [(title: String, members: [Int])] = []
        for group in groups {
            let title = group.title.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespacesAndNewlines))
            let members = Array(Set(group.members)).filter { ingredients.indices.contains($0) && !claimed.contains($0) }.sorted()
            claimed.formUnion(members)
            if !members.isEmpty, !title.isEmpty { cleaned.append((title, members)) }
        }
        let leftovers = ingredients.indices.filter { !claimed.contains($0) }
        if !leftovers.isEmpty { cleaned.append(("Other", leftovers)) }
        guard cleaned.count >= 2 else { return nil }

        var ordered: [String] = []
        var sections: [IngredientSection] = []
        for group in cleaned {
            sections.append(IngredientSection(title: group.title, start: ordered.count))
            ordered += group.members.map { ingredients[$0] }
        }
        return (ordered, sections)
    }

    /// One group per section name, in order of first appearance. An ingredient the model skipped joins the section of the
    /// one before it (or after it, at the start of the list).
    static func groups(from assignments: [(index: Int, section: String)], count: Int) -> [Group] {
        var labels = [String?](repeating: nil, count: count)
        for (index, section) in assignments where labels.indices.contains(index) && labels[index] == nil {
            let name = section.trimmingCharacters(in: CharacterSet(charactersIn: ":").union(.whitespacesAndNewlines))
            if !name.isEmpty { labels[index] = name }
        }
        for index in labels.indices where labels[index] == nil && index > 0 { labels[index] = labels[index - 1] }
        for index in labels.indices.reversed() where labels[index] == nil && index + 1 < count { labels[index] = labels[index + 1] }
        var order: [String] = []
        var members: [String: [Int]] = [:]
        for (index, label) in labels.enumerated() {
            guard let label else { continue }
            let key = label.lowercased()
            if members[key] == nil { order.append(label) }
            members[key, default: []].append(index)
        }
        return order.map { Group(title: $0, members: members[$0.lowercased()] ?? []) }
    }

    public static func group(title: String, ingredients: [String], steps: [String]) async -> Outcome {
        let status = AppleIntelligence.status
        guard status.isAvailable else { return .unavailable(status) }
        guard ingredients.count >= 4 else { return .unchanged }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
                You decide whether a recipe's ingredient list needs sections. Most recipes do not: use one section name for every \
                ingredient unless the method makes a distinct part of the meal separately and then combines or serves it with the \
                rest, such as a salad's dressing, a pie's filling and crust, or a dish's sauce. Never group by type of ingredient \
                (spices, produce, dairy, pantry) or by when an ingredient is added; seasonings, oil and garnishes stay with the \
                part of the meal they flavor. Name each section after the part of the meal it makes, like "Salad" and "Dressing". \
                Write one assignment for every ingredient, in order, using the same section name for ingredients that belong together.

                Example 1. Ingredients: 1 romaine, 2 cucumber, 3 olive oil, 4 lemon juice, 5 Dijon mustard, 6 salt. Method: toss the \
                romaine and cucumber; whisk the oil, lemon juice, mustard and salt and pour over. Assignments: 1 Salad, 2 Salad, \
                3 Dressing, 4 Dressing, 5 Dressing, 6 Dressing.

                Example 2. Ingredients: 1 chicken thighs, 2 onion, 3 garlic, 4 paprika, 5 cumin, 6 salt, 7 olive oil. Method: season \
                the chicken, then cook it with the onion and garlic in the oil. Assignments: 1 Chicken, 2 Chicken, 3 Chicken, \
                4 Chicken, 5 Chicken, 6 Chicken, 7 Chicken.
                """)
            let list = ingredients.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            let method = steps.joined(separator: " ").prefix(1800)
            do {
                let response = try await session.respond(
                    to: "Recipe: \(title)\n\nIngredients:\n\(list)\n\nMethod: \(method)",
                    generating: GeneratedGrouping.self
                )
                let groups = groups(from: response.content.assignments.map { ($0.number - 1, $0.section) }, count: ingredients.count)
                if let result = apply(groups, to: ingredients) { return .grouped(ingredients: result.ingredients, sections: result.sections) }
                return .unchanged
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .exceededContextWindowSize: return .failed("The recipe is too long for the on-device model.")
                case .guardrailViolation: return .failed("Apple Intelligence declined to read this recipe.")
                case .unsupportedLanguageOrLocale: return .failed("Apple Intelligence doesn't support this recipe's language.")
                case .assetsUnavailable: return .unavailable(.modelNotReady)
                default: return .failed(error.localizedDescription)
                }
            } catch {
                return .failed(error.localizedDescription)
            }
        }
        #endif
        return .unavailable(.osTooOld)
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedGrouping {
    @Guide(description: "One sentence naming the distinct parts of the meal the method makes separately, or saying it is a single dish.")
    var components: String
    @Guide(description: "One assignment per ingredient, in the order listed.")
    var assignments: [GeneratedAssignment]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedAssignment {
    @Guide(description: "The ingredient's number as listed.")
    var number: Int
    @Guide(description: "A short name for the part of the meal its section makes, such as Salad or Dressing. Reuse one name for a single dish.")
    var section: String
}
#endif
