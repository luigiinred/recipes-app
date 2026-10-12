import Foundation

public enum IngredientUnit: String, CaseIterable, Identifiable, Hashable, Sendable {
    case teaspoon, tablespoon, cup, fluidOunce, pint, quart, gallon
    case milliliter, centiliter, deciliter, liter
    case milligram, gram, kilogram, ounce, pound
    case pinch, dash, clove, can, package, jar, bunch, sprig, stalk, head, slice, stick, handful

    public var id: String { rawValue }

    public enum Group: String, CaseIterable, Sendable {
        case volume = "Volume", weight = "Weight", count = "Count"
    }

    public var group: Group {
        switch self {
        case .teaspoon, .tablespoon, .cup, .fluidOunce, .pint, .quart, .gallon, .milliliter, .centiliter, .deciliter, .liter: .volume
        case .milligram, .gram, .kilogram, .ounce, .pound: .weight
        default: .count
        }
    }

    /// How the unit is written in a recipe: abbreviations never change, words agree with the quantity.
    var labels: (singular: String, plural: String) {
        switch self {
        case .teaspoon: ("tsp", "tsp")
        case .tablespoon: ("tbsp", "tbsp")
        case .cup: ("cup", "cups")
        case .fluidOunce: ("fl oz", "fl oz")
        case .pint: ("pint", "pints")
        case .quart: ("quart", "quarts")
        case .gallon: ("gallon", "gallons")
        case .milliliter: ("ml", "ml")
        case .centiliter: ("cl", "cl")
        case .deciliter: ("dl", "dl")
        case .liter: ("l", "l")
        case .milligram: ("mg", "mg")
        case .gram: ("g", "g")
        case .kilogram: ("kg", "kg")
        case .ounce: ("oz", "oz")
        case .pound: ("lb", "lb")
        case .pinch: ("pinch", "pinches")
        case .dash: ("dash", "dashes")
        case .clove: ("clove", "cloves")
        case .can: ("can", "cans")
        case .package: ("package", "packages")
        case .jar: ("jar", "jars")
        case .bunch: ("bunch", "bunches")
        case .sprig: ("sprig", "sprigs")
        case .stalk: ("stalk", "stalks")
        case .head: ("head", "heads")
        case .slice: ("slice", "slices")
        case .stick: ("stick", "sticks")
        case .handful: ("handful", "handfuls")
        }
    }

    /// Short name for pickers, such as "tbsp" or "cup".
    public var abbreviation: String { labels.singular }

    public var title: String {
        switch self {
        case .teaspoon: "Teaspoon (tsp)"
        case .tablespoon: "Tablespoon (tbsp)"
        case .fluidOunce: "Fluid ounce (fl oz)"
        case .milliliter: "Milliliter (ml)"
        case .centiliter: "Centiliter (cl)"
        case .deciliter: "Deciliter (dl)"
        case .liter: "Liter (l)"
        case .milligram: "Milligram (mg)"
        case .gram: "Gram (g)"
        case .kilogram: "Kilogram (kg)"
        case .ounce: "Ounce (oz)"
        case .pound: "Pound (lb)"
        default: labels.singular.capitalized
        }
    }

    public static func units(in group: Group) -> [IngredientUnit] {
        allCases.filter { $0.group == group }
    }

    /// The unit written in a recipe for this quantity, such as "cups" for 2 and "cup" for 1.
    public func label(forQuantity quantity: String) -> String {
        guard let value = Ingredient.value(of: quantity), value <= 1 else { return labels.plural }
        return labels.singular
    }

    private static let aliases: [String: IngredientUnit] = {
        let table: [IngredientUnit: [String]] = [
            .teaspoon: ["tsp", "tsps", "teaspoon", "teaspoons"],
            .tablespoon: ["tbsp", "tbsps", "tbs", "tablespoon", "tablespoons"],
            .cup: ["cup", "cups"],
            .fluidOunce: ["floz", "fl.oz", "fl.oz."],
            .pint: ["pt", "pint", "pints"],
            .quart: ["qt", "qts", "quart", "quarts"],
            .gallon: ["gal", "gallon", "gallons"],
            .milliliter: ["ml", "milliliter", "milliliters", "millilitre", "millilitres"],
            .centiliter: ["cl"],
            .deciliter: ["dl"],
            .liter: ["l", "liter", "liters", "litre", "litres"],
            .milligram: ["mg"],
            .gram: ["g", "gram", "grams"],
            .kilogram: ["kg", "kilogram", "kilograms"],
            .ounce: ["oz", "ounce", "ounces"],
            .pound: ["lb", "lbs", "pound", "pounds"],
            .pinch: ["pinch", "pinches"],
            .dash: ["dash", "dashes"],
            .clove: ["clove", "cloves"],
            .can: ["can", "cans"],
            .package: ["package", "packages", "pkg", "pkgs"],
            .jar: ["jar", "jars"],
            .bunch: ["bunch", "bunches"],
            .sprig: ["sprig", "sprigs"],
            .stalk: ["stalk", "stalks"],
            .head: ["head", "heads"],
            .slice: ["slice", "slices"],
            .stick: ["stick", "sticks"],
            .handful: ["handful", "handfuls"],
        ]
        var result: [String: IngredientUnit] = [:]
        for (unit, names) in table { for name in names { result[name] = unit } }
        return result
    }()

