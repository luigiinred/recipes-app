import Foundation
import RecipeKit

/// How the Groceries list is split into sections.
enum GroceryGrouping: String, CaseIterable {
    case none, aisle, recipe

    var title: String {
        switch self {
        case .none: "None"
        case .aisle: "Aisle"
        case .recipe: "Recipe"
        }
    }
}

/// Each grocery's aisle: a keyword guess at once, then Apple Intelligence for the ones it couldn't place, remembered by name.
@MainActor
final class GroceryAisles: ObservableObject {
    static let shared = GroceryAisles()

    @Published private var answers: [String: GroceryAisle]
    private var asked: Set<String> = []
    private let defaults: UserDefaults
    private static let storeKey = "groceryAisleAnswers"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: Self.storeKey) as? [String: String] ?? [:]
        answers = saved.compactMapValues(GroceryAisle.init(rawValue:))
    }

    func aisle(for item: GroceryItem) -> GroceryAisle {
        let key = GroceryAisle.key(for: item.name)
        if let known = answers[key] { return known }
        return GroceryAisle.guess(item.name)
    }

    /// Asks the model about every item the keywords couldn't place, once per name.
    func sortUnknown(_ items: [GroceryItem]) async {
        var names: [String: String] = [:]
        for item in items {
            let key = GroceryAisle.key(for: item.name)
            guard answers[key] == nil, !asked.contains(key), GroceryAisle.guess(item.name) == .other else { continue }
            names[key] = item.name
        }
        guard !names.isEmpty else { return }
        asked.formUnion(names.keys)
        let keys = Array(names.keys)
        guard let sorted = await GroceryAisleSorter.sort(keys.map { names[$0]! }) else { return }
        for key in keys {
            if let aisle = sorted[names[key]!] { answers[key] = aisle }
        }
        defaults.set(answers.mapValues(\.rawValue), forKey: Self.storeKey)
    }
}
