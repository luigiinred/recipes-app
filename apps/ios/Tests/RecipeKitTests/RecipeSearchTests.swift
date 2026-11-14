import XCTest
@testable import RecipeKit

final class RecipeSearchTests: XCTestCase {
    func testWordPressPosts() {
        let json = #"[{"title":{"rendered":"Mac &#038; Cheese &#8211; Easy"},"link":"https://www.budgetbytes.com/mac/","_embedded":{"wp:featuredmedia":[{"source_url":"https://www.budgetbytes.com/mac.jpg"}]}},{"title":{"rendered":"No link"}}]"#
        let results = RecipeSearch.wordPressPosts(Data(json.utf8), site: URL(string: "https://www.budgetbytes.com")!)
        XCTAssertEqual(results.map(\.title), ["Mac & Cheese – Easy"])
        XCTAssertEqual(results.first?.source, "budgetbytes.com")
        XCTAssertEqual(results.first?.imageURL?.absoluteString, "https://www.budgetbytes.com/mac.jpg")
    }

    func testYouTubeVideos() {
        let html = #"<script>var ytInitialData = {"contents":[{"videoRenderer":{"videoId":"abcdefghijk","title":{"runs":[{"text":"Best Lasagna"}]},"ownerText":{"runs":[{"text":"Chef A"}]}}},{"channelRenderer":{"channelId":"UC1"}}]};</script>"#
        let results = RecipeSearch.youTubeVideos(inSearchPage: html)
        XCTAssertEqual(results.map(\.title), ["Best Lasagna"])
        XCTAssertEqual(results.first?.source, "Chef A")
        XCTAssertEqual(results.first?.link.absoluteString, "https://www.youtube.com/watch?v=abcdefghijk")
        XCTAssertEqual(results.first?.kind, .video)
    }

    func testWebResults() {
        let html = #"""
        <div class="result"><a rel="nofollow" class="result__a" href="https://www.allrecipes.com/recipe/23600/worlds-best-lasagna/">World&#x27;s <b>Best</b> Lasagna</a></div>
        <div class="result"><a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Fwww.simplyrecipes.com%2Flasagna%2F&amp;rut=1">Simply Lasagna</a></div>
        <div class="result result--ad"><a class="result__a" href="https://duckduckgo.com/y.js?ad=1">An ad</a></div>
        <div class="result"><a rel="nofollow" class="result__a" href="https://www.allrecipes.com/recipe/23600/worlds-best-lasagna/">Again</a></div>
        """#
        let results = RecipeSearch.webResults(inPage: html)
        XCTAssertEqual(results.map(\.title), ["World's Best Lasagna", "Simply Lasagna"])
        XCTAssertEqual(results.map(\.source), ["allrecipes.com", "simplyrecipes.com"])
        XCTAssertEqual(results[1].link.absoluteString, "https://www.simplyrecipes.com/lasagna/")
    }

    func testSitesBehindFeeds() {
        XCTAssertEqual(RecipeSearch.site(ofFeed: "https://www.budgetbytes.com/feed/")?.absoluteString, "https://www.budgetbytes.com")
        XCTAssertNil(RecipeSearch.site(ofFeed: "https://www.youtube.com/feeds/videos.xml?channel_id=UC1"))
        XCTAssertNil(RecipeSearch.site(ofFeed: "https://www.reddit.com/r/recipes/.rss"))
        XCTAssertEqual(RecipeSearch.webSearchURL("lasagna")?.absoluteString, "https://www.google.com/search?q=lasagna%20recipe")
    }

    func testSearchEngineLinks() {
        XCTAssertTrue(RecipeSearch.isSearchEnginePage(URL(string: "https://www.google.com/search?q=x")!))
        XCTAssertTrue(RecipeSearch.isSearchEnginePage(URL(string: "https://www.google.co.uk/search?q=x")!))
        XCTAssertFalse(RecipeSearch.isSearchEnginePage(URL(string: "https://www.budgetbytes.com/chili/")!))
        let redirect = URL(string: "https://www.google.com/url?q=https://www.budgetbytes.com/chili/&sa=U")!
        XCTAssertEqual(RecipeSearch.destination(of: redirect).absoluteString, "https://www.budgetbytes.com/chili/")
        XCTAssertEqual(RecipeSearch.destination(of: URL(string: "https://www.budgetbytes.com/chili/")!).absoluteString, "https://www.budgetbytes.com/chili/")
    }
}
