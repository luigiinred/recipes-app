import XCTest
@testable import RecipeKit

final class FeedWidgetSnapshotTests: XCTestCase {
    private let bakes = Feed(url: "https://bakes.example/feed", title: "Bakes")
    private let soups = Feed(url: "https://soups.example/feed", title: "Soups")

    private func entry(_ title: String, _ seconds: TimeInterval?, site: String = "bakes") -> FeedEntry {
        FeedEntry(title: title, link: URL(string: "https://\(site).example/\(title)")!, published: seconds.map { Date(timeIntervalSince1970: $0) })
    }

    func testPostsAreNewestFirstAcrossFeeds() {
        let snapshot = FeedWidgetSnapshot.make(feeds: [bakes, soups], entries: [
            bakes.url: [entry("bread", 300), entry("cake", 100)],
            soups.url: [entry("pho", 200, site: "soups"), entry("undated", nil, site: "soups")],
        ])
        XCTAssertEqual(snapshot.posts.map(\.title), ["bread", "pho", "cake", "undated"])
        XCTAssertEqual(snapshot.posts.map(\.source), ["Bakes", "Soups", "Bakes", "Soups"])
    }

    func testEachFeedKeepsOnlyItsNewestPosts() {
        let many = (0..<10).map { entry("post\($0)", TimeInterval(1000 - $0)) }
        let snapshot = FeedWidgetSnapshot.make(feeds: [bakes, soups], entries: [bakes.url: many, soups.url: [entry("pho", 1, site: "soups")]])
        XCTAssertEqual(snapshot.posts(from: bakes.url).count, FeedWidgetSnapshot.postsPerFeed)
        XCTAssertEqual(snapshot.posts(from: soups.url).map(\.title), ["pho"])
        XCTAssertEqual(snapshot.posts(from: nil).count, FeedWidgetSnapshot.postsPerFeed + 1)
    }

    func testUnfollowedFeedsAndRepeatedPostsAreDropped() {
        let snapshot = FeedWidgetSnapshot.make(feeds: [bakes], entries: [
            bakes.url: [entry("bread", 2), entry("bread", 1)],
            soups.url: [entry("pho", 3, site: "soups")],
        ])
        XCTAssertEqual(snapshot.posts.map(\.title), ["bread"])
    }

    func testViewedPostsAreHiddenAndNewerOnesFillIn() {
        let many = (0..<10).map { entry("post\($0)", TimeInterval(1000 - $0)) }
        let viewed: Set = [many[0].id, many[1].id, "https://bakes.example/gone"]
        let snapshot = FeedWidgetSnapshot.make(feeds: [bakes], entries: [bakes.url: many], viewed: viewed)
        XCTAssertEqual(snapshot.posts.map(\.title), (2..<8).map { "post\($0)" })
        XCTAssertEqual(snapshot.viewed, [many[0].id, many[1].id])
    }

    func testSavingKeepsPhotosOnlyForShownPosts() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetStore(directory: directory)
        let old = URL(string: "https://bakes.example/old.jpg")!, new = URL(string: "https://bakes.example/new.jpg")!
        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="))

        func snapshot(_ image: URL) -> FeedWidgetSnapshot {
            FeedWidgetSnapshot.make(feeds: [bakes], entries: [bakes.url: [FeedEntry(title: "bread", link: URL(string: "https://bakes.example/\(image.lastPathComponent)")!, imageURL: image)]])
        }
        try await store.saveFeeds(snapshot(old)) { _ in png }
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.feedImageURL(for: old).path))

        try await store.saveFeeds(snapshot(new)) { _ in png }
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.feedImageURL(for: old).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.feedImageURL(for: new).path))
        XCTAssertEqual(store.loadFeeds().posts.map(\.imageURL), [new])
    }
}
