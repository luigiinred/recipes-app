import RecipeKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

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

/// The number in its own right-aligned column, so a list of amounts reads down one edge.
struct AlignedIngredientLine: View {
    let text: String

    var body: some View {
        let ingredient = Ingredient(parsing: text)
        let quantity = Ingredient.standardQuantity(ingredient.quantity, unit: ingredient.unit)
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(quantity)
                .fontWeight(.semibold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 40, alignment: .trailing)
            Text(quantity.isEmpty ? IngredientLine.styled(text) : Self.remainder(of: ingredient, quantity: quantity))
                .multilineTextAlignment(.leading)
        }
    }

    private static func remainder(of ingredient: Ingredient, quantity: String) -> AttributedString {
        var result = AttributedString([ingredient.unit?.label(forQuantity: quantity), ingredient.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
        if !ingredient.preparation.isEmpty {
            var note = AttributedString(" " + ingredient.preparation)
            note.inlinePresentationIntent = .emphasized
            note.foregroundColor = .secondary
            result += note
        }
        return result
    }
}

extension View {
    /// Press and hold an ingredient to see its amount in other units; choosing one copies it.
    func conversionMenu(for text: String) -> some View {
        modifier(ConversionMenu(text: text))
    }
}

private struct ConversionMenu: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        let ingredient = Ingredient(parsing: text)
        let options = ingredient.conversions
        if options.isEmpty {
            content
        } else {
            content.contextMenu {
                Section("\(ingredient.amount) is") {
                    ForEach(options, id: \.self) { option in
                        Button(option, systemImage: "doc.on.doc") { Self.copy(option) }
                    }
                }
            }
        }
    }

    private static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
