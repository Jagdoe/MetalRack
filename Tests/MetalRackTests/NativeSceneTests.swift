import XCTest
import MetalKit
import MetalRack
import MetalRackScene

private final class RecordingNode: MRNode {
    var name = ""
    var record: ((String) -> Void)?
    override func draw(_ context: MRRenderContext!) { record?(name) }
}

private final class DrawReentryState {
    let context: MRRenderContext
    var values: [Float] = []
    var nested = false
    init(context: MRRenderContext) { self.context = context }
    func draw(_ x: Float) {
        var vertex = MRRenderVertex(x: x,y: 0,u: 0,v: 0,r: 1,g: 1,b: 1,a: 1)
        context.drawVertices(&vertex,count: 1,texture: 1,
                             blend: MRBlendFunction(src: MRBlendOne,dst: MRBlendZero),
                             sampling: MRTextureSampling(minFilter: MRFilterLinear,magFilter: MRFilterLinear,sAddress: MRAddressClamp,tAddress: MRAddressClamp))
    }
    func run() {
        context.beginFrame(with: CGSize(width: 10,height: 10))
        context.pushClipRect(CGRect(x: 0,y: 0,width: 10,height: 10))
        draw(1); context.popClipRect()
    }
    func receive(_ vertices: UnsafePointer<MRRenderVertex>, _ count: Int) {
        values.append(vertices[0].x)
        if !nested { nested = true; draw(9); values.append(vertices[0].x) }
    }
}

final class NativeSceneTests: XCTestCase {
    func testCachedChildOrderInvalidatesAndSnapshotsSurviveDrawMutation() {
        let context = MRRenderContext(), root = RecordingNode(), a = RecordingNode(), b = RecordingNode()
        root.name = "root"; a.name = "a"; b.name = "b"
        var order: [String] = []
        for node in [root,a,b] { node.record = { order.append($0) } }
        root.addChild(a,z: 0); root.addChild(b,z: 0)
        let original: [MRNode] = root.children
        root.visit(context); root.visit(context)
        XCTAssertEqual(order, ["root","a","b","root","a","b"])
        order = []; b.zOrder = -1; root.visit(context)
        XCTAssertEqual(order, ["b","root","a"])
        order = []; root.record = { name in order.append(name); root.removeChild(a) }
        root.visit(context)
        XCTAssertEqual(order, ["b","root"])
        XCTAssertEqual(original.count,2, "Caller-owned snapshots remain immutable")
        XCTAssertEqual(root.children.count,1)
        let other = RecordingNode(); other.name = "other"
        a.record = { order.append($0) }; other.addChild(a)
        root.record = { order.append($0) }; root.addChild(other)
        order = []; root.visit(context)
        XCTAssertEqual(order, ["b","root","a"])
        root.removeAllChildren(withCleanup: true)
        XCTAssertTrue(root.children.isEmpty)
    }
    func testTransformCachesFollowGeometryAncestorsReparentingAndParentLifetime() {
        func local(_ node: MRNode) -> CGAffineTransform {
            let ax = node.anchorPoint.x * node.contentSize.width, ay = node.anchorPoint.y * node.contentSize.height
            let r = -node.rotation * .pi / 180
            var x = node.position.x, y = node.position.y
            if node.ignoresAnchorPointForPosition { x += ax; y += ay }
            var t = CGAffineTransform(a: cos(r)*node.scaleX,b: sin(r)*node.scaleX,
                                      c: -sin(r)*node.scaleY,d: cos(r)*node.scaleY,tx: x,ty: y)
            if node.skewX != 0 || node.skewY != 0 {
                t = CGAffineTransform(a: 1,b: tan(node.skewY * .pi/180),c: tan(node.skewX * .pi/180),d: 1,tx: 0,ty: 0).concatenating(t)
            }
            return t.translatedBy(x: -ax,y: -ay)
        }
        func check(_ node: MRNode) {
            var expected = local(node), parent = node.parent
            while let current = parent { expected = expected.concatenating(local(current)); parent = current.parent }
            for _ in 0..<2 {
                let actual = node.nodeToWorldTransform
                for (a,b) in zip([actual.a,actual.b,actual.c,actual.d,actual.tx,actual.ty],
                                 [expected.a,expected.b,expected.c,expected.d,expected.tx,expected.ty]) {
                    XCTAssertEqual(a,b,accuracy: 0.000000001)
                }
            }
        }
        let root = MRNode(), parent = MRNode(), leaf = MRNode()
        root.addChild(parent); parent.addChild(leaf); check(leaf)
        let changes: [() -> Void] = [
            { leaf.position = CGPoint(x: 4,y: 7) }, { root.position = CGPoint(x: 20,y: -12) },
            { parent.rotation = 24 }, { leaf.anchorPoint = CGPoint(x: 0.2,y: 0.7) },
            { leaf.contentSize = CGSize(width: 20,height: 13) }, { root.scaleX = 2 },
            { parent.scaleY = 0.7 }, { parent.skewX = 7 }, { root.skewY = -9 },
            { leaf.ignoresAnchorPointForPosition = true }, { root.scale = 3 }
        ]
        for change in changes { change(); check(leaf) }
        parent.removeFromParent(); check(leaf)
        let other = MRNode(); other.position = CGPoint(x: -30,y: 80); other.addChild(parent); check(leaf)
        var temporary: MRNode? = MRNode(); let retainedChild = MRNode()
        temporary!.position = CGPoint(x: 10,y: 20); temporary!.addChild(retainedChild); check(retainedChild)
        temporary = nil; XCTAssertNil(retainedChild.parent); check(retainedChild)
    }
    func testDeepTransformStackAndReentrantDrawBuffers() {
        let context = MRRenderContext()
        let original = context.transform
        for _ in 0..<80 { context.pushTransform(); context.multiplyTransform(CGAffineTransform(translationX: 1,y: 2)) }
        XCTAssertEqual(context.transform.tx,80); XCTAssertEqual(context.transform.ty,160)
        for _ in 0..<80 { context.popTransform() }
        XCTAssertEqual(context.transform,original)
        var backend = MRRenderBackend()
        backend.beginFrame = { _, _ in }; backend.present = { _ in }
        backend.draw = { pointer, vertices, count, _, _, _, _, _ in
            let state = Unmanaged<DrawReentryState>.fromOpaque(pointer!).takeUnretainedValue()
            state.receive(vertices!,count)
        }
        let state = DrawReentryState(context: context)
        backend.context = Unmanaged.passUnretained(state).toOpaque()
        context.setBackend(backend)
        state.run()
        XCTAssertEqual(state.values,[1,9,1], "Nested draws must not overwrite the caller's vertices")
        context.setBackend(MRRenderBackend())
    }
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
