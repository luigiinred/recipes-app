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

    @Test("feed picks cover every kind of popular feed, once each")
    func feedPicks() {
        let picks = OnboardingFeeds.picks
        #expect(Set(picks.map(\.url)).count == picks.count)
        #expect(Set(picks.map(\.kind)) == Set(PopularFeed.Kind.allCases))
    }

    @Test("showing and hiding a Home section keeps the others as they were")
    func homeSections() {
        var (order, hidden) = HomeSection.showing(.tags, false, order: "", hidden: "")
        #expect(HomeSection.hidden(hidden, order: order) == [.tags, .discover])
        (order, hidden) = HomeSection.showing(.discover, true, order: order, hidden: hidden)
        #expect(HomeSection.hidden(hidden, order: order) == [.tags])
        #expect(HomeSection.order(order) == HomeSection.allCases)
    }

    @Test("showing and hiding a tab")
    func tabs() {
        let hidden = AppSettings.showing(.plan, false, hidden: AppSettings.showing(.feeds, false, hidden: ""))
        #expect(AppSettings.hiddenTabs(hidden) == [.feeds, .plan])
        #expect(AppSettings.hiddenTabs(AppSettings.showing(.feeds, true, hidden: hidden)) == [.plan])
    }

    private func library(adding indices: [Int], feeds: [Feed] = []) -> RecipeLibrary {
        RecipeLibrary(recipes: indices.map {
            let source = OnboardingSources.all[$0]
            return Recipe(title: source.title, summary: "Imported from \(source.site).", servings: 4, prepMinutes: 10, cookMinutes: 20,
                          ingredients: ["2 eggs"], steps: ["Cook."], sourceURL: source.url.absoluteString)
        }, feeds: feeds)
    }

    private func snapshot(
        _ step: OnboardingView.Step, library: RecipeLibrary? = nil,
        discover: DiscoverController? = nil, testName: String = #function
    ) {
        let page = OnboardingView(step: step, loadsPreviews: false) {}
            .environmentObject(library ?? self.library(adding: []))
            .environmentObject(discover ?? DiscoverController(previewing: []))
        assertPageSnapshots(of: page, inNavigationStack: false, macSize: SnapshotEnvironment.macSheetSize, coverage: .sheet, testName: testName)
    }

    @Test("welcome")
    func welcome() { snapshot(.welcome) }

    @Test("add: nothing imported yet")
    func addEmpty() { snapshot(.add) }

    @Test("add: a web recipe and a video imported")
    func addSome() { snapshot(.add, library: library(adding: [0, 2])) }

    #if os(iOS)
    @Test("home sections")
    func home() { snapshot(.home) }
    #endif

    @Test("tabs")
    func tabsPage() { snapshot(.tabs) }

    @Test("feeds: two followed")
    func feeds() {
        let picks = OnboardingFeeds.picks
        snapshot(.feeds, library: library(adding: [], feeds: [picks[0], picks[3]].map { Feed(url: $0.url, title: $0.name) }))
    }

    @Test("discover: nothing added yet")
    func discover() { snapshot(.discover) }

    @Test("discover: a server added")
    func discoverAdded() {
        snapshot(.discover, discover: DiscoverController(previewing: [
            DiscoverCatalog(previewing: DiscoverSource(server: "https://friends.example.com", token: ""), recipes: []),
        ]))
    }

    @Test("look")
    func look() { snapshot(.look) }

    @Test("reminders")
    func reminders() { snapshot(.reminders) }

    @Test("done, after setting things up")
    func done() {
        snapshot(
            .done, library: library(adding: [0, 1], feeds: [Feed(url: OnboardingFeeds.picks[0].url, title: OnboardingFeeds.picks[0].name)])
        )
    }
}
