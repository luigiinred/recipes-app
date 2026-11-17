import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Where a grocery is found in a store, in the order a trip through one usually goes.
public enum GroceryAisle: String, CaseIterable, Codable, Sendable {
    case produce, bakery, meat, seafood, dairy, frozen, pantry, spices, drinks, household, other

    public var title: String {
        switch self {
        case .produce: "Produce"
        case .bakery: "Bakery"
        case .meat: "Meat"
        case .seafood: "Seafood"
        case .dairy: "Dairy & Eggs"
        case .frozen: "Frozen"
        case .pantry: "Pantry"
        case .spices: "Spices & Baking"
        case .drinks: "Drinks"
        case .household: "Household"
        case .other: "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .produce: "carrot"
        case .bakery: "birthday.cake"
        case .meat: "fork.knife"
        case .seafood: "fish"
        case .dairy: "drop"
        case .frozen: "snowflake"
        case .pantry: "takeoutbag.and.cup.and.straw"
        case .spices: "leaf"
        case .drinks: "cup.and.saucer"
        case .household: "house"
        case .other: "basket"
        }
    }

    /// The lookup key for a grocery's name, so "2 Limes" and "lime" share one answer.
    public static func key(for name: String) -> String {
        name.lowercased().split { !$0.isLetter }.map(singular).joined(separator: " ")
    }

    private static func singular(_ word: Substring) -> String {
        let word = String(word)
        if word.hasSuffix("ies") { return word.dropLast(3) + "y" }
        if word.hasSuffix("oes") || word.hasSuffix("ches") { return String(word.dropLast(2)) }
        if word.hasSuffix("s"), !word.hasSuffix("ss") { return String(word.dropLast()) }
        return word
    }

    /// A quick guess from the words in the name; `.other` when none are known.
    public static func guess(_ name: String) -> GroceryAisle {
        let words = key(for: name).split(separator: " ").map(String.init)
        if words.contains("frozen") { return .frozen }
        // Later words name the thing ("chicken stock" is pantry, not meat), so they're checked first.
        for (index, word) in words.enumerated().reversed() {
            if index > 0, let aisle = keywords["\(words[index - 1]) \(word)"] { return aisle }
            if let aisle = keywords[word] { return aisle }
        }
        return .other
    }

    private static let keywords: [String: GroceryAisle] = {
        var table: [String: GroceryAisle] = [:]
        func add(_ aisle: GroceryAisle, _ words: String) {
            for word in words.split(separator: ",") { table[word.trimmingCharacters(in: .whitespaces)] = aisle }
        }
        add(.produce, "apple, avocado, banana, basil, bean sprout, beet, berry, blueberry, broccoli, cabbage, carrot, cauliflower, celery, chard, cherry, chili, chive, cilantro, corn, cucumber, dill, eggplant, fennel, garlic, ginger, grape, herb, jalapeno, kale, leek, lemon, lettuce, lime, mango, mint, mushroom, onion, orange, parsley, peach, pear, pepper, potato, pumpkin, radish, rosemary, sage, scallion, shallot, spinach, squash, strawberry, thyme, tomato, zucchini, arugula, asparagus, bok choy, okra, plum, pineapple, watermelon, melon, sweet potato, yam, romaine, pea, green bean, bell pepper, spring onion, berry, cherry tomato")
        add(.bakery, "bagel, baguette, bread, brioche, bun, ciabatta, croissant, loaf, pita, roll, sourdough, tortilla, naan, focaccia")
        add(.meat, "bacon, beef, chicken, chorizo, duck, ham, lamb, pork, prosciutto, sausage, steak, turkey, veal, mince, brisket, thigh, breast, rib, pancetta, salami")
        add(.seafood, "anchovy, clam, cod, crab, fish, halibut, lobster, mussel, oyster, prawn, salmon, scallop, shrimp, squid, tilapia, trout, tuna")
        add(.dairy, "butter, buttermilk, cheese, cheddar, cream, egg, feta, ghee, milk, mozzarella, parmesan, ricotta, yogurt, yoghurt, mascarpone, brie, gruyere, halloumi, sour cream, cream cheese")
        add(.frozen, "frozen, ice cream, sorbet")
        add(.pantry, "bean, broth, chickpea, coconut milk, couscous, cracker, flour, honey, jam, ketchup, lentil, mayonnaise, mustard, noodle, oat, oil, olive, pasta, peanut butter, quinoa, rice, salsa, sauce, spaghetti, stock, sugar, syrup, tahini, vinegar, cereal, almond, cashew, walnut, pecan, peanut, nut, seed, raisin, chocolate, tomato paste, soy sauce, miso, maple syrup, breadcrumb, panko, lasagna, macaroni, penne, tofu, chip")
        add(.spices, "allspice, baking powder, baking soda, bay, cardamom, cayenne, cinnamon, clove, coriander, cumin, curry, nutmeg, oregano, paprika, salt, saffron, turmeric, vanilla, yeast, peppercorn, cornstarch, spice, seasoning, black pepper, red pepper flake, chili powder, chili flake, garlic powder, onion powder")
        add(.drinks, "beer, coffee, juice, kombucha, soda, tea, water, wine, seltzer")
        add(.household, "battery, detergent, foil, napkin, paper towel, soap, sponge, toilet paper, trash bag, wrap, dish soap, tissue")
        return table
    }()
}

/// Asks the on-device model where groceries the keyword table doesn't know are found.
public enum GroceryAisleSorter {
    /// Nil when Apple Intelligence isn't available; otherwise an aisle for each name it answered.
    public static func sort(_ names: [String]) async -> [String: GroceryAisle]? {
        guard !names.isEmpty else { return [:] }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *), AppleIntelligence.status.isAvailable {
            let session = LanguageModelSession(instructions: """
                You sort a shopping list into grocery store aisles. For each numbered item, pick the aisle a typical \
                supermarket shelves it in. Use other only for things no grocery store sells.
                """)
            let list = names.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            guard let response = try? await session.respond(to: list, generating: GeneratedAisles.self) else { return nil }
            var answers: [String: GroceryAisle] = [:]
            for answer in response.content.items where names.indices.contains(answer.number - 1) {
                answers[names[answer.number - 1]] = GroceryAisle(rawValue: answer.aisle.rawValue) ?? .other
            }
            return answers
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
enum GeneratedAisle: String {
    case produce, bakery, meat, seafood, dairy, frozen, pantry, spices, drinks, household, other
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedAisles {
    @Guide(description: "One answer per item, in the order listed.")
    var items: [GeneratedAisleAnswer]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedAisleAnswer {
    @Guide(description: "The item's number as listed.")
    var number: Int
    var aisle: GeneratedAisle
}
#endif
