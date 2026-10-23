import XCTest
@testable import RecipeKit

final class MealieLinkTests: XCTestCase {
    func testRoundTripsAServerAndToken() throws {
        let link = MealieLink(server: URL(string: "https://mealie.example.com/base")!, token: "a.b+c/d=e&f")
        XCTAssertEqual(MealieLink(url: link.url), link)
    }

    func testReadsABareHostAndTrimsTheToken() throws {
        let url = try XCTUnwrap(URL(string: "recipes://mealie?server=mealie.example.com/api&token=%20abc%20"))
        let link = try XCTUnwrap(MealieLink(url: url))
        XCTAssertEqual(link.server.absoluteString, "https://mealie.example.com")
        XCTAssertEqual(link.token, "abc")
    }

    func testRejectsLinksMissingAServerOrToken() throws {
        for text in [
            "recipes://mealie", "recipes://mealie?server=https://m.example.com", "recipes://mealie?token=abc",
            "recipes://mealie?server=https://m.example.com&token=", "recipes://mealie?server=ftp://m.example.com&token=abc",
            "recipes://recipe/\(UUID().uuidString)", "https://mealie?server=m.example.com&token=abc",
        ] {
            XCTAssertNil(MealieLink(url: URL(string: text)!), text)
        }
    }
}
