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

    /// Uses the on-device language model; nil when it isn't available or can't read the text.
    public static func extract(title: String, transcript: String) async -> Extracted? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *), isAvailable {
            let text = String(transcript.prefix(9000))
            let session = LanguageModelSession(instructions: """
                You turn the spoken captions of a cooking video into a written recipe. \
                Only use what the cook says. Do not invent ingredients, quantities or steps.
                """)
            do {
                let response = try await session.respond(
                    to: "Video title: \(title)\n\nCaptions:\n\(text)",
                    generating: GeneratedRecipe.self
                )
                let content = response.content
                return Extracted(ingredients: content.ingredients, steps: content.steps, servings: content.servings, summary: content.summary)
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
struct GeneratedRecipe {
    @Guide(description: "Every ingredient with its quantity if stated, such as '2 cups flour'. No equipment.")
    var ingredients: [String]
    @Guide(description: "The cooking steps in order, each one or two clear sentences.")
    var steps: [String]
    @Guide(description: "Number of servings, only if the cook says it.")
    var servings: Int?
    @Guide(description: "One sentence describing the dish.")
    var summary: String
}
#endif