    /// Reads a unit as people write it: "Tablespoons", "tbsp.", "lbs".
    public init?(alias: String) {
        guard let unit = Self.aliases[alias.lowercased().trimmingCharacters(in: .punctuationCharacters)] else { return nil }
        self = unit
    }

    /// Values for a language model to choose from, with "none" for a bare count.
    public static let generationChoices: [String] = ["none"] + allCases.map(\.abbreviation)
}

/// One ingredient line split into quantity, unit and item, written in a single standard form: "1 1/2 cups flour".
public struct Ingredient: Hashable, Sendable {
    public var quantity: String
    public var unit: IngredientUnit?
    public var item: String

    public init(quantity: String = "", unit: IngredientUnit? = nil, item: String = "") {
        self.quantity = quantity
        self.unit = unit
        self.item = item
    }

    public init(parsing text: String) {
        var tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let original = tokens.joined(separator: " ")
        var quantityTokens: [String] = []
        var unit: IngredientUnit?

        while unit == nil, let token = tokens.first, Self.isNumeric(token) {
            tokens.removeFirst()
            let (number, suffix) = Self.splitNumber(token)
            if suffix.isEmpty {
                quantityTokens.append(number)
            } else if let attached = IngredientUnit(alias: suffix) {
                quantityTokens.append(number)
                unit = attached
            } else {
                quantityTokens.append(token)
            }
        }
        if !quantityTokens.isEmpty, unit == nil, let token = tokens.first {
            if ["fl", "fl."].contains(token.lowercased()), tokens.count > 1, ["oz", "oz."].contains(tokens[1].lowercased()) {
                unit = .fluidOunce
                tokens.removeFirst(2)
            } else if let spoken = IngredientUnit(alias: token) {
                unit = spoken
                tokens.removeFirst()
            }
        }
        if unit != nil, tokens.first?.lowercased() == "of" { tokens.removeFirst() }

        let item = tokens.joined(separator: " ")
        if quantityTokens.isEmpty || item.isEmpty {
            self.init(item: original)
        } else {
            self.init(quantity: Self.normalizedQuantity(quantityTokens.joined(separator: " ")), unit: unit, item: item)
        }
    }

    /// The quantity and unit together, such as "1 1/2 cups"; empty for items without one.
    public var amount: String {
        let amount = Self.normalizedQuantity(quantity)
        guard !amount.isEmpty else { return "" }
        guard let unit else { return amount }
        return amount + " " + unit.label(forQuantity: amount)
    }

    /// The item without its preparation: "garlic" for "garlic, minced".
    public var name: String {
        let name = item.split(separator: ",", maxSplits: 1).first.map(String.init) ?? item
        return name.trimmingCharacters(in: .whitespaces)
    }

    /// How the item is prepared: "minced" for "garlic, minced".
    public var preparation: String {
        let parts = item.split(separator: ",", maxSplits: 1)
        return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
    }

    /// The standard written form. A unit without a quantity reads as one.
    public var text: String {
        let name = item.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        var amount = Self.normalizedQuantity(quantity)
        if amount.isEmpty, unit != nil, !name.isEmpty { amount = "1" }
        var parts: [String] = []
        if !amount.isEmpty { parts.append(amount) }
        if let unit, !amount.isEmpty { parts.append(unit.label(forQuantity: amount)) }
        if !name.isEmpty { parts.append(name) }
        return parts.joined(separator: " ")
    }

    /// Numeric value of a quantity such as "1 1/2", "0.5" or "2-3" (a range reads as its upper end).
    static func value(of quantity: String) -> Double? {
        let range = quantity.split(whereSeparator: { $0 == "-" || $0 == "–" }).map(String.init)
        guard let upper = range.last else { return nil }
        var total = 0.0
        let parts = upper.split(whereSeparator: \.isWhitespace)
        guard !parts.isEmpty else { return nil }
        for part in parts {
            let pieces = part.split(separator: "/").map { Double($0) }
            if pieces.count == 2, let top = pieces[0], let bottom = pieces[1], bottom != 0 {
                total += top / bottom
            } else if pieces.count == 1, let number = pieces[0] {
                total += number
            } else {
                return nil
            }
        }
        return total
    }

    private static let vulgarFractions: [Character: String] = [
        "¼": "1/4", "½": "1/2", "¾": "3/4", "⅓": "1/3", "⅔": "2/3", "⅛": "1/8", "⅜": "3/8", "⅝": "5/8", "⅞": "7/8",
    ]
    private static let numberCharacters = CharacterSet(charactersIn: "0123456789./-–,")

    private static func isNumeric(_ token: String) -> Bool {
        guard let first = token.first else { return false }
        return first.isNumber || vulgarFractions[first] != nil
    }

    private static func splitNumber(_ token: String) -> (number: String, suffix: String) {
        var number = ""
        var rest = Substring(token)
        while let character = rest.first,
              character.isNumber || vulgarFractions[character] != nil
                || (character.unicodeScalars.count == 1 && numberCharacters.contains(character.unicodeScalars.first!)) {
            number.append(character)
            rest = rest.dropFirst()
        }
        return (number, String(rest))
    }

    /// "½" and "1½" become "1/2" and "1 1/2"; surrounding spaces collapse.
    static func normalizedQuantity(_ quantity: String) -> String {
        var result = ""
        for character in quantity {
            if let fraction = vulgarFractions[character] {
                if let last = result.last, last.isNumber { result.append(" ") }
                result += fraction
            } else {
                result.append(character)
            }
        }
        return result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
