import XCTest
@testable import RecipeKit

final class YouTubeChannelsTests: XCTestCase {
    func testReadsChannelsFromSearchPage() {
        let html = """
        <script>var ytInitialData = {"contents":{"sectionListRenderer":{"contents":[{"itemSectionRenderer":{"contents":[
        {"channelRenderer":{"channelId":"UC1","title":{"simpleText":"Pasta Grannies"},
          "thumbnail":{"thumbnails":[{"url":"//yt3.ggpht.com/small"},{"url":"//yt3.ggpht.com/large"}]},
          "subscriberCountText":{"simpleText":"@pastagrannies"},"videoCountText":{"runs":[{"text":"1.2M"},{"text":" subscribers"}]}}},
        {"channelRenderer":{"channelId":"UC2","title":{"runs":[{"text":"Joshua Weissman"}]}}},
        {"channelRenderer":{"channelId":"UC1","title":{"simpleText":"Pasta Grannies"}}}
        ]}}]}}};</script>
        """
        let channels = YouTubeChannels.channels(inSearchPage: html)
        XCTAssertEqual(channels.map(\.id), ["UC1", "UC2"])
        XCTAssertEqual(channels[0].title, "Pasta Grannies")
        XCTAssertEqual(channels[0].detail, "@pastagrannies · 1.2M subscribers")
        XCTAssertEqual(channels[0].thumbnailURL?.absoluteString, "https://yt3.ggpht.com/large")
        XCTAssertEqual(channels[1].feedURL.absoluteString, "https://www.youtube.com/feeds/videos.xml?channel_id=UC2")
    }

    func testReadsChannelFromWatchPage() {
        let html = #"<script>{"videoDetails":{"channelId":"UCedsqpl7jaIb8BiaUFuC9KQ","author":"x"},"ownerChannelName":"Pasta \u0026 Grannies"}</script>"#
        let channel = YouTubeChannels.channel(inWatchPage: html)
        XCTAssertEqual(channel?.id, "UCedsqpl7jaIb8BiaUFuC9KQ")
        XCTAssertEqual(channel?.title, "Pasta & Grannies")
    }

    func testNoDataIsNoChannels() {
        XCTAssertTrue(YouTubeChannels.channels(inSearchPage: "<html></html>").isEmpty)
    }
}
