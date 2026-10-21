import XCTest
import ImageIO
import MetalKit
import MetalRack
import MetalRackScene

final class NativeResourceTests: XCTestCase {
    private func writeImage(_ url: URL) throws {
        let rgba: [UInt8] = [255,0,0,255, 0,255,0,255, 0,0,255,255,
                             255,0,0,128, 0,0,0,0, 255,255,255,255]
        let provider = try XCTUnwrap(CGDataProvider(data: Data(rgba) as CFData))
        let image = try XCTUnwrap(CGImage(width: 3,height: 2,bitsPerComponent: 8,bitsPerPixel: 32,
            bytesPerRow: 12,space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,decode: nil,shouldInterpolate: false,intent: .defaultIntent))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil))
        CGImageDestinationAddImage(destination,image,nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
    private func writeAtlas(_ url: URL, image: String, rect: String = "{{1, 0}, {2, 2}}") throws {
        let dictionary: [String: Any] = ["metadata": ["format": 3,"textureFileName": image],
            "frames": ["icon.png": ["textureRect": rect,"textureRotated": false,
                "spriteSize": "{2, 2}","spriteSourceSize": "{4, 4}","spriteOffset": "{0, 0}","aliases": ["alias.png"]]]]
        try PropertyListSerialization.data(fromPropertyList: dictionary,format: .xml,options: 0).write(to: url)
    }
    private func directory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MetalRackResources-\(UUID().uuidString)",isDirectory: true)
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        return directory
    }
    func testPNGOrientationPremultiplicationAndUnpaddedCache() throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeImage(directory.appendingPathComponent("tile.png"))
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let resources = MRSceneResources(context: context,baseURL: directory)
        let texture = try XCTUnwrap(try resources.textureNamed("tile.png"))
        let same = try XCTUnwrap(try resources.texture(at: directory.appendingPathComponent("./tile.png")))
        XCTAssertTrue(texture === same)
        XCTAssertEqual(texture.pixelSize, CGSize(width: 3,height: 2))
        var pixels = [UInt8](repeating: 0,count: 24)
        pixels.withUnsafeMutableBytes { context.readTexture(texture.identifier,rect: CGRect(x: 0,y: 0,width: 3,height: 2),rgba: $0.baseAddress!) }
        XCTAssertEqual(Array(pixels[0..<12]), [255,0,0,255, 0,255,0,255, 0,0,255,255])
        XCTAssertEqual(Array(pixels[12..<24]), [128,0,0,128, 0,0,0,0, 255,255,255,255])
        resources.removeAllResources()
        XCTAssertNotNil(renderer.textures[texture.identifier], "External texture owners keep their image valid")
    }
    func testFileAtlasDensityAliasesAndFailedLoadAreTransactional() throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeImage(directory.appendingPathComponent("tile.png"))
        try writeImage(directory.appendingPathComponent("other.png"))
        try writeAtlas(directory.appendingPathComponent("atlas.plist"),image: "tile.png")
        try writeAtlas(directory.appendingPathComponent("bad.plist"),image: "other.png",rect: "{{100, 0}, {2, 2}}")
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let resources = MRSceneResources(context: context,baseURL: directory)
        try resources.addAtlasNamed("atlas.plist",pixelsPerPoint: 2)
        let frame = try XCTUnwrap(resources.frameNamed("icon.png"))
        XCTAssertTrue(frame === resources.frameNamed("alias.png"))
        XCTAssertEqual(frame.pixelRect, CGRect(x: 1,y: 0,width: 2,height: 2))
        XCTAssertEqual(frame.originalSize, CGSize(width: 2,height: 2))
        XCTAssertEqual(frame.pixelsPerPoint, 2)
        XCTAssertTrue(frame.texture === (try resources.textureNamed("tile.png")))
        let count = renderer.textures.count
        try autoreleasepool {
            XCTAssertThrowsError(try resources.addAtlasNamed("bad.plist",pixelsPerPoint: 2))
        }
        XCTAssertEqual(renderer.textures.count, count, "Failed geometry must not retain a newly decoded texture")
        XCTAssertTrue(frame === resources.frameNamed("icon.png"))
    }
    func testMissingCanonicalImageDoesNotProbeDensitySuffixes() throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeImage(directory.appendingPathComponent("missing-hd.png"))
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let resources = MRSceneResources(context: context,baseURL: directory)
        XCTAssertThrowsError(try resources.textureNamed("missing.png"))
        XCTAssertTrue(renderer.textures.isEmpty)
    }
}
