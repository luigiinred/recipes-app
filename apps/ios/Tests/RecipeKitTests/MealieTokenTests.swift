import XCTest
@testable import RecipeKit

final class MealieTokenTests: XCTestCase {
    func testCreatesATokenForTheSignedInUser() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TokenProtocol.self]
        TokenProtocol.reply = (201, Data(#"{"name":"Shared","id":7,"token":"new-secret"}"#.utf8))
        let client = MealieClient(server: URL(string: "https://mealie.test")!, token: "mine", session: URLSession(configuration: configuration))

        let token = try await client.createAPIToken(name: "Shared")

        XCTAssertEqual(token, "new-secret")
        let request = try XCTUnwrap(TokenProtocol.seen)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/users/api-tokens")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer mine")
        XCTAssertEqual(try XCTUnwrap(TokenProtocol.body), Data(#"{"name":"Shared"}"#.utf8))
    }

    func testAResponseWithoutATokenIsNotAcceptable() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TokenProtocol.self]
        TokenProtocol.reply = (201, Data(#"{"name":"Shared"}"#.utf8))
        let client = MealieClient(server: URL(string: "https://mealie.test")!, token: "mine", session: URLSession(configuration: configuration))

        do {
            _ = try await client.createAPIToken(name: "Shared")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? MealieError, .notMealie)
        }
    }
}

private final class TokenProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var reply = (200, Data())
    nonisolated(unsafe) static var seen: URLRequest?
    nonisolated(unsafe) static var body: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.seen = request
        Self.body = request.httpBody ?? request.httpBodyStream.map { stream in
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
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.reply.0, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.reply.1)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
