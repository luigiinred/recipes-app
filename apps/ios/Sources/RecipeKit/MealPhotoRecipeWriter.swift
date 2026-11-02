import Foundation
import ImageIO
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Writes a draft recipe for the dish in a photo with the on-device model.
public enum MealPhotoRecipeWriter {
    public enum Outcome: Sendable {
        case written(Recipe)
        case unavailable(AppleIntelligence.Status)
        /// The model was ready but couldn't write a recipe; the text says why.
        case failed(String)
    }

    /// Reads the image itself when the model can see; otherwise works from what Vision recognizes in it.
    public static func run(imageData: Data) async -> Outcome {
        let status = AppleIntelligence.status
        guard status.isAvailable else { return .unavailable(status) }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failed("Couldn't read that photo.")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32).flatMap(CGImagePropertyOrientation.init) ?? .up
        #if canImport(FoundationModels)
        if #available(macOS 27.0, iOS 27.0, *), SystemLanguageModel.default.capabilities.contains(.vision) {
            if let outcome = await looking(at: image, orientation: orientation) { return outcome }
        }
        if #available(macOS 26.0, iOS 26.0, *) {
            let labels = (try? classify(image, orientation: orientation)) ?? []
            guard let prompt = labelPrompt(labels) else { return .failed("Couldn't tell what's in that photo.") }
            return await respond { "\(prompt)" }
        }
        #endif
        return .unavailable(.osTooOld)
    }

    static func labelPrompt(_ labels: [(identifier: String, confidence: Float)]) -> String? {
        let seen = labels
            .filter { $0.confidence >= 0.15 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map { "\($0.identifier.replacingOccurrences(of: "_", with: " ")) (\(Int(($0.confidence * 100).rounded()))%)" }
        guard !seen.isEmpty else { return nil }
        return "Image recognition looked at a photo of a meal and saw, most likely first: \(seen.joined(separator: ", ")). Write a recipe for the dish."
    }

    private static func classify(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> [(identifier: String, confidence: Float)] {
        let request = VNClassifyImageRequest()
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        return (request.results ?? []).map { ($0.identifier, $0.confidence) }
    }

    #if canImport(FoundationModels)
    /// Nil when the model can't take the image, so the caller falls back to Vision labels.
    @available(macOS 27.0, iOS 27.0, *)
    private static func looking(at image: CGImage, orientation: CGImagePropertyOrientation) async -> Outcome? {
        do {
            return try await generate {
                "Write a recipe for the dish in this photo."
                Attachment(image, orientation: orientation)
            }
        } catch let error as LanguageModelError {
            switch error {
            case .guardrailViolation, .refusal: return .failed("Apple Intelligence declined to read this photo.")
            default: return nil
            }
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error { return .failed("Apple Intelligence declined to read this photo.") }
            return nil
        } catch {
            return nil
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func respond(@PromptBuilder _ prompt: () throws -> Prompt) async -> Outcome {
        do {
            return try await generate(prompt)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation: return .failed("Apple Intelligence declined to read this photo.")
            case .unsupportedLanguageOrLocale: return .failed("Apple Intelligence doesn't support this language.")
            case .assetsUnavailable: return .unavailable(.modelNotReady)
            default: return .failed(error.localizedDescription)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func generate(@PromptBuilder _ prompt: () throws -> Prompt) async throws -> Outcome {
        let session = LanguageModelSession(instructions: AIAction.mealPhoto.instructions())
        let content = try await session.respond(generating: GeneratedMealRecipe.self, prompt: prompt).content
        let title = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return .written(Recipe(
            title: title.isEmpty ? "Untitled Meal" : title,
            summary: content.summary,
            servings: content.servings > 0 ? content.servings : nil,
            ingredients: content.ingredients.map { Ingredient(parsing: $0).text }.filter { !$0.isEmpty },
            steps: content.steps.map(RecipeStandards.standardStep).filter { !$0.isEmpty }
        ))
    }
    #endif
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedMealRecipe {
    @Guide(description: "The dish's name in title case, such as 'Chicken Fried Rice'.")
    var title: String
    @Guide(description: "One sentence describing the dish.")
    var summary: String
    @Guide(description: "How many servings the amounts make.")
    var servings: Int
    @Guide(description: "Every ingredient in the order they are used, each written as amount, unit and item, such as '1 1/2 cups flour', '2 eggs' or '1 clove garlic, minced'.")
    var ingredients: [String]
    @Guide(description: "The cooking steps in order, each a short imperative sentence or two, with no numbering.")
    var steps: [String]
}
#endif
