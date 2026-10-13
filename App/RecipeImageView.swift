import RecipeKit
import SwiftUI

struct RecipeImageView: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe

    @State private var loaded: CGImage?

    var body: some View {
        let image = library.cachedThumbnail(for: recipe.id) ?? loaded
        ZStack {
            LinearGradient(
                colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(Theme.accent.opacity(0.45))
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .task(id: library.imageStamps[recipe.id]) {
            loaded = await library.loadThumbnail(for: recipe.id)
        }
        .accessibilityHidden(true)
    }
}

enum AverageColor {
    static func of(_ image: CGImage) -> Color? {
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        return Color(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
    }
}
