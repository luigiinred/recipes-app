import Foundation
import RecipeKit
import Testing
@testable import Recipes

/// Sharing a server and browsing it, end to end, against a fake Mealie that only answers what a real one would.
@Suite("Mealie share and browse flow", .serialized)
@MainActor
struct MealieFlowTests {
    private let server = URL(string: "https://mealie.test")!
    private let session: URLSession

    init() {
        FakeMealieServer.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeMealieServer.self]
        session = URLSession(configuration: configuration)
    }

    @Test("a read-only link adds the server, browses it and copies a recipe into yours")
    func readOnlyLink() async throws {
        let shared = try await MealieClient(server: server, token: "owner", session: session).createAPIToken(name: "Recipes Discover shared")
        let sent = MealieLink(server: server, token: shared, kind: .discover)
        let opened = try #require(MealieLink(url: sent.url))
        #expect(opened.kind == .discover)

        let discover = DiscoverController(previewing: [], session: session)
        let source = try await discover.add(address: opened.server.absoluteString, token: opened.token)
        #expect(source.username == "sam")
        #expect(source.group == nil)

        let catalog = try #require(discover.catalog(for: source.id))
        await catalog.load()
        #expect(catalog.state == .loaded)
        let browsed = try #require(catalog.library.recipes.first)
        #expect(browsed.title == "Smoky Chili")
        #expect(browsed.ingredients.isEmpty)

        try await catalog.loadDetails(browsed.id)
        #expect(catalog.library.recipe(id: browsed.id)?.ingredients == ["2 cans black beans"])

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let mine = RecipeLibrary(opening: Library(root: root))
        await catalog.add(browsed.id, to: mine)

        #expect(catalog.problem == nil)
        #expect(catalog.added.contains(browsed.id))
        let copy = try #require(mine.recipes.first)
        #expect(mine.recipes.count == 1)
        #expect(copy.id != browsed.id)
        #expect(copy.title == "Smoky Chili")
        #expect(copy.steps == ["Simmer for 20 minutes."])
        #expect(FakeMealieServer.requests.allSatisfy { $0.method == "GET" || $0.path == "/api/users/api-tokens" })
        #expect(FakeMealieServer.requests.filter { $0.path.hasPrefix("/api/recipes") }.allSatisfy { $0.authorization == "Bearer \(shared)" })
    }

    @Test("a bare address browses the server's public recipes without a token")
    func publicAddress() async throws {
        let discover = DiscoverController(previewing: [], session: session)
        let source = try await discover.add(address: "mealie.test", token: "")
        #expect(source.group == "home")
        #expect(source.username == nil)

        let catalog = try #require(discover.catalog(for: source.id))
        await catalog.load()
        let browsed = try #require(catalog.library.recipes.first)
        try await catalog.loadDetails(browsed.id)
        #expect(catalog.library.recipe(id: browsed.id)?.steps == ["Simmer for 20 minutes."])
        #expect(FakeMealieServer.requests.allSatisfy { $0.authorization == nil })
        #expect(FakeMealieServer.requests.contains { $0.path == "/api/explore/groups/home/recipes/smoky-chili" })

        let link = try #require(source.link)
        #expect(MealieLink(url: link.url)?.group == "home")
    }

    @Test("a server with nothing public says so and isn't added")
    func privateServer() async throws {
        FakeMealieServer.isPublic = false
        let discover = DiscoverController(previewing: [], session: session)
        await #expect(throws: MealieError.notPublic) { try await discover.add(address: "mealie.test", token: "") }
        #expect(discover.sources.isEmpty)
    }

    @Test("the same server can be added more than once, each with its own name")
    func addedTwice() async throws {
        let discover = DiscoverController(previewing: [], session: session)
        let first = try await discover.add(address: "https://mealie.test", token: "owner", label: "My Mealie")
        let second = try await discover.add(address: "https://mealie.test", token: "friend")
        #expect(discover.sources.map(\.id) == [first.id, second.id])
        #expect(discover.sources.map(\.name) == ["My Mealie", "mealie.test"])

        discover.rename(second, to: "Friend's view")
        #expect(discover.sources.map(\.name) == ["My Mealie", "Friend's view"])
        discover.remove(first)
        #expect(discover.sources.map(\.name) == ["Friend's view"])
    }

    @Test("an invite link signs up a new user who then gets a token of their own")
    func inviteLink() async throws {
        let invitation = try await MealieClient(server: server, token: "owner", session: session).createInvitation()
        let opened = try #require(MealieLink(url: MealieLink(server: server, token: invitation, kind: .invite).url))
        #expect(opened.kind == .invite)

        let registration = MealieClient.Registration(fullName: "Test User", email: "test@example.com", username: "tester", password: "password123")
        let token = try await MealieClient.join(server: opened.server, invitation: opened.token, as: registration, tokenName: "Recipes", session: session)

        #expect(FakeMealieServer.registeredWith == invitation)
        #expect(token == "token-for-tester")
        let user = try await MealieClient(server: server, token: token, session: session).currentUser()
        #expect(user.username == "tester")
    }
}

