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
