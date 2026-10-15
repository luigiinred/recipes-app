import Foundation

enum FileIO {
    static func read(_ url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError, byAccessor: { (url: URL) in
            result = Result { try Data(contentsOf: url) }
        })
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    static func write(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError, byAccessor: { (url: URL) in
            result = Result { try data.write(to: url, options: .atomic) }
        })
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    static func remove(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var coordinationError: NSError?
        var result: Result<Void, Error> = .success(())
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError, byAccessor: { (url: URL) in
            result = Result { try FileManager.default.removeItem(at: url) }
        })
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    /// Asks iCloud to fetch files that are only placeholders on this device.
    static func startDownloadIfPlaceholder(_ url: URL, in directory: URL) -> Bool {
        let name = url.lastPathComponent
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return false }
        let real = String(name.dropFirst().dropLast(".icloud".count))
        try? FileManager.default.startDownloadingUbiquitousItem(at: directory.appendingPathComponent(real))
        return true
    }
}
