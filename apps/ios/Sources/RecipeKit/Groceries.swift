import Foundation

public struct GroceryItem: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var quantity: String
    public var isChecked: Bool
    public var recipeID: UUID?
    /// Identifier of the matching item in the Reminders app, once synced.
    public var reminderID: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        quantity: String = "",
        isChecked: Bool = false,
        recipeID: UUID? = nil,
        reminderID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.isChecked = isChecked
        self.recipeID = recipeID
        self.reminderID = reminderID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// How the item reads as a reminder title, such as "500g black beans".
    public var reminderTitle: String { quantity.isEmpty ? name : "\(quantity) \(name)" }

    public init(parsing text: String, recipeID: UUID? = nil) {
        let parts = IngredientParser.split(text)
        self.init(name: parts.name, quantity: parts.quantity, recipeID: recipeID)
    }
}

public enum IngredientParser {
    private static let vulgarFractions = Set("¼½¾⅓⅔⅛⅜⅝⅞")

    public static func split(_ text: String) -> (quantity: String, name: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        var index = 0
        while index < tokens.count, isNumeric(tokens[index]) { index += 1 }
        guard index > 0 else { return ("", trimmed) }
        if index < tokens.count, IngredientUnit(alias: tokens[index]) != nil {
            index += 1
        }
        let quantity = tokens[..<index].joined(separator: " ")
        if index < tokens.count, tokens[index].lowercased() == "of" { index += 1 }
        let name = tokens[index...].joined(separator: " ")
        return name.isEmpty ? ("", trimmed) : (quantity, name)
    }

    private static func isNumeric(_ token: String) -> Bool {
        guard let first = token.first else { return false }
        return first.isNumber || vulgarFractions.contains(first)
    }
}
