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
