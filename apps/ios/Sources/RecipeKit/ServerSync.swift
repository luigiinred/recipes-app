import CryptoKit
import Foundation

/// Keeps a library folder in step with a self-hosted Recipes server (see `apps/server`).
///
/// The folder layout is the iCloud one, so each pass is a three-way comparison of every file: what is on disk now,
/// what the server has, and what both had after the last pass. Whoever changed since then wins; when both changed,
/// the newer edit wins. Nothing here needs tombstones on the server.
public struct ServerSync: Sendable {
    public struct Report: Codable, Equatable, Sendable {
        public var uploaded = 0
        public var downloaded = 0
        public var deletedLocally = 0
        public var deletedOnServer = 0
        /// Files edited on both sides since the last pass; the newer edit was kept.
        public var conflicts = 0
        /// Files the server changed while this pass ran; they sync on the next one.
        public var deferred = 0

        public init() {}

        public var changedAnything: Bool { uploaded + downloaded + deletedLocally + deletedOnServer > 0 }
    }

    public enum SyncError: LocalizedError, Equatable {
        case unauthorized
        case unreachable(String)
        case server(Int, String)
        case tooManyDeletions(Int)

        public var errorDescription: String? {
            switch self {
            case .unauthorized: "The server didn't accept the access token."
            case .unreachable(let reason): "Couldn't reach the server: \(reason)"
            case .server(let status, let message): "The server answered \(status): \(message)"
            case .tooManyDeletions(let count): "This would delete \(count) files, which looks like a mistake. Nothing was changed."
            }
        }
    }

    /// Folder names and file extensions, as the server's `LIBRARY_DIRS` lists them.
    static let directories: [(name: String, fileExtension: String)] = [
        ("Recipes", "json"), ("Calendar", "json"), ("Groceries", "json"), ("Feeds", "json"),
        ("Images", "jpg"), ("StepImages", "jpg"),
    ]

    static let stateFileName = ".sync-state.json"
    private static let maxConcurrentTransfers = 6

    public let root: URL
    public let server: URL
    private let token: String
    private let session: URLSession

    public init(root: URL, server: URL, token: String, session: URLSession = .shared) {
        self.root = root
        self.server = server
        self.token = token
        self.session = session
    }

    // MARK: - Pass

    @discardableResult
    public func sync(allowMassDeletion: Bool = false) async throws -> Report {
        for directory in Self.directories {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(directory.name), withIntermediateDirectories: true)
        }
        var state = loadState()
        let remote = try await listRemote()
        let local = try scanLocal(known: state.files)

        var report = Report()
        var actions: [Action] = []
        var known = state.files

        for path in Set(local.keys).union(remote.keys).union(known.keys).sorted() {
            let l = local[path], r = remote[path]
            let base = known[path]?.hash
            if let l, let r, l.hash == r.etag {
                known[path] = Known(l)
                continue
            }
            if l == nil, r == nil {
                known[path] = nil
                continue
            }
            let localChanged = l?.hash != base
            let remoteChanged = r?.etag != base
            switch (localChanged, remoteChanged) {
            case (true, false):
                if l != nil { actions.append(.upload(path, ifMatch: r?.etag)) } else if let r { actions.append(.deleteRemote(path, ifMatch: r.etag)) }
            case (false, true):
                if let r { actions.append(.download(path, remote: r)) } else { actions.append(.deleteLocal(path)) }
            case (true, true):
                if let l, let r {
                    actions.append(.resolve(path, local: l, remote: r))
                } else if let r {
                    actions.append(.download(path, remote: r))
                } else {
                    actions.append(.upload(path, ifMatch: nil))
                }
            case (false, false):
                break
            }
        }

        let deletions = actions.filter { if case .deleteLocal = $0 { true } else if case .deleteRemote = $0 { true } else { false } }.count
        if !allowMassDeletion, deletions > max(10, known.count / 2) { throw SyncError.tooManyDeletions(deletions) }

