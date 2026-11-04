import XCTest
@testable import RecipeKit

final class FeedCacheTests: XCTestCase {
    private var cache: FeedCache!

    override func setUp() {
        cache = FeedCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    override func tearDown() { cache.clear() }

    func testSavesAndReadsPosts() throws {
        let entry = FeedEntry(title: "Soup", link: URL(string: "https://example.com/soup")!, imageURL: URL(string: "https://example.com/soup.jpg"))
        try cache.save([entry], for: "https://example.com/feed")
        XCTAssertEqual(cache.snapshot(for: "https://example.com/feed")?.entries, [entry])
        XCTAssertNil(cache.snapshot(for: "https://other.com/feed"))
        XCTAssertNotNil(cache.lastUpdated)
    }

    func testPruneDropsUnfollowedFeedsAndTheirPhotos() throws {
        let kept = FeedEntry(title: "Kept", link: URL(string: "https://a.com/1")!, imageURL: URL(string: "https://a.com/1.jpg"))
        let dropped = FeedEntry(title: "Dropped", link: URL(string: "https://b.com/1")!, imageURL: URL(string: "https://b.com/1.jpg"))
        try cache.save([kept], for: "https://a.com/feed")
        try cache.save([dropped], for: "https://b.com/feed")
        try cache.savePhoto(Data([1]), for: kept.imageURL!)
        try cache.savePhoto(Data([2]), for: dropped.imageURL!)

        cache.prune(keeping: ["https://a.com/feed"])

        XCTAssertNotNil(cache.snapshot(for: "https://a.com/feed"))
        XCTAssertNil(cache.snapshot(for: "https://b.com/feed"))
        XCTAssertTrue(cache.hasPhoto(for: kept.imageURL!))
        XCTAssertFalse(cache.hasPhoto(for: dropped.imageURL!))
    }

    func testClearRemovesEverything() throws {
        try cache.save([], for: "https://a.com/feed")
        cache.clear()
        XCTAssertNil(cache.snapshot(for: "https://a.com/feed"))
        XCTAssertEqual(cache.byteCount, 0)
    }
}
