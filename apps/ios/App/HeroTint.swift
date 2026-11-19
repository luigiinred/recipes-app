import CoreImage
import SwiftUI

enum HeroTint {
    enum Edge: Hashable { case leading, bottom, center }

    /// The average colour along one edge (or the middle) of the image, darkened so white text reads on it.
    static func color(from image: CGImage, edge: Edge) -> Color? {
        let input = CIImage(cgImage: image)
        let extent = input.extent
        let strip = switch edge {
        case .leading: CGRect(x: extent.minX, y: extent.minY, width: extent.width * 0.2, height: extent.height)
        case .bottom: CGRect(x: extent.minX, y: extent.minY, width: extent.width, height: extent.height * 0.2)
        case .center: extent.insetBy(dx: extent.width * 0.2, dy: extent.height * 0.25)
        }
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: strip)]),
              let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let rgb = pixel.prefix(3).map { Double($0) / 255 }
        let luminance = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
        let scale = luminance > 0.2 ? 0.2 / luminance : 1
        return Color(red: rgb[0] * scale, green: rgb[1] * scale, blue: rgb[2] * scale)
    }
}
