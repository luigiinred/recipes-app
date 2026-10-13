import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Sorts a long ingredient list into sections such as "Dough" and "Topping".
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
                You organize a recipe's ingredient list into sections. A section is one component of the dish that the method \
                makes separately and then combines, such as the main food, a sauce, a dressing, a filling or a topping. \
                Name each section after what it makes, like "Pancakes", "Syrup" or "Cinnamon sugar", never "Dough" or "Topping" \
                unless the recipe really is a dough or topping. Only split when the method clearly makes separate components; \
                otherwise use a single section name for every ingredient. Write one assignment for every ingredient, in order, \
                using the same section name for ingredients that belong together.

                Example. Ingredients: 1 flour, 2 eggs, 3 milk, 4 maple syrup, 5 butter. Method: whisk the flour, eggs and milk and fry \
                the pancakes; warm the syrup with the butter and pour over. Assignments: 1 Pancakes, 2 Pancakes, 3 Pancakes, 4 Syrup, 5 Syrup.
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
    @Guide(description: "One sentence naming the separate things the method makes before combining them.")
    var components: String
    @Guide(description: "One assignment per ingredient, in the order listed.")
    var assignments: [GeneratedAssignment]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedAssignment {
    @Guide(description: "The ingredient's number as listed.")
    var number: Int
    @Guide(description: "A short name for what its section makes, such as Pancakes, Syrup or Cinnamon sugar.")
    var section: String
}
#endif
