import CoreGraphics
import Foundation
import ImageIO
import Vision

public enum RecipeScanner {
    /// Blocking: call off the main thread.
    public static func recognizeText(in images: [CGImage]) throws -> String {
        var pages: [String] = []
        for image in images {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: image).perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            pages.append(lines.joined(separator: "\n"))
        }
        return pages.joined(separator: "\n")
    }

    /// The largest text in a photo, such as the product name on a box. Blocking: call off the main thread.
    public static func prominentTitle(in image: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let lines = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { (text: $0.string, height: Double(observation.boundingBox.height)) }
        }
        return prominentTitle(from: lines)
    }

    static func prominentTitle(from lines: [(text: String, height: Double)]) -> String? {
        let words = lines
            .map { (text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), height: $0.height) }
            .filter { $0.text.filter(\.isLetter).count >= 3 }
        guard let tallest = words.map(\.height).max() else { return nil }
        let title = words
            .filter { $0.height >= tallest * 0.75 }
            .prefix(3)
            .map { $0.text == $0.text.uppercased() ? $0.text.capitalized : $0.text }
            .joined(separator: " ")
        return String(title.prefix(60))
    }

    public static func recipe(fromImageAt url: URL) throws -> (recipe: Recipe, text: String) {
        let text = try recognizeText(in: try images(from: url))
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeError.invalid("No text found in that file.")
        }
        return (RecipeTextParser.parse(text), text)
    }

    public static func images(from url: URL) throws -> [CGImage] {
        if url.pathExtension.lowercased() == "pdf" { return try pdfPages(at: url) }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw RecipeError.invalid("Couldn't read an image from that file.")
        }
        return [image]
    }

    private static func pdfPages(at url: URL) throws -> [CGImage] {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else {
            throw RecipeError.invalid("Couldn't read that PDF.")
        }
        let scale: CGFloat = 2
        return (1...document.numberOfPages).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            let box = page.getBoxRect(.mediaBox)
            guard let context = CGContext(
                data: nil, width: Int(box.width * scale), height: Int(box.height * scale), bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: box.width * scale, height: box.height * scale))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -box.minX, y: -box.minY)
            context.drawPDFPage(page)
            return context.makeImage()
        }
    }
}
