import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public enum TranscriptRecipeExtractor {
    public struct Extracted: Sendable {
        public var ingredients: [String]
        public var steps: [String]
        public var servings: Int?
        public var summary: String
    }

    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Loads the on-device model ahead of time so the first request doesn't wait for it.
    public static func prewarm() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *), isAvailable {
            LanguageModelSession(instructions: instructions).prewarm()
        }
        #endif
    }

    private static let instructions = """
        You turn the spoken captions of a cooking video into a written recipe. \
        Only use what the cook says. Do not invent ingredients, quantities or steps.

        \(RecipeStandards.rules)
        """

    /// Uses the on-device language model; nil when it isn't available or can't read the text.
    public static func extract(title: String, transcript: String) async -> Extracted? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *), isAvailable {
            let text = String(transcript.prefix(9000))
            let session = LanguageModelSession(instructions: instructions)
            do {
                let response = try await session.respond(
                    to: "Video title: \(title)\n\nCaptions:\n\(text)",
                    generating: GeneratedRecipe.self
                )
                let content = response.content
                return Extracted(
                    ingredients: content.ingredients.map(\.standardText).filter { !$0.isEmpty },
                    steps: content.steps.map(RecipeStandards.standardStep).filter { !$0.isEmpty },
                    servings: content.servings,
                    summary: content.summary
                )
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedIngredient {
    @Guide(description: "Amount in digits or a fraction such as 2, 1/2 or 1 1/2. Empty when the cook gives none.")
    var quantity: String
    @Guide(description: "The unit, or none for whole items such as eggs.", .anyOf(IngredientUnit.generationChoices))
    var unit: String
    @Guide(description: "The ingredient alone, such as 'flour' or 'garlic, minced'. No quantity, no equipment.")
    var item: String

    var standardText: String {
        Ingredient(
            quantity: quantity, unit: unit == "none" ? nil : IngredientUnit(alias: unit),
            item: item
        ).text
    }
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedRecipe {
    @Guide(description: "Every ingredient the cook uses, in the order they are used.")
    var ingredients: [GeneratedIngredient]
    @Guide(description: "The cooking steps in order, each a short imperative sentence or two, with no numbering.")
    var steps: [String]
    @Guide(description: "Number of servings, only if the cook says it.")
    var servings: Int?
    @Guide(description: "One sentence describing the dish.")
    var summary: String
}
#endif
