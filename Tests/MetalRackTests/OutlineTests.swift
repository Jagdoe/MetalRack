import XCTest
import MetalRackImageProcessing

final class OutlineTests: XCTestCase {
    func testOutlineMatchesNearestSilhouetteDistance() {
        let width = 19, height = 23
        for sample in 0..<16 {
            let radius = sample % 6 + 1
            var source = [UInt8](repeating: 0, count: width * height * 4)
            for y in 0..<height { for x in 0..<width {
                source[(y * width + x) * 4 + 3] = sample == 0 ? 0 : sample == 1 ? 255 : UInt8((x * 73 + y * 47 + sample * 19) % 256)
            }}
            var output = source
            source.withUnsafeBufferPointer { input in
                output.withUnsafeMutableBufferPointer { result in
                    MRCreateOutlineMask(input.baseAddress, Int32(width), Int32(height), Int32(radius), result.baseAddress)
                }
            }
            for y in 0..<height { for x in 0..<width {
                var nearest = Int.max
                for sy in 0..<height { for sx in 0..<width where source[(sy * width + sx) * 4 + 3] >= 128 {
                    nearest = min(nearest, (sx-x)*(sx-x) + (sy-y)*(sy-y))
                }}
                let expected: UInt8 = source[(y * width + x) * 4 + 3] < 128 && nearest <= radius * radius ? 255 : 0
                XCTAssertEqual(Array(output[(y * width + x) * 4..<(y * width + x + 1) * 4]), [UInt8](repeating: expected, count: 4))
            }}
        }
    }

    func testInteriorHoleHasAnOutlineAndClearCenter() {
        let width = 21
        var source = [UInt8](repeating: 0, count: width * width * 4)
        for y in 3..<18 { for x in 3..<18 where x < 6 || x >= 15 || y < 6 || y >= 15 {
            source[(y * width + x) * 4 + 3] = 255
        }}
        var output = source
        source.withUnsafeBufferPointer { input in
            output.withUnsafeMutableBufferPointer { result in
                MRCreateOutlineMask(input.baseAddress, Int32(width), Int32(width), 2, result.baseAddress)
            }
        }
        XCTAssertEqual(output[(10 * width + 10) * 4 + 3], 0)
        XCTAssertEqual(output[(10 * width + 6) * 4 + 3], 255)
    }
}
