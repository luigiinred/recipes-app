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
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(trimmingLetterbox)
    }

    /// Crops matching black bars off opposite edges, such as the ones baked into YouTube's 4:3 thumbnails. A one-sided dark
    /// edge is left alone, since that is more likely part of the photo.
    static func trimmingLetterbox(_ image: CGImage) -> CGImage {
        let width = image.width, height = image.height
        guard width >= 16, height >= 16,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
              ), let base = context.data else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        func isBlack(_ count: Int, _ brightAt: (Int) -> UInt8) -> Bool {
            var bright = 0
            for index in 0..<count where brightAt(index) > 40 { bright += 1 }
            return bright * 100 <= count
        }
        func bars(length: Int, isBlackAt: (Int) -> Bool) -> (leading: Int, trailing: Int) {
            var leading = 0, trailing = 0
            while leading < length, isBlackAt(leading) { leading += 1 }
            while trailing < length - leading, isBlackAt(length - 1 - trailing) { trailing += 1 }
            return (leading, trailing)
        }

        let rows = bars(length: height) { row in isBlack(width) { pixels[row * width + $0] } }
        let columns = bars(length: width) { column in isBlack(height) { pixels[$0 * width + column] } }
        let minimum = { (length: Int) in max(2, length / 33) }
        var rect = CGRect(x: 0, y: 0, width: width, height: height)
        if rows.leading >= minimum(height), rows.trailing >= minimum(height) {
            rect = CGRect(x: 0, y: rows.leading, width: width, height: height - rows.leading - rows.trailing)
        } else if columns.leading >= minimum(width), columns.trailing >= minimum(width) {
            rect = CGRect(x: columns.leading, y: 0, width: width - columns.leading - columns.trailing, height: height)
        }
        guard rect.width * rect.height >= CGFloat(width * height) / 2, rect.size != CGSize(width: width, height: height),
              let cropped = image.cropping(to: rect) else { return image }
        return cropped
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
