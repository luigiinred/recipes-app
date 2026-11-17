import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Adds the periods and capitals missing where a step's sentences run together, like "add the oatmeal Mix well", with the on-device model.
public enum StepPunctuation {
    /// A lowercase word, then a capitalized one with no punctuation between them.
    private static let runOn = try! NSRegularExpression(pattern: "\\p{Ll}\\s+(?!I\\b)\\p{Lu}\\p{Ll}")

    static func needsHelp(_ step: String) -> Bool {
        runOn.firstMatch(in: step, range: NSRange(step.startIndex..., in: step)) != nil
    }

    /// The model's version only when it changed nothing but punctuation, capitals and spacing.
    static func validated(_ fixed: String, original: String) -> String? {
        func words(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
        let step = RecipeStandards.standardStep(fixed)
        guard !step.isEmpty, step != original, words(step) == words(original) else { return nil }
        return step
    }

    /// Each run-together step with its punctuation fixed; every other step and any failure stay as they were.
    public static func fix(_ steps: [String]) async -> [String] {
        guard steps.contains(where: needsHelp), AppleIntelligence.status.isAvailable else { return steps }
        var result: [String] = []
        for step in steps {
            if needsHelp(step), let fixed = await fixed(step) { result.append(fixed) } else { result.append(step) }
        }
        return result
    }

    private static func fixed(_ step: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let session = LanguageModelSession(instructions: AIAction.punctuateSteps.instructions())
            do {
                let response = try await session.respond(to: String(step.prefix(1500)), generating: PunctuatedStep.self)
                return validated(response.content.text, original: step)
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
struct PunctuatedStep {
    @Guide(description: "The step with only its punctuation, capitals and spacing fixed.")
    var text: String
}
#endif
