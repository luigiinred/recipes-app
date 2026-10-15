import RecipeKit
import SwiftUI

/// An ingredient with its amount in bold, the item in the surrounding style, and its preparation in grey italics.
struct IngredientLine: View {
    let text: String

    var body: some View {
        Text(Self.styled(text))
    }

    /// "2 tbsp olive oil" without the preparation, for chips.
    static func chipText(_ text: String) -> String {
        let ingredient = Ingredient(parsing: text)
        return ingredient.amount.isEmpty ? ingredient.name : ingredient.amount + " " + ingredient.name
    }

    static func styled(_ text: String) -> AttributedString {
        let ingredient = Ingredient(parsing: text)
        var result = AttributedString()
        if !ingredient.amount.isEmpty {
            var amount = AttributedString(ingredient.amount + " ")
            amount.inlinePresentationIntent = .stronglyEmphasized
            result += amount
        }
        result += AttributedString(ingredient.name)
        if !ingredient.preparation.isEmpty {
            var note = AttributedString(" " + ingredient.preparation)
            note.inlinePresentationIntent = .emphasized
            note.foregroundColor = .secondary
            result += note
        }
        return result
    }
}
