import XCTest
@testable import RecipeKit

/// Speaks the server's `/api/sync/files` protocol from memory, including its ETag preconditions.
private final class FakeServer: @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: (data: Data, mtimeMs: Double)] = [:]
    var token = "good-token"
    var failNextPutWith412 = false

    func put(_ path: String, _ text: String) {
        lock.lock(); defer { lock.unlock() }
        files[path] = (Data(text.utf8), Date().timeIntervalSince1970 * 1000)
    }

    func text(_ path: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return files[path].map { String(decoding: $0.data, as: UTF8.self) }
    }

    func remove(_ path: String) {
        lock.lock(); defer { lock.unlock() }
        files[path] = nil
    }

    var paths: [String] {
        lock.lock(); defer { lock.unlock() }
        return files.keys.sorted()
    }

    func handle(_ request: URLRequest, body: Data) -> (Int, Data) {
        lock.lock(); defer { lock.unlock() }
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer \(token)" else {
            return (401, Data(#"{"error":"Sign in required."}"#.utf8))
        }
        let components = request.url!.path.components(separatedBy: "/api/sync/files")
        let path = components.last!.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let etag = path.isEmpty ? nil : files[path].map { ServerSync.sha256($0.data) }
        let ifMatch = request.value(forHTTPHeaderField: "If-Match")?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let ifNoneMatch = request.value(forHTTPHeaderField: "If-None-Match")

        switch request.httpMethod ?? "GET" {
        case "GET" where path.isEmpty:
            let list = files.sorted { $0.key < $1.key }.map {
                #"{"path":"\#($0.key)","size":\#($0.value.data.count),"etag":"\#(ServerSync.sha256($0.value.data))","mtimeMs":\#($0.value.mtimeMs)}"#
            }
            return (200, Data(#"{"files":[\#(list.joined(separator: ","))],"serverTime":0}"#.utf8))
        case "GET":
            guard let file = files[path] else { return (404, Data(#"{"error":"No such library file."}"#.utf8)) }
            return (200, file.data)
        case "PUT":
            if failNextPutWith412 { failNextPutWith412 = false; return (412, Data()) }
            if ifNoneMatch == "*", etag != nil { return (412, Data()) }
            if let ifMatch, ifMatch != etag { return (412, Data()) }
            files[path] = (body, Date().timeIntervalSince1970 * 1000)
            return (200, Data("{}".utf8))
        case "DELETE":
            if let ifMatch, ifMatch != etag { return (412, Data()) }
            files[path] = nil
            return (204, Data())
        default:
            return (405, Data())
        }
    }
}

private final class FakeProtocol: URLProtocol {
    nonisolated(unsafe) static var server: FakeServer?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
            stream.close()
        }
        let (status, data) = Self.server!.handle(request, body: body)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ServerSyncTests: XCTestCase {
    private var root: URL!
    private var server: FakeServer!

    private let a = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private let b = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("serversync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        server = FakeServer()
        FakeProtocol.server = server
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        FakeProtocol.server = nil
    }

    private func makeSync(token: String = "good-token") -> ServerSync {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeProtocol.self]
        return ServerSync(root: root, server: URL(string: "http://recipes.test")!, token: token, session: URLSession(configuration: configuration))
    }

    private func doc(_ title: String, updatedAt: String = "2026-01-01T00:00:00Z") -> String {
        #"{"title":"\#(title)","updatedAt":"\#(updatedAt)"}"#
    }

    private func local(_ path: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func writeLocal(_ path: String, _ text: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func testFirstPassDownloadsEverythingTheServerHas() async throws {
        server.put("Recipes/\(a).json", doc("Soup"))
        server.put("Images/\(a).jpg", "jpeg-bytes")
        let report = try await makeSync().sync()
        XCTAssertEqual(report.downloaded, 2)
        XCTAssertEqual(local("Recipes/\(a).json"), doc("Soup"))
        XCTAssertEqual(local("Images/\(a).jpg"), "jpeg-bytes")
    }

    func testNewLocalFilesAreUploadedAndASecondPassDoesNothing() async throws {
        try writeLocal("Recipes/\(a).json", doc("Cake"))
        let sync = makeSync()
        let first = try await sync.sync()
        XCTAssertEqual(first.uploaded, 1)
        XCTAssertEqual(server.text("Recipes/\(a).json"), doc("Cake"))
        let second = try await sync.sync()
        XCTAssertEqual(second, ServerSync.Report())
    }

    func testEditsTravelInBothDirections() async throws {
        server.put("Recipes/\(a).json", doc("Soup"))
        try writeLocal("Recipes/\(b).json", doc("Pie"))
        let sync = makeSync()
        try await sync.sync()

        server.put("Recipes/\(a).json", doc("Better Soup", updatedAt: "2026-02-01T00:00:00Z"))
        try writeLocal("Recipes/\(b).json", doc("Best Pie", updatedAt: "2026-02-01T00:00:00Z"))
        let report = try await sync.sync()
        XCTAssertEqual(report.downloaded, 1)
        XCTAssertEqual(report.uploaded, 1)
        XCTAssertEqual(local("Recipes/\(a).json"), doc("Better Soup", updatedAt: "2026-02-01T00:00:00Z"))
        XCTAssertEqual(server.text("Recipes/\(b).json"), doc("Best Pie", updatedAt: "2026-02-01T00:00:00Z"))
    }

    func testDeletionsTravelToo() async throws {
        server.put("Recipes/\(a).json", doc("Soup"))
        server.put("Recipes/\(b).json", doc("Pie"))
        let sync = makeSync()
        try await sync.sync()

        try FileManager.default.removeItem(at: root.appendingPathComponent("Recipes/\(a).json"))
        server.remove("Recipes/\(b).json")
        let report = try await sync.sync()
        XCTAssertEqual(report.deletedOnServer, 1)
        XCTAssertEqual(report.deletedLocally, 1)
        XCTAssertNil(server.text("Recipes/\(a).json"))
        XCTAssertNil(local("Recipes/\(b).json"))
    }

    func testTheNewerEditWinsWhenBothSidesChanged() async throws {
        server.put("Recipes/\(a).json", doc("Original"))
        server.put("Recipes/\(b).json", doc("Original"))
        let sync = makeSync()
        try await sync.sync()

        server.put("Recipes/\(a).json", doc("Server edit", updatedAt: "2026-03-02T00:00:00Z"))
        try writeLocal("Recipes/\(a).json", doc("Phone edit", updatedAt: "2026-03-01T00:00:00Z"))
        server.put("Recipes/\(b).json", doc("Server edit", updatedAt: "2026-03-01T00:00:00Z"))
        try writeLocal("Recipes/\(b).json", doc("Phone edit", updatedAt: "2026-03-02T00:00:00Z"))

        let report = try await sync.sync()
        XCTAssertEqual(report.conflicts, 2)
        XCTAssertEqual(local("Recipes/\(a).json"), doc("Server edit", updatedAt: "2026-03-02T00:00:00Z"))
        XCTAssertEqual(server.text("Recipes/\(b).json"), doc("Phone edit", updatedAt: "2026-03-02T00:00:00Z"))
        let settled = try await sync.sync()
        XCTAssertEqual(settled, ServerSync.Report())
    }

    func testAnEditBeatsADeletionOnTheOtherSide() async throws {
        server.put("Recipes/\(a).json", doc("Soup"))
        let sync = makeSync()
        try await sync.sync()

        server.remove("Recipes/\(a).json")
        try writeLocal("Recipes/\(a).json", doc("Soup, improved", updatedAt: "2026-04-01T00:00:00Z"))
        try await sync.sync()
        XCTAssertEqual(server.text("Recipes/\(a).json"), doc("Soup, improved", updatedAt: "2026-04-01T00:00:00Z"))
    }

    func testARefusedUploadIsRetriedOnTheNextPass() async throws {
        try writeLocal("Recipes/\(a).json", doc("Cake"))
        let sync = makeSync()
        server.failNextPutWith412 = true
        let first = try await sync.sync()
        XCTAssertEqual(first.deferred, 1)
        XCTAssertNil(server.text("Recipes/\(a).json"))
        let second = try await sync.sync()
        XCTAssertEqual(second.uploaded, 1)
        XCTAssertEqual(server.text("Recipes/\(a).json"), doc("Cake"))
    }

    func testRefusesToDeleteMostOfALibraryByAccident() async throws {
        for index in 0..<30 {
            server.put("Recipes/00000000-0000-4000-8000-\(String(format: "%012d", index)).json", doc("R\(index)"))
        }
        let sync = makeSync()
        try await sync.sync()
        for path in server.paths { server.remove(path) }

        do {
            try await sync.sync()
            XCTFail("expected the guard to trip")
        } catch let error as ServerSync.SyncError {
            XCTAssertEqual(error, .tooManyDeletions(30))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Recipes").path).filter { $0.hasSuffix(".json") }.count, 30)

        let forced = try await sync.sync(allowMassDeletion: true)
        XCTAssertEqual(forced.deletedLocally, 30)
    }

    func testAWrongTokenIsReported() async throws {
        do {
            try await makeSync(token: "nope").sync()
            XCTFail("expected an authorization error")
        } catch let error as ServerSync.SyncError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func testOnlyLibraryFilesAreSynced() async throws {
        try writeLocal("Recipes/notes.txt", "not a recipe")
        try writeLocal("Recipes/\(a).json.tmp", "partial")
        try writeLocal("Recipes/\(a.uppercased()).json", doc("Upper"))
        let report = try await makeSync().sync()
        XCTAssertEqual(report.uploaded, 0)
        XCTAssertTrue(server.paths.isEmpty)
    }

    func testEditDateReadsUpdatedAtThenCreatedAt() {
        XCTAssertEqual(ServerSync.editDate(of: Data(#"{"updatedAt":"2026-01-02T03:04:05Z"}"#.utf8)), ISO8601DateFormatter().date(from: "2026-01-02T03:04:05Z"))
        XCTAssertEqual(ServerSync.editDate(of: Data(#"{"createdAt":"2026-01-02T03:04:05.250Z"}"#.utf8)).timeIntervalSince1970, 1_767_323_045.25, accuracy: 0.001)
        XCTAssertEqual(ServerSync.editDate(of: Data("nope".utf8)), .distantPast)
    }
}
