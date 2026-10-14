import RecipeKit
import SwiftUI
import Testing
@testable import Recipes

@Suite("Onboarding", .serialized)
@MainActor
struct OnboardingTests {
    @Test("four distinct secure sources, mixing web pages and videos")
    func sources() {
        let all = OnboardingSources.all
        #expect(all.count == 4)
        #expect(Set(all.map(\.id)).count == 4)
        #expect(all.allSatisfy { $0.url.scheme == "https" && $0.url.host != nil })
        for source in all {
            #expect((YouTubeImporter.videoID(from: source.url) != nil) == (source.kind == .video), "\(source.title) is mislabeled")
        }
        #expect(all.contains { $0.kind == .web } && all.contains { $0.kind == .video })
    }

    @Test("an imported recipe matches its source, including a normalized video link")
    func matching() throws {
        let web = try #require(OnboardingSources.all.first { $0.kind == .web })
        let video = try #require(OnboardingSources.all.first { $0.kind == .video })
        #expect(web.matches(Recipe(title: "A", sourceURL: web.url.absoluteString)))
        #expect(video.matches(Recipe(title: "B", sourceURL: video.url.absoluteString + "&t=30s")))
        #expect(!web.matches(Recipe(title: "C", sourceURL: video.url.absoluteString)))
        #expect(!web.matches(Recipe(title: "D")))
    }

    private func library(adding indices: [Int]) -> RecipeLibrary {
        RecipeLibrary(recipes: indices.map {
            let source = OnboardingSources.all[$0]
            return Recipe(title: source.title, summary: "Imported from \(source.site).", servings: 4, prepMinutes: 10, cookMinutes: 20,
                          ingredients: ["2 eggs"], steps: ["Cook."], sourceURL: source.url.absoluteString)
        })
    }

    private func snapshot(_ step: OnboardingView.Step, library: RecipeLibrary? = nil, testName: String = #function) {
        let page = OnboardingView(step: step, loadsPreviews: false) {}.environmentObject(library ?? self.library(adding: []))
        assertPageSnapshots(of: page, inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet, testName: testName)
    }

    @Test("welcome")
    func welcome() { snapshot(.welcome) }

    @Test("share sheet explainer")
    func share() { snapshot(.share) }

    @Test("add: nothing imported yet")
    func addEmpty() { snapshot(.add) }

    @Test("add: a web recipe and a video imported")
    func addSome() { snapshot(.add, library: library(adding: [0, 2])) }

    @Test("try it on the first imported recipe")
    func tryIt() { snapshot(.tryIt, library: library(adding: [1])) }

    @Test("discover")
    func discover() { snapshot(.discover) }
}
