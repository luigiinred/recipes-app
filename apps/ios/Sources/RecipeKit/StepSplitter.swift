import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Breaks a method that was pasted as one block into separate steps with the on-device model.
public enum StepSplitter {
    private static let longStep = 450

    /// A step this long is probably several run together.
    public static func needsHelp(_ steps: [String]) -> Bool {
        steps.contains { $0.count > longStep }
    }

    /// The model's pieces as clean steps, or nil when it gave back fewer than two or dropped much of the text.
    static func validated(_ pieces: [String], original: String) -> [String]? {
        let steps = pieces.map(RecipeStandards.standardStep).filter { !$0.isEmpty }
        guard steps.count >= 2, Double(steps.joined(separator: " ").count) >= Double(original.count) * 0.7 else { return nil }
        return steps
    }

    /// Each long step replaced by its parts; every other step and any failure leave the list as it was.
    public static func split(_ steps: [String]) async -> [String] {
        guard needsHelp(steps), AppleIntelligence.status.isAvailable else { return steps }
        var result: [String] = []
        for step in steps {
            if step.count > longStep, let parts = await parts(of: step) { result += parts } else { result.append(step) }
        }
        return result
    }

    private static func parts(of text: String) async -> [String]? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let session = LanguageModelSession(instructions: """
                A recipe's method was pasted as one block. Split it into separate steps in the original order. \
                Keep the author's words. Do not add, drop or reorder anything. Each step is one action or two related ones.
                """)
            do {
                let response = try await session.respond(to: String(text.prefix(3000)), generating: GeneratedMethod.self)
                return validated(response.content.steps, original: String(text.prefix(3000)))
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
struct GeneratedMethod {
    @Guide(description: "The method as separate steps, in order, without numbering.")
    var steps: [String]
}
#endif