private final class FakeMealieServer: URLProtocol, @unchecked Sendable {
    struct Request {
        var method: String
        var path: String
        var authorization: String?
    }

    static let recipeID = UUID(uuidString: "C0FFEE00-0000-4000-8000-000000000001")!.uuidString.lowercased()
    nonisolated(unsafe) static var requests: [Request] = []
    nonisolated(unsafe) static var isPublic = true
    nonisolated(unsafe) static var registeredWith: String?

    static func reset() {
        requests = []
        isPublic = true
        registeredWith = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let authorization = request.value(forHTTPHeaderField: "Authorization")
        Self.requests.append(Request(method: method, path: path, authorization: authorization))
        let (status, body) = Self.answer(method, path, authorization: authorization, body: request.httpBody ?? request.httpBodyStream.map(Self.read))
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: (try? JSONSerialization.data(withJSONObject: body)) ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    private static var summary: [String: Any] {
        ["id": recipeID, "slug": "smoky-chili", "name": "Smoky Chili", "description": "Weeknight chili.", "image": NSNull()]
    }

    private static var full: [String: Any] {
        summary.merging([
            "recipeIngredient": [["note": "2 cans black beans", "display": "2 cans black beans"]],
            "recipeInstructions": [["text": "Simmer for 20 minutes."]],
        ]) { _, new in new }
    }

    private static func page(_ items: [[String: Any]]) -> [String: Any] { ["items": items, "total_pages": 1] }

    private static func answer(_ method: String, _ path: String, authorization: String?, body: Data?) -> (Int, Any) {
        let signedIn = authorization != nil
        switch (method, path) {
        case ("GET", "/api/app/about"):
            return (200, ["defaultGroupSlug": NSNull()])
        case ("GET", "/api/explore/groups/home/recipes"):
            if !isPublic { return (404, ["detail": "group not found"]) }
            return (200, page([summary]))
        case ("GET", "/api/explore/groups/home/recipes/smoky-chili"):
            if !isPublic { return (404, ["detail": "recipe not found"]) }
            return (200, full)
        case ("POST", "/api/auth/token"):
            return (200, ["access_token": "session-tester", "token_type": "bearer"])
        case ("POST", "/api/users/register"):
            let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            registeredWith = json?["groupToken"] as? String
            return (201, ["id": "u-tester", "username": "tester"])
        case _ where !signedIn:
            return (401, ["detail": "Not authenticated"])
        case ("GET", "/api/users/self"):
            let tester = authorization == "Bearer token-for-tester"
            return (200, ["id": tester ? "u-tester" : "u-sam", "username": tester ? "tester" : "sam", "groupSlug": "home"])
        case ("POST", "/api/users/api-tokens"):
            return (201, ["name": "Recipes", "token": authorization == "Bearer session-tester" ? "token-for-tester" : "shared-\(requests.count)"])
        case ("POST", "/api/households/invitations"):
            return (201, ["token": "invite-1", "usesLeft": 1])
        case ("GET", "/api/recipes"):
            return (200, page([summary]))
        case ("GET", "/api/recipes/smoky-chili"):
            return (200, full)
        default:
            return (404, ["detail": "Not Found"])
        }
    }

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
