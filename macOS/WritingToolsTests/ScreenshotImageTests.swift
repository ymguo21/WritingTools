import AppKit
import XCTest
@testable import WritingTools

final class ScreenshotImageTests: XCTestCase {
    private func png(width: Int, height: Int) throws -> Data {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    private func size(of data: Data) throws -> (width: Int, height: Int) {
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        return (rep.pixelsWide, rep.pixelsHigh)
    }

    func testLargeImageIsScaledToTheLimitKeepingAspectRatio() throws {
        let scaled = ScreenshotImage.downscaled(try png(width: 4000, height: 1000), maxLongEdge: 2000)
        let result = try size(of: scaled)
        XCTAssertEqual(result.width, 2000)
        XCTAssertEqual(result.height, 500)
    }

    func testSmallImageIsReturnedUnchanged() throws {
        let original = try png(width: 800, height: 600)
        XCTAssertEqual(ScreenshotImage.downscaled(original, maxLongEdge: 2000), original)
    }

    func testUndecodableDataIsReturnedUnchanged() {
        let garbage = Data([1, 2, 3, 4])
        XCTAssertEqual(ScreenshotImage.downscaled(garbage), garbage)
    }
}
