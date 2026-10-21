import XCTest
import MetalKit
import MetalRack
import MetalRackScene

private final class LifecycleNode: MRNode {
    var entries = 0, exits = 0
    var elapsed: [Float] = []
    var pulses = 0
    @objc func pulse() { pulses += 1 }
    override func didEnterScene() { entries += 1; super.didEnterScene() }
    override func willExitScene() { exits += 1; super.willExitScene() }
    @objc func timer(_ delta: Float) { elapsed.append(delta) }
}
private final class RegionSprite: MRSprite {
    override func draw(_ context: MRRenderContext!) {
        var region = MRNormalizedRegion(minX: 0,minY: 0,maxX: 1,maxY: 0.5)
        drawRegions(&region,count: 1,context: context)
    }
}
final class NativeIntegrationTests: XCTestCase {
    func testRootAdoptionKeepsLifecycleAndTimerAccumulationContinuous() {
        let scheduler = MRScheduler(), driver = MRSceneDriver(context: MRRenderContext(),scheduler: scheduler)
        let node = LifecycleNode(); node.schedule(#selector(LifecycleNode.timer(_:)),interval: 0.5)
        driver.scene = node; scheduler.tick(0); scheduler.tick(0.2)
        let wrapper = MRNode(); wrapper.addChild(node); driver.scene = wrapper
        XCTAssertEqual(node.entries,1); XCTAssertEqual(node.exits,0)
        scheduler.tick(0.3)
        XCTAssertEqual(node.elapsed.count,1); XCTAssertEqual(node.elapsed[0],0.5,accuracy: 0.00001)
        driver.scene = node
        XCTAssertNil(node.parent); XCTAssertEqual(node.entries,1); XCTAssertEqual(node.exits,0)
        driver.scene = nil; scheduler.tick(2)
        XCTAssertEqual(node.exits,1); XCTAssertEqual(node.elapsed.count,1)
        driver.scene = node; scheduler.tick(0.5)
        XCTAssertEqual(node.entries,2); XCTAssertEqual(node.elapsed.count,2)
        node.cleanup(); scheduler.tick(1)
        XCTAssertEqual(node.elapsed.count,2)
    }
    func testNodeTimersDoNotRetainDetachedNodes() {
        let scheduler = MRScheduler(), driver = MRSceneDriver(context: MRRenderContext(),scheduler: scheduler)
        weak var reference: LifecycleNode?
        autoreleasepool {
            let root = MRNode(), child = LifecycleNode(); reference = child
            child.schedule(#selector(LifecycleNode.timer(_:)),interval: 1)
            root.addChild(child); driver.scene = root; scheduler.tick(0)
            child.removeFromParent()
        }
        XCTAssertNil(reference)
        scheduler.tick(2); driver.scene = nil
    }
    func testOverlayUsesNativeLifecycleAndNoArgumentTimers() {
        let scheduler = MRScheduler(), driver = MRSceneDriver(context: MRRenderContext(),scheduler: scheduler)
        let node = LifecycleNode()
        node.schedule(#selector(LifecycleNode.pulse),interval: 0)
        driver.overlay = node
        XCTAssertEqual(node.entries,1)
        scheduler.tick(0); scheduler.tick(0.1)
        XCTAssertEqual(node.pulses,1)
        driver.scene = MRNode()
        XCTAssertEqual(node.exits,0)
        driver.overlay = nil
        XCTAssertEqual(node.exits,1)
        scheduler.tick(1)
        XCTAssertEqual(node.pulses,1)
    }
    private func texture(_ context: MRRenderContext) throws -> MRTexture {
        let pixels: [UInt8] = [255,0,0,255, 0,255,0,255, 0,0,255,255,
                              255,255,255,255, 255,255,0,255, 0,255,255,255]
        return try XCTUnwrap(pixels.withUnsafeBytes { MRTexture(context: context,width: 3,height: 2,rgba: $0.baseAddress!) })
    }
    private func render(_ sprite: MRSprite, context: MRRenderContext, width: Int, height: Int) throws -> [UInt8] {
        sprite.anchorPoint = .zero
        sprite.sampling = MRTextureSampling(minFilter: MRFilterNearest,magFilter: MRFilterNearest,sAddress: MRAddressClamp,tAddress: MRAddressClamp)
        let size = CGSize(width: width,height: height)
        var pixels = [UInt8](repeating: 0,count: width*height*4)
        let target = try XCTUnwrap(pixels.withUnsafeBytes { MRTexture(context: context,width: Int32(width),height: Int32(height),rgba: $0.baseAddress!) })
        context.beginFrame(with: size)
        context.beginTarget(target.identifier,size: size,clear: true,color: MRRenderColor(r: 0,g: 0,b: 0,a: 0))
        sprite.visit(context); context.endTarget()
        pixels.withUnsafeMutableBytes { context.readTexture(target.identifier,rect: CGRect(origin: .zero,size: size),rgba: $0.baseAddress!) }
        return pixels
    }
    func testNativeFrameCropPreservesPixelsAndTrimmedLogicalGeometry() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        defer { withExtendedLifetime(renderer) {} }
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let texture = try texture(context)
        let frame = try XCTUnwrap(MRSpriteFrame(texture: texture,pixelRect: CGRect(x: 0,y: 0,width: 3,height: 2),originalSize: CGSize(width: 3,height: 2),trimOffset: .zero,pixelsPerPoint: 1,rotated: false))
        let cropped = try XCTUnwrap(frame.cropped(to: CGRect(x: 0,y: 1,width: 2,height: 1)))
        XCTAssertTrue(cropped.texture === texture)
        XCTAssertEqual(cropped.pixelRect,CGRect(x: 0,y: 0,width: 2,height: 1))
        XCTAssertEqual(try render(MRSprite(frame: cropped),context: context,width: 2,height: 1),[255,0,0,255,0,255,0,255])
        let trimmed = try XCTUnwrap(MRSpriteFrame(texture: texture,pixelRect: frame.pixelRect,originalSize: CGSize(width: 5,height: 4),trimOffset: CGPoint(x: 1,y: -0.5),pixelsPerPoint: 1,rotated: false))
        let cut = try XCTUnwrap(trimmed.cropped(to: CGRect(x: 1,y: 0,width: 3,height: 3)))
        XCTAssertEqual(cut.originalSize,CGSize(width: 3,height: 3)); XCTAssertEqual(cut.trimOffset,CGPoint(x: 0.5,y: 0))
        XCTAssertNil(frame.cropped(to: CGRect(x: 10,y: 10,width: 1,height: 1)))
    }
    func testRotatedFrameCropUsesTheVisibleLogicalAxes() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        defer { withExtendedLifetime(renderer) {} }
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let texture = try texture(context)
        let frame = try XCTUnwrap(MRSpriteFrame(texture: texture,pixelRect: CGRect(x: 0,y: 0,width: 3,height: 2),originalSize: CGSize(width: 2,height: 3),trimOffset: .zero,pixelsPerPoint: 1,rotated: true))
        let all = try render(MRSprite(frame: frame),context: context,width: 2,height: 3)
        let crop = try XCTUnwrap(frame.cropped(to: CGRect(x: 0,y: 1,width: 1,height: 2)))
        let part = try render(MRSprite(frame: crop),context: context,width: 1,height: 2)
        XCTAssertEqual(part,Array(all[0..<4])+Array(all[8..<12]))
    }
    func testNormalizedMaterialRegionsDrawEachSourceRowOnce() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        defer { withExtendedLifetime(renderer) {} }
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let texture = try texture(context)
        let frame = try XCTUnwrap(MRSpriteFrame(texture: texture,pixelRect: CGRect(x: 0,y: 0,width: 3,height: 2),originalSize: CGSize(width: 3,height: 2),trimOffset: .zero,pixelsPerPoint: 1,rotated: false))
        let pixels = try render(RegionSprite(frame: frame),context: context,width: 3,height: 2)
        XCTAssertEqual(Array(pixels.prefix(12)),[255,0,0,255,0,255,0,255,0,0,255,255])
        XCTAssertEqual(Array(pixels.suffix(12)),[UInt8](repeating: 0,count: 12))
    }
    func testMipmapsKeepBaseGeometryAndRebuildAfterPixelReplacement() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        defer { withExtendedLifetime(renderer) {} }
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        var pixels: [UInt8] = []
        for y in 0..<8 { for x in 0..<8 { pixels += (x+y)%2 == 0 ? [255,0,0,255] : [0,255,0,255] } }
        let texture = try XCTUnwrap(pixels.withUnsafeBytes { MRTexture(context: context,width: 8,height: 8,rgba: $0.baseAddress!) })
        texture.generateMipmaps()
        XCTAssertEqual(texture.pixelSize,CGSize(width: 8,height: 8)); XCTAssertTrue(texture.hasMipmaps)
        let image = try XCTUnwrap(renderer.textures[texture.identifier]); XCTAssertEqual(image.mipmapLevelCount,4)
        var mip = [UInt8](repeating: 0,count: 4*4*4)
        image.getBytes(&mip,bytesPerRow: 16,from: MTLRegionMake2D(0,0,4,4),mipmapLevel: 1)
        for i in stride(from: 0,to: mip.count,by: 4) { XCTAssertEqual(Int(mip[i]),128,accuracy: 1);XCTAssertEqual(Int(mip[i+1]),128,accuracy: 1);XCTAssertEqual(mip[i+2],0);XCTAssertEqual(mip[i+3],255) }
        let blue: [UInt8] = Array(repeating: [0,0,255,255],count: 64).flatMap { $0 }
        blue.withUnsafeBytes { XCTAssertEqual($0.count,256);texture.replaceRGBA($0.baseAddress!) }
        let replaced = try XCTUnwrap(renderer.textures[texture.identifier]);XCTAssertEqual(replaced.mipmapLevelCount,4)
        var pixel = [UInt8](repeating: 0,count: 4)
        replaced.getBytes(&pixel,bytesPerRow: 4,from: MTLRegionMake2D(0,0,1,1),mipmapLevel: 3)
        XCTAssertEqual(pixel,[0,0,255,255])
    }
}
