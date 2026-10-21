import XCTest
import MetalKit
import MetalRack
import MetalRackScene

private final class RecordingNode: MRNode {
    var name = ""
    var record: ((String) -> Void)?
    override func draw(_ context: MRRenderContext!) { record?(name) }
}

final class NativeSceneTests: XCTestCase {
    func testHierarchyTransformsAndStableDrawOrder() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext()
        renderer.attachNativeContext(context)
        context.beginFrame(with: CGSize(width: 100, height: 100))
        let root = RecordingNode()
        root.position = CGPoint(x: 10, y: 20)
        root.scaleX = 2; root.scaleY = 3
        root.name = "root"
        var order: [String] = []
        root.record = { order.append($0) }
        for (name, z) in [("a", 0), ("back", -1), ("b", 0)] {
            let child = RecordingNode()
            child.name = name; child.record = { order.append($0) }
            root.addChild(child, z: z)
        }
        let child = try XCTUnwrap(root.children.first)
        child.position = CGPoint(x: 4, y: 5)
        child.contentSize = CGSize(width: 8, height: 6)
        child.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        XCTAssertEqual(child.convert(toWorldSpace: CGPoint(x: 4, y: 3)), CGPoint(x: 18, y: 35))
        let p = CGPoint(x: -3, y: 7)
        let roundTrip = child.convert(toNodeSpace: child.convert(toWorldSpace: p))
        XCTAssertEqual(roundTrip.x, p.x, accuracy: 0.00001)
        XCTAssertEqual(roundTrip.y, p.y, accuracy: 0.00001)
        root.visit(context)
        XCTAssertEqual(order, ["back", "root", "a", "b"])
        XCTAssertEqual(context.transform, .identity)
        child.removeFromParent()
        XCTAssertNil(child.parent)
        XCTAssertEqual(root.children.count, 2)
    }

    func testNativeSpritePixelsDensityFlipAndClip() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext()
        renderer.attachNativeContext(context)
        context.beginFrame(with: CGSize(width: 8, height: 8))
        // Top row red/green, bottom row blue/white. Geometry is y-up.
        let pixels: [UInt8] = [255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,255,255]
        let atlas = pixels.withUnsafeBytes { MRTexture(context: context, width: 2, height: 2, rgba: $0.baseAddress!)! }
        let frame = MRSpriteFrame(texture: atlas, pixelRect: CGRect(x: 0,y: 0,width: 2,height: 2),
            originalSize: CGSize(width: 2,height: 2), trimOffset: .zero, pixelsPerPoint: 1, rotated: false)!
        let sprite = MRSprite(frame: frame)!
        sprite.position = CGPoint(x: 4,y: 4); sprite.scaleX = 2; sprite.scaleY = 2
        sprite.sampling = MRTextureSampling(minFilter: MRFilterNearest, magFilter: MRFilterNearest, sAddress: MRAddressClamp,tAddress: MRAddressClamp)
        var empty = [UInt8](repeating: 0, count: 8*8*4)
        let target = empty.withUnsafeBytes { MRTexture(context: context,width: 8,height: 8,rgba: $0.baseAddress!)! }
        context.beginTarget(target.identifier, size: CGSize(width: 8,height: 8),clear: true,color: MRRenderColor(r: 0,g: 0,b: 0,a: 0))
        sprite.visit(context)
        context.endTarget()
        empty.withUnsafeMutableBytes { context.readTexture(target.identifier,rect: CGRect(x: 0,y: 0,width: 8,height: 8),rgba: $0.baseAddress!) }
        func rgba(_ x: Int, _ y: Int) -> [UInt8] { Array(empty[(y*8+x)*4..<(y*8+x)*4+4]) }
        XCTAssertEqual(rgba(2,2), [255,0,0,255])
        XCTAssertEqual(rgba(5,2), [0,255,0,255])
        XCTAssertEqual(rgba(2,5), [0,0,255,255])
        XCTAssertEqual(rgba(5,5), [255,255,255,255])
        XCTAssertEqual(rgba(1,1), [0,0,0,0])
        sprite.flipX = true
        context.beginTarget(target.identifier,size: CGSize(width: 8,height: 8),clear: true,color: MRRenderColor(r: 0,g: 0,b: 0,a: 0))
        context.pushClipRect(CGRect(x: 2,y: 4,width: 2,height: 2))
        sprite.visit(context)
        context.popClipRect()
        context.endTarget()
        empty.withUnsafeMutableBytes { context.readTexture(target.identifier,rect: CGRect(x: 0,y: 0,width: 8,height: 8),rgba: $0.baseAddress!) }
        XCTAssertEqual(rgba(2,2), [0,255,0,255])
        XCTAssertEqual(rgba(5,2), [0,0,0,0])
        XCTAssertEqual(rgba(2,5), [0,0,0,0])
        XCTAssertEqual(context.logicalSize, CGSize(width: 8,height: 8))
        XCTAssertEqual(context.clipRect, CGRect(x: 0,y: 0,width: 8,height: 8))
    }
    func testNativeSnapshotOutlineIncludesAttachmentsAndRestoresContext() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext()
        renderer.attachNativeContext(context)
        context.beginFrame(with: CGSize(width: 40,height: 30))
        let pixel: [UInt8] = [255,255,255,255]
        let texture = pixel.withUnsafeBytes { MRTexture(context: context,width: 1,height: 1,rgba: $0.baseAddress!)! }
        let frame = MRSpriteFrame(texture: texture,pixelRect: CGRect(x: 0,y: 0,width: 1,height: 1),
            originalSize: CGSize(width: 1,height: 1),trimOffset: .zero,pixelsPerPoint: 1,rotated: false)!
        let root = MRSprite(frame: frame)!
        root.anchorPoint = .zero; root.position = CGPoint(x: 3,y: 4)
        let attachment = MRSprite(frame: frame)!
        attachment.anchorPoint = .zero; attachment.position = CGPoint(x: 3,y: 0)
        root.addChild(attachment)
        context.pushTransform()
        context.multiplyTransform(CGAffineTransform(translationX: 7,y: 8))
        context.pushClipRect(CGRect(x: 0,y: 0,width: 10,height: 10))
        let savedTransform = context.transform, savedClip = context.clipRect
        let outline = MRCreateNodeOutline(root,context,CGPoint(x: 5,y: 4.5),2,0.5)!
        XCTAssertEqual(root.position, CGPoint(x: 3,y: 4))
        XCTAssertEqual(attachment.parent, root)
        XCTAssertEqual(context.transform, savedTransform)
        XCTAssertEqual(context.clipRect, savedClip)
        XCTAssertEqual(context.logicalSize, CGSize(width: 40,height: 30))
        let image = try XCTUnwrap(outline.frame?.texture)
        let width = Int(image.pixelSize.width), height = Int(image.pixelSize.height)
        var pixels = [UInt8](repeating: 0,count: width*height*4)
        pixels.withUnsafeMutableBytes { context.readTexture(image.identifier,rect: CGRect(x: 0,y: 0,width: width,height: height),rgba: $0.baseAddress!) }
        let alpha = stride(from: 3,to: pixels.count,by: 4).map { pixels[$0] }
        XCTAssertTrue(alpha.contains(255))
        XCTAssertTrue(alpha.allSatisfy { $0 == 0 || $0 == 255 })
        XCTAssertTrue((0..<width).allSatisfy { alpha[$0] == 0 && alpha[(height-1)*width+$0] == 0 })
        XCTAssertTrue((0..<height).allSatisfy { alpha[$0*width] == 0 && alpha[$0*width+width-1] == 0 })
        // Two separate 2x2 silhouettes each have an eight-pixel radius-one ring.
        XCTAssertEqual(alpha.filter { $0 == 255 }.count, 16)
        context.popClipRect(); context.popTransform()
    }

    func testDenseRotatedTrimmedFrameGeometryAndPremultiplication() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext()
        renderer.attachNativeContext(context)
        context.beginFrame(with: CGSize(width: 8,height: 8))
        let pixels = [UInt8](repeating: 255,count: 4*6*4)
        let texture = pixels.withUnsafeBytes { MRTexture(context: context,width: 4,height: 6,rgba: $0.baseAddress!)! }
        let frame = MRSpriteFrame(texture: texture,pixelRect: CGRect(x: 0,y: 0,width: 4,height: 6),
            originalSize: CGSize(width: 5,height: 4),trimOffset: CGPoint(x: 0.5,y: -0.5),pixelsPerPoint: 2,rotated: true)!
        let sprite = MRSprite(frame: frame)!
        sprite.anchorPoint = .zero
        sprite.color = MRColor3B(r: 128,g: 255,b: 0); sprite.opacity = 128
        sprite.visit(context)
        let vertices = try XCTUnwrap(renderer.batches.last).vertices
        // Stored 4x6 rotated pixels describe a 3x2-point trimmed image, inside
        // a 5x4-point source canvas, offset half a point right and down.
        XCTAssertEqual(vertices[0].position, SIMD2(1.5,7.5))
        XCTAssertEqual(vertices[1].position, SIMD2(4.5,7.5))
        XCTAssertEqual(vertices[2].position, SIMD2(1.5,5.5))
        XCTAssertEqual(vertices[0].texCoord, SIMD2(0,0))
        XCTAssertEqual(vertices[1].texCoord, SIMD2(0,1))
        XCTAssertEqual(vertices[2].texCoord, SIMD2(1,0))
        XCTAssertEqual(vertices[0].color.x, (128.0/255)*(128.0/255),accuracy: 0.00001)
        XCTAssertEqual(vertices[0].color.w, 128.0/255,accuracy: 0.00001)
        sprite.flipX = true; sprite.flipY = true
        sprite.visit(context)
        let flipped = try XCTUnwrap(renderer.batches.last).vertices
        XCTAssertEqual(flipped[0].position, SIMD2(0.5,6.5))
        XCTAssertEqual(flipped[0].texCoord, SIMD2(1,1))
    }

    func testNestedTargetsAndQueuedTextureVersions() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext()
        renderer.attachNativeContext(context)
        context.beginFrame(with: CGSize(width: 2,height: 2))
        let empty = [UInt8](repeating: 0,count: 16)
        let first = empty.withUnsafeBytes { MRTexture(context: context,width: 2,height: 2,rgba: $0.baseAddress!)! }
        let second = empty.withUnsafeBytes { MRTexture(context: context,width: 2,height: 2,rgba: $0.baseAddress!)! }
        context.beginTarget(first.identifier,size: CGSize(width: 2,height: 2),clear: true,color: MRRenderColor(r: 255,g: 0,b: 0,a: 255))
        context.beginTarget(second.identifier,size: CGSize(width: 1,height: 1),clear: true,color: MRRenderColor(r: 0,g: 255,b: 0,a: 255))
        context.endTarget()
        XCTAssertEqual(context.logicalSize, CGSize(width: 2,height: 2))
        context.endTarget()
        let frame = MRSpriteFrame(texture: first,pixelRect: CGRect(x: 0,y: 0,width: 2,height: 2),originalSize: CGSize(width: 2,height: 2),trimOffset: .zero,pixelsPerPoint: 1,rotated: false)!
        MRSprite(frame: frame)!.visit(context)
        let queued = try XCTUnwrap(renderer.batches.first).texture
        context.beginTarget(first.identifier,size: CGSize(width: 2,height: 2),clear: true,color: MRRenderColor(r: 0,g: 0,b: 255,a: 255))
        context.endTarget()
        XCTAssertTrue(renderer.batches.first?.texture === queued)
        XCTAssertFalse(renderer.textures[first.identifier] === queued)
        var oldPixels = [UInt8](repeating: 0,count: 16)
        oldPixels.withUnsafeMutableBytes { queued.getBytes($0.baseAddress!,bytesPerRow: 8,from: MTLRegionMake2D(0,0,2,2),mipmapLevel: 0) }
        XCTAssertEqual(Array(oldPixels[0..<4]), [255,0,0,255])
        var newPixels = [UInt8](repeating: 0,count: 16)
        newPixels.withUnsafeMutableBytes { context.readTexture(first.identifier,rect: CGRect(x: 0,y: 0,width: 2,height: 2),rgba: $0.baseAddress!) }
        XCTAssertEqual(Array(newPixels[0..<4]), [0,0,255,255])
        newPixels.withUnsafeMutableBytes { context.readTexture(second.identifier,rect: CGRect(x: 0,y: 0,width: 2,height: 2),rgba: $0.baseAddress!) }
        XCTAssertEqual(Array(newPixels[0..<4]), [0,255,0,255])
    }

}
