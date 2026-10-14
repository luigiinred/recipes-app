import CoreGraphics
import XCTest
@testable import RecipeKit

final class ImageTrimTests: XCTestCase {
    private func image(width: Int, height: Int, bright: (Int, Int) -> Bool) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height { for x in 0..<width { pixels[y * width + x] = bright(x, y) ? 200 : 0 } }
        return context.makeImage()!
    }

    func testBarsAboveAndBelowAreCropped() {
        let result = RecipeImageProcessing.trimmingLetterbox(image(width: 120, height: 90) { _, y in (12..<78).contains(y) })
        XCTAssertEqual(result.width, 120)
        XCTAssertEqual(result.height, 66)
    }

    func testBarsLeftAndRightAreCropped() {
        let result = RecipeImageProcessing.trimmingLetterbox(image(width: 120, height: 90) { x, _ in (20..<100).contains(x) })
        XCTAssertEqual(result.width, 80)
        XCTAssertEqual(result.height, 90)
    }

    func testDarkEdgeOnOneSideIsKept() {
        let result = RecipeImageProcessing.trimmingLetterbox(image(width: 120, height: 90) { _, y in y >= 20 })
        XCTAssertEqual(result.height, 90)
    }

    func testNormalPhotoIsUntouched() {
        let result = RecipeImageProcessing.trimmingLetterbox(image(width: 120, height: 90) { _, _ in true })
        XCTAssertEqual(result.width, 120)
        XCTAssertEqual(result.height, 90)
    }
}
