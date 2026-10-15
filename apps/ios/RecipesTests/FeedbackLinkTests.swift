import Foundation
import Testing
@testable import Recipes

@Suite("Feedback link")
struct FeedbackLinkTests {
    private func items(_ kind: FeedbackKind) -> [String: String] {
        let url = FeedbackLink.url(for: kind, environment: "Recipes 1.0 (8) · iOS 26")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/luigiinred/recipes-app/issues/new")
        return Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value ?? "") })
    }

    @Test("a bug opens a labelled issue that asks how to reproduce it")
    func bug() {
        let query = items(.bug)
        #expect(query["labels"] == "bug")
        #expect(query["body"]!.contains("Steps to reproduce"))
    }

    @Test("a suggestion is labelled as an enhancement")
    func feature() {
        #expect(items(.feature)["labels"] == "enhancement")
    }

    @Test("the app version and system ride along in the body")
    func environment() {
        #expect(items(.bug)["body"]!.hasSuffix("---\nRecipes 1.0 (8) · iOS 26"))
    }
}
