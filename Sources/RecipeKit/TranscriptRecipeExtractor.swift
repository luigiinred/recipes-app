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

    public static var isAvailable: Bool { AppleIntelligence.status.isAvailable }

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

        \(RecipeStandards.extractionRules)
        """

    public enum Outcome: Sendable {
        case extracted(Extracted)
        case unavailable(AppleIntelligence.Status)
        /// The model was ready but couldn't produce a recipe; the text says why.
        case failed(String)
    }

    /// Uses the on-device language model; nil when it isn't available or can't read the text.
    public static func extract(title: String, transcript: String) async -> Extracted? {
        if case .extracted(let extracted) = await run(title: title, transcript: transcript) { return extracted }
        return nil
    }

    /// Like `extract`, but says why when there is no recipe. A long transcript that overflows the model's window is retried shorter.
    public static func run(title: String, transcript: String) async -> Outcome {
        let status = AppleIntelligence.status
        guard status.isAvailable else { return .unavailable(status) }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            var failure = "The captions couldn't be read."
            for limit in [7000, 3500] {
                let session = LanguageModelSession(instructions: instructions)
                do {
                    let response = try await session.respond(
                        to: "Video title: \(title)\n\nCaptions:\n\(String(transcript.prefix(limit)))",
                        generating: GeneratedRecipe.self
                    )
                    let content = response.content
                    return .extracted(Extracted(
                        ingredients: content.ingredients.map(\.standardText).filter { !$0.isEmpty },
                        steps: content.steps.map(RecipeStandards.standardStep).filter { !$0.isEmpty },
                        servings: content.servings,
                        summary: content.summary
                    ))
                } catch let error as LanguageModelSession.GenerationError {
                    switch error {
                    case .exceededContextWindowSize:
                        failure = "The video's captions are too long for the on-device model."
                        continue
                    case .guardrailViolation:
                        return .failed("Apple Intelligence declined to read these captions.")
                    case .unsupportedLanguageOrLocale:
                        return .failed("Apple Intelligence doesn't support this video's language.")
                    case .assetsUnavailable:
                        return .unavailable(.modelNotReady)
                    default:
                        return .failed(error.localizedDescription)
                    }
                } catch {
                    return .failed(error.localizedDescription)
                }
            }
            return .failed(failure)
        }
        #endif
        return .unavailable(.osTooOld)
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
