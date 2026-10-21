import XCTest
import MetalRack
import MetalRackScene
import MetalKit

final class NativeAtlasTests: XCTestCase {
    private func atlasFixture() -> [String: Any] {
        ["metadata": ["format": 3], "frames": ["trimmed.png": [
            "textureRect": "{{4, 8}, {12, 20}}", "textureRotated": true,
            "spriteSize": "{20, 12}", "spriteSourceSize": "{32, 24}",
            "spriteOffset": "{4, -2}", "aliases": ["alias.png"]]]]
    }
    func testPackedPixelsStayPhysicalWhileDensityControlsGeometry() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext()
        renderer.attachNativeContext(context)
        let pixels = [UInt8](repeating: 0,count: 64*64*4)
        let texture = pixels.withUnsafeBytes { MRTexture(context: context,width: 64,height: 64,rgba: $0.baseAddress!)! }
        let atlas = MRAtlas()
        try atlas.addFrames(from: atlasFixture(),texture: texture,pixelsPerPoint: 4)
        let frame = try XCTUnwrap(atlas.frameNamed("trimmed.png"))
        XCTAssertTrue(frame === atlas.frameNamed("alias.png"))
        XCTAssertEqual(frame.pixelRect, CGRect(x: 4,y: 8,width: 12,height: 20))
        XCTAssertEqual(frame.originalSize, CGSize(width: 8,height: 6))
        XCTAssertEqual(frame.trimOffset, CGPoint(x: 1,y: -0.5))
        XCTAssertEqual(frame.pixelsPerPoint, 4)
        XCTAssertTrue(frame.rotated)
        atlas.removeAllFrames()
        XCTAssertTrue(atlas.frames.isEmpty)
        XCTAssertTrue(frame.texture === texture)
    }
    func testInvalidAtlasLeavesInstalledFramesUntouched() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext()
        renderer.attachNativeContext(context)
        let pixels = [UInt8](repeating: 0,count: 64*64*4)
        let texture = pixels.withUnsafeBytes { MRTexture(context: context,width: 64,height: 64,rgba: $0.baseAddress!)! }
        let atlas = MRAtlas()
        try atlas.addFrames(from: atlasFixture(),texture: texture,pixelsPerPoint: 4)
        let original = try XCTUnwrap(atlas.frameNamed("trimmed.png"))
        let invalid: [String: Any] = ["metadata": ["format": 3],"frames": ["bad.png": [
            "textureRect": "{{63, 63}, {12, 20}}","textureRotated": true,
            "spriteSize": "{20, 12}","spriteSourceSize": "{32, 24}","spriteOffset": "{0, 0}"]]]
        XCTAssertThrowsError(try atlas.addFrames(from: invalid,texture: texture,pixelsPerPoint: 4))
        XCTAssertEqual(atlas.frames.count, 2)
        XCTAssertTrue(atlas.frameNamed("trimmed.png") === original)
        XCTAssertNil(atlas.frameNamed("bad.png"))
        XCTAssertThrowsError(try atlas.addFrames(from: atlasFixture(),texture: texture,pixelsPerPoint: 0))
    }
}