        var index = 0
        while index < actions.count {
            let batch = Array(actions[index..<min(index + Self.maxConcurrentTransfers, actions.count)])
            index += batch.count
            let outcomes = try await withThrowingTaskGroup(of: Outcome.self) { group in
                for action in batch { group.addTask { try await perform(action) } }
                var collected: [Outcome] = []
                for try await outcome in group { collected.append(outcome) }
                return collected
            }
            for outcome in outcomes {
                switch outcome.result {
                case .synced(let entry): known[outcome.path] = entry
                case .gone: known[outcome.path] = nil
                case .deferred: break
                }
                outcome.tally(into: &report)
            }
        }

        state.files = known
        saveState(state)
        return report
    }

    // MARK: - Planning types

    private struct LocalFile {
        var hash: String
        var mtime: Double
        var size: Int
    }

    private struct RemoteFile: Decodable {
        var path: String
        var size: Int
        var etag: String
        var mtimeMs: Double
    }

    private struct Known: Codable {
        var hash: String
        var mtime: Double
        var size: Int

        init(_ file: LocalFile) {
            hash = file.hash
            mtime = file.mtime
            size = file.size
        }

        init(hash: String, mtime: Double, size: Int) {
            self.hash = hash
            self.mtime = mtime
            self.size = size
        }
    }

    private struct State: Codable {
        var server: String
        var files: [String: Known]
    }

    private enum Action {
        case upload(String, ifMatch: String?)
        case download(String, remote: RemoteFile)
        case deleteRemote(String, ifMatch: String)
        case deleteLocal(String)
        case resolve(String, local: LocalFile, remote: RemoteFile)
    }

    private struct Outcome {
        enum Result {
            case synced(Known)
            case gone
            case deferred
        }

        enum Kind { case upload, download, deleteLocal, deleteRemote, conflictKeptLocal, conflictKeptRemote }

        var path: String
        var result: Result
        var kind: Kind

        func tally(into report: inout Report) {
            if case .deferred = result {
                report.deferred += 1
                return
            }
            switch kind {
            case .upload: report.uploaded += 1
            case .download: report.downloaded += 1
            case .deleteLocal: report.deletedLocally += 1
            case .deleteRemote: report.deletedOnServer += 1
            case .conflictKeptLocal: report.conflicts += 1; report.uploaded += 1
            case .conflictKeptRemote: report.conflicts += 1; report.downloaded += 1
            }
        }
    }

    // MARK: - Execution

    private func perform(_ action: Action) async throws -> Outcome {
        switch action {
        case .upload(let path, let ifMatch):
            return try await upload(path, ifMatch: ifMatch, kind: .upload)
        case .download(let path, let remote):
            return try await download(path, remote: remote, kind: .download)
        case .deleteRemote(let path, let ifMatch):
            let (_, response) = try await send("DELETE", path, headers: ["If-Match": "\"\(ifMatch)\""])
            if response.statusCode == 412 { return Outcome(path: path, result: .deferred, kind: .deleteRemote) }
            return Outcome(path: path, result: .gone, kind: .deleteRemote)
        case .deleteLocal(let path):
            try FileIO.remove(fileURL(path))
            return Outcome(path: path, result: .gone, kind: .deleteLocal)
        case .resolve(let path, let local, let remote):
            return try await resolve(path, local: local, remote: remote)
        }
    }

    private func upload(_ path: String, ifMatch: String?, kind: Outcome.Kind) async throws -> Outcome {
        let url = fileURL(path)
        let data = try FileIO.read(url)
        let condition = ifMatch.map { ["If-Match": "\"\($0)\""] } ?? ["If-None-Match": "*"]
        let (_, response) = try await send("PUT", path, body: data, headers: condition)
        if response.statusCode == 412 { return Outcome(path: path, result: .deferred, kind: kind) }
        return Outcome(path: path, result: .synced(Known(hash: Self.sha256(data), mtime: Self.mtime(of: url), size: data.count)), kind: kind)
    }

    private func download(_ path: String, remote: RemoteFile, kind: Outcome.Kind) async throws -> Outcome {
        let (data, _) = try await send("GET", path)
        let url = fileURL(path)
        try FileIO.write(data, to: url)
        return Outcome(path: path, result: .synced(Known(hash: Self.sha256(data), mtime: Self.mtime(of: url), size: data.count)), kind: kind)
    }

    /// Both sides changed the same file: documents keep the later `updatedAt`, photos the later modification time.
    private func resolve(_ path: String, local: LocalFile, remote: RemoteFile) async throws -> Outcome {
        let localData = try FileIO.read(fileURL(path))
        let (remoteData, _) = try await send("GET", path)
        let keepLocal: Bool
        if path.hasSuffix(".json") {
            keepLocal = Self.editDate(of: localData) > Self.editDate(of: remoteData)
        } else {
            keepLocal = Date(timeIntervalSince1970: local.mtime) > Date(timeIntervalSince1970: remote.mtimeMs / 1000)
        }
        if keepLocal { return try await upload(path, ifMatch: remote.etag, kind: .conflictKeptLocal) }
        let url = fileURL(path)
        try FileIO.write(remoteData, to: url)
        return Outcome(
            path: path,
            result: .synced(Known(hash: Self.sha256(remoteData), mtime: Self.mtime(of: url), size: remoteData.count)),
            kind: .conflictKeptRemote
        )
    }

    // MARK: - Server

    private func listRemote() async throws -> [String: RemoteFile] {
        struct Listing: Decodable { var files: [RemoteFile] }
        let (data, _) = try await send("GET", nil)
        guard let listing = try? JSONDecoder().decode(Listing.self, from: data) else {
            throw SyncError.server(200, "That doesn't look like a Recipes server.")
        }
        return Dictionary(listing.files.map { ($0.path, $0) }, uniquingKeysWith: { $1 })
    }

    /// 412 is returned to the caller (a precondition lost a race); every other failure throws.
    private func send(_ method: String, _ path: String?, body: Data? = nil, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var url = server.appendingPathComponent("api/sync/files")
        if let path {
            for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SyncError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw SyncError.server(0, "No response.") }
        switch http.statusCode {
        case 200..<300, 412: return (data, http)
        case 401: throw SyncError.unauthorized
        default:
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw SyncError.server(http.statusCode, message ?? "Unexpected response.")
        }
    }

    // MARK: - Disk

    private func fileURL(_ path: String) -> URL {
        root.appendingPathComponent(path)
    }

    private func scanLocal(known: [String: Known]) throws -> [String: LocalFile] {
        var result: [String: LocalFile] = [:]
        let pattern = try NSRegularExpression(pattern: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(json|jpg)$"#)
        for directory in Self.directories {
            let folder = root.appendingPathComponent(directory.name)
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            for url in urls {
                let name = url.lastPathComponent
                guard url.pathExtension == directory.fileExtension,
                      pattern.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil else { continue }
                let path = "\(directory.name)/\(name)"
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let mtime = values.contentModificationDate?.timeIntervalSince1970 ?? 0
                let size = values.fileSize ?? 0
                if let seen = known[path], seen.mtime == mtime, seen.size == size {
                    result[path] = LocalFile(hash: seen.hash, mtime: mtime, size: size)
                } else {
                    result[path] = LocalFile(hash: Self.sha256(try FileIO.read(url)), mtime: mtime, size: size)
                }
            }
        }
        return result
    }

    private var stateURL: URL { root.appendingPathComponent(Self.stateFileName) }

    private func loadState() -> State {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(State.self, from: data),
              state.server == server.absoluteString else { return State(server: server.absoluteString, files: [:]) }
        return state
    }

    private func saveState(_ state: State) {
        if let data = try? JSONEncoder().encode(state) { try? data.write(to: stateURL, options: .atomic) }
    }

    // MARK: - Helpers

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func mtime(of url: URL) -> Double {
        ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()).timeIntervalSince1970
    }

    /// When a document was last edited, from its `updatedAt` (or `createdAt` for documents without one).
    static func editDate(of data: Data) -> Date {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .distantPast }
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for key in ["updatedAt", "createdAt"] {
            if let text = object[key] as? String, let date = plain.date(from: text) ?? fractional.date(from: text) { return date }
        }
        return .distantPast
    }
}
