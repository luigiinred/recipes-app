import XCTest
@testable import RecipeKit

final class MealieInviteTests: XCTestCase {
    private let server = URL(string: "https://mealie.test")!

    override func tearDown() {
        InviteProtocol.reset()
        super.tearDown()
    }

    private var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InviteProtocol.self]
        return URLSession(configuration: configuration)
    }

    func testMakesAHouseholdInvitation() async throws {
        InviteProtocol.replies["/api/households/invitations"] = (201, #"{"token":"invite-1","usesLeft":1}"#)
        let token = try await MealieClient(server: server, token: "mine", session: session).createInvitation()

        XCTAssertEqual(token, "invite-1")
        let request = try XCTUnwrap(InviteProtocol.seen.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.authorization, "Bearer mine")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: request.body) as? [String: Int], ["uses": 1])
    }

    func testFallsBackToGroupInvitationsOnOlderServers() async throws {
        InviteProtocol.replies["/api/households/invitations"] = (404, #"{"detail":"Not Found"}"#)
        InviteProtocol.replies["/api/groups/invitations"] = (201, #"{"token":"invite-old"}"#)
        let token = try await MealieClient(server: server, token: "mine", session: session).createInvitation()

        XCTAssertEqual(token, "invite-old")
        XCTAssertEqual(InviteProtocol.seen.map(\.path), ["/api/households/invitations", "/api/groups/invitations"])
    }

    func testJoiningRegistersSignsInAndMakesAToken() async throws {
        InviteProtocol.replies["/api/users/register"] = (201, #"{"id":"u2","username":"sam"}"#)
        InviteProtocol.replies["/api/auth/token"] = (200, #"{"access_token":"session-jwt","token_type":"bearer"}"#)
        InviteProtocol.replies["/api/users/api-tokens"] = (201, #"{"name":"Recipes","token":"sam-token"}"#)
        let registration = MealieClient.Registration(fullName: "Sam", email: "sam@example.com", username: "sam", password: "p&ss+word=1")

        let token = try await MealieClient.join(server: server, invitation: "invite-1", as: registration, tokenName: "Recipes", session: session)

        XCTAssertEqual(token, "sam-token")
        XCTAssertEqual(InviteProtocol.seen.map(\.path), ["/api/users/register", "/api/auth/token", "/api/users/api-tokens"])
        let register = InviteProtocol.seen[0]
        XCTAssertNil(register.authorization)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: register.body) as? [String: Any])
        XCTAssertEqual(body["groupToken"] as? String, "invite-1")
        XCTAssertEqual(body["passwordConfirm"] as? String, "p&ss+word=1")
        let signIn = InviteProtocol.seen[1]
        XCTAssertEqual(signIn.contentType, "application/x-www-form-urlencoded")
        XCTAssertEqual(String(decoding: signIn.body, as: UTF8.self), "username=sam&password=p%26ss%2Bword%3D1")
        XCTAssertEqual(InviteProtocol.seen[2].authorization, "Bearer session-jwt")
    }

    func testAnInviteLinkRoundTrips() throws {
        let link = MealieLink(server: server, token: "invite-1", kind: .invite)
        XCTAssertEqual(link.url.host, "mealie-invite")
        XCTAssertEqual(MealieLink(url: link.url), link)
    }
}

private final class InviteProtocol: URLProtocol, @unchecked Sendable {
    struct Seen {
        var method: String
        var path: String
        var authorization: String?
        var contentType: String?
        var body: Data
    }

    nonisolated(unsafe) static var replies: [String: (Int, String)] = [:]
    nonisolated(unsafe) static var seen: [Seen] = []

    static func reset() {
        replies = [:]
        seen = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.seen.append(Seen(
            method: request.httpMethod ?? "", path: path,
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            contentType: request.value(forHTTPHeaderField: "Content-Type"),
            body: request.httpBody ?? request.httpBodyStream.map(Self.read) ?? Data()
        ))
        let (status, text) = Self.replies[path] ?? (404, #"{"detail":"Not Found"}"#)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(text.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class MealiePublicPageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PublicProtocol.paths = []
        PublicProtocol.authorization = nil
    }

    func testReadsTheServerAndGroupFromAPublicPage() throws {
        let page = try XCTUnwrap(MealieClient.publicPage("mealie.example.com/g/home/r/tomato-soup"))
        XCTAssertEqual(page.server.absoluteString, "https://mealie.example.com")
        XCTAssertEqual(page.group, "home")
        let nested = try XCTUnwrap(MealieClient.publicPage("https://example.com/mealie/g/family"))
        XCTAssertEqual(nested.server.absoluteString, "https://example.com/mealie")
        XCTAssertEqual(nested.group, "family")
        XCTAssertNil(MealieClient.publicPage("https://mealie.example.com"))
        XCTAssertNil(MealieClient.publicPage("https://mealie.example.com/g"))
    }

    func testAPublicDiscoverLinkNeedsNoToken() throws {
        let link = MealieLink(server: URL(string: "https://mealie.example.com")!, token: "", kind: .discover, group: "home")
        XCTAssertFalse(link.url.absoluteString.contains("token"))
        XCTAssertEqual(MealieLink(url: link.url), link)
        XCTAssertNil(MealieLink(url: URL(string: "recipes://mealie?server=m.example.com&group=home")!))
    }

    func testBrowsesAPublicGroupWithoutSigningIn() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicProtocol.self]
        let browser = MealieBrowser(
            server: URL(string: "https://mealie.test")!, token: "", group: "home", session: URLSession(configuration: configuration)
        )
        let entries = try await browser.recipes()
        XCTAssertEqual(entries.map(\.slug), ["soup"])
        XCTAssertEqual(PublicProtocol.paths, ["/api/explore/groups/home/recipes"])
        XCTAssertNil(PublicProtocol.authorization)
    }

    func testABareAddressBrowsesTheDefaultGroup() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicProtocol.self]
        let client = MealieClient(server: URL(string: "https://mealie.test")!, token: "", session: URLSession(configuration: configuration))
        PublicProtocol.about = #"{"defaultGroupSlug":"family"}"#
        let named = await client.defaultGroup()
        PublicProtocol.about = #"{"defaultGroupSlug":null}"#
        let unnamed = await client.defaultGroup()
        XCTAssertEqual([named, unnamed], ["family", "home"])
    }

    func testAPrivateGroupSaysSo() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicProtocol.self]
        let browser = MealieBrowser(
            server: URL(string: "https://mealie.test")!, token: "", group: "secret", session: URLSession(configuration: configuration)
        )
        do {
            _ = try await browser.check()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? MealieError, .notPublic)
        }
    }
}

private final class PublicProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var paths: [String] = []
    nonisolated(unsafe) static var authorization: String?
    nonisolated(unsafe) static var about = "{}"

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.paths.append(path)
        Self.authorization = request.value(forHTTPHeaderField: "Authorization")
        let found = path == "/api/explore/groups/home/recipes" || path == "/api/app/about"
        let body = path == "/api/app/about" ? Self.about : found
            ? #"{"items":[{"id":"\#(UUID().uuidString.lowercased())","slug":"soup","name":"Soup"}],"total_pages":1}"#
            : #"{"detail":"group not found"}"#
        let response = HTTPURLResponse(url: request.url!, statusCode: found ? 200 : 404, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
