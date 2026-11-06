import XCTest
@testable import RecipeKit

final class ViewedPostsTests: XCTestCase {
    func testInsertKeepsTheFirstMarkAndRemoveForgets() {
        var posts = ViewedPosts()
        let first = Date(timeIntervalSince1970: 100)
        posts.insert(["a", "b"], at: first)
        posts.insert(["a"], at: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(posts.dates["a"], first)
        XCTAssertEqual(posts.ids, ["a", "b"])

        posts.remove(["a"])
        XCTAssertFalse(posts.contains("a"))
        XCTAssertTrue(posts.contains("b"))
    }

    func testForgetsTheOldestPastTheLimit() {
        var posts = ViewedPosts()
        posts.insert(["oldest"], at: Date(timeIntervalSince1970: 0))
        posts.insert((0..<ViewedPosts.limit).map { "post-\($0)" }, at: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(posts.count, ViewedPosts.limit)
        XCTAssertFalse(posts.contains("oldest"))
        XCTAssertTrue(posts.contains("post-0"))
    }

    func testStoreRoundTrips() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("viewed.json")
        let store = ViewedPostsStore(file: file)
        XCTAssertEqual(store.load(), ViewedPosts())

        var posts = ViewedPosts()
        posts.insert(["https://example.com/soup"])
        try store.save(posts)
        XCTAssertEqual(store.load(), posts)
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }
}
