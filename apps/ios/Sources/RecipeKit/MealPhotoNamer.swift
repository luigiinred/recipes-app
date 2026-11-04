import Foundation
import ImageIO
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Names the dish or packaged food in a photo, so it can be saved as an idea.
public enum MealPhotoNamer {
    /// Tries the on-device model, then the largest printed text, such as the name on a box. Nil when neither finds a name.
    public static func name(imageData: Data) async -> String? {
        if case .named(let name) = await run(imageData: imageData) { return name }
        guard let image = RecipeImageProcessing.thumbnail(from: imageData, maxPixelSize: 1600) else { return nil }
        return await Task.detached { try? RecipeScanner.prominentTitle(in: image) }.value
    }

    public enum Outcome: Sendable {
        case named(String)
        case unavailable(AppleIntelligence.Status)
        /// The model was ready but couldn't name the dish; the text says why.
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
        return "Image recognition looked at a photo of a meal and saw, most likely first: \(seen.joined(separator: ", ")). Name the dish."
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
                "Name the dish or food in this photo."
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
        let session = LanguageModelSession(instructions: AIAction.mealPhotoName.instructions())
        let title = try await session.respond(generating: GeneratedMealName.self, prompt: prompt).content.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? .failed("Couldn't tell what's in that photo.") : .named(title)
    }
    #endif
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct GeneratedMealName {
    @Guide(description: "The dish's name in title case, such as 'Chicken Fried Rice' or 'Frozen Meat Lasagna'.")
    var title: String
}
#endif
