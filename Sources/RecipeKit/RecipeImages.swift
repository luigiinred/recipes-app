import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct RecipeImageStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString.lowercased()).jpg")
    }

    public func save(_ data: Data, for id: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileIO.write(data, to: fileURL(for: id))
    }

    public func data(for id: UUID) -> Data? {
        try? FileIO.read(fileURL(for: id))
    }

    public func delete(for id: UUID) throws {
        try FileIO.remove(fileURL(for: id))
    }

    /// Modification time of each stored image, so callers can tell when one changes.
    public func stamps() -> [UUID: Date] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: []
        ) else { return [:] }
        var result: [UUID: Date] = [:]
        for url in urls {
            if FileIO.startDownloadIfPlaceholder(url, in: directory) { continue }
            guard url.pathExtension == "jpg", let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            result[id] = date ?? .distantPast
        }
        return result
    }
}

public enum RecipeImageProcessing {
    /// JPEG, scaled so the longest side is at most `maxPixelSize`.
    public static func jpegData(from data: Data, maxPixelSize: Int = 1600, quality: CGFloat = 0.82) -> Data? {
        guard let image = thumbnail(from: data, maxPixelSize: maxPixelSize) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    public static func thumbnail(from data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    public static func download(_ urlString: String?, relativeTo base: URL? = nil) async -> Data? {
        guard let urlString, let url = URL(string: urlString, relativeTo: base)?.absoluteURL,
              url.scheme?.hasPrefix("http") == true else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              data.count < 15_000_000 else { return nil }
        return jpegData(from: data)
    }
}
