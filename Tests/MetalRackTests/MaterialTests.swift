import XCTest
import MetalKit
import MetalRackScene
@testable import MetalRack

final class MaterialTests: XCTestCase {
    func testAdjacentCoalescingPreservesStateBoundariesAndVertexOrder() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let image = try XCTUnwrap(renderer.device.makeTexture(descriptor: .texture2DDescriptor(pixelFormat: .rgba8Unorm,width: 1,height: 1,mipmapped: false)))
        func batch(_ x: Float, _ material: UInt32 = 0, _ attributes: UInt32 = 0) -> SceneRenderer.Batch {
            .init(material: material, attributes: attributes,
                  vertices: Array(repeating: .init(position: SIMD2(x,0),texCoord: .zero,color: SIMD4(repeating: 1)), count: 3),
                  texture: image,source: .one,destination: .oneMinusSourceAlpha,
                  clip: CGRect(x: 0,y: 0,width: 1,height: 1),sampler: renderer.quads.samplerState)
        }
        renderer.enqueue(batch(1)); renderer.enqueue(batch(2))
        XCTAssertEqual(renderer.batches.count,2,"The optimization is explicitly opt-in")
        renderer.batches.removeAll(); renderer.coalescesAdjacentBatches = true
        renderer.enqueue(batch(1)); renderer.enqueue(batch(2)); renderer.enqueue(batch(3,1))
        renderer.enqueue(batch(4)); renderer.enqueue(batch(5,0,1))
        XCTAssertEqual(renderer.batches.count,4)
        XCTAssertEqual(renderer.batches[0].vertices.map(\.position.x),[1,1,1,2,2,2])
        XCTAssertEqual(renderer.batches[1].vertices.map(\.position.x),[3,3,3])
        XCTAssertEqual(renderer.batches[2].vertices.map(\.position.x),[4,4,4],"Never merge across an intervening draw")
        XCTAssertEqual(renderer.batches[3].attributes,1)
        let linear = renderer.sampler(minFilter: .linear,magFilter: .linear,sAddress: .clampToEdge,tAddress: .clampToEdge)
        XCTAssertTrue(linear === renderer.sampler(minFilter: .linear,magFilter: .linear,sAddress: .clampToEdge,tAddress: .clampToEdge))
        XCTAssertFalse(linear === renderer.sampler(minFilter: .nearest,magFilter: .linear,sAddress: .clampToEdge,tAddress: .clampToEdge))
    }
    func testCoalescedAlphaTrianglesMatchSeparateDrawPixels() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        var white: UInt32 = .max
        let image = MRTexture(context: context,width: 1,height: 1,rgba: &white)!
        var pixels = [UInt8](repeating: 0,count: 4*4*4)
        let target = pixels.withUnsafeBytes { MRTexture(context: context,width: 4,height: 4,rgba: $0.baseAddress!)! }
        let frame = MRSpriteFrame(texture: image,pixelRect: CGRect(x: 0,y: 0,width: 1,height: 1),originalSize: CGSize(width: 1,height: 1),trimOffset: .zero,pixelsPerPoint: 1,rotated: false)!
        let root = MRNode()
        for color in [MRColor3B(r: 255,g: 0,b: 0),MRColor3B(r: 0,g: 0,b: 255)] {
            let sprite = MRSprite(frame: frame)!; sprite.scale = 4; sprite.position = CGPoint(x: 2,y: 2)
            sprite.color = color; sprite.opacity = 128; root.addChild(sprite)
        }
        var outputs: [[UInt8]] = []
        for merged in [false,true] {
            renderer.coalescesAdjacentBatches = merged
            context.beginTarget(target.identifier,size: CGSize(width: 4,height: 4),clear: true,color: MRRenderColor(r: 0,g: 0,b: 0,a: 0))
            root.visit(context)
            XCTAssertEqual(renderer.batches.count,merged ? 1 : 2)
            context.endTarget()
            pixels.withUnsafeMutableBytes { context.readTexture(target.identifier,rect: CGRect(x: 0,y: 0,width: 4,height: 4),rgba: $0.baseAddress!) }
            outputs.append(pixels)
        }
        XCTAssertEqual(outputs[0],outputs[1])
        XCTAssertGreaterThan(outputs[1][(2*4+2)*4+2],UInt8(0))
        renderer.detachNativeContext()
    }
    func testEqualLengthShaderSourcesRemainDistinct() throws {
        let renderer = try QuadRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let red = "fragment float4 paint(VertexOut o [[stage_in]]) { return float4(1,0,0,1); }"
        let blue = "fragment float4 paint(VertexOut o [[stage_in]]) { return float4(0,0,1,1); }"
        XCTAssertEqual(red.utf8.count, blue.utf8.count)
        let a = try renderer.pipeline(source: .one, destination: .zero, pixelFormat: .rgba8Unorm,
                                      fragmentSource: red, fragmentFunction: "paint")
        let b = try renderer.pipeline(source: .one, destination: .zero, pixelFormat: .rgba8Unorm,
                                      fragmentSource: blue, fragmentFunction: "paint")
        XCTAssertFalse(a === b)
        XCTAssertTrue(a === (try renderer.pipeline(source: .one, destination: .zero, pixelFormat: .rgba8Unorm,
                                                  fragmentSource: red, fragmentFunction: "paint")))
    }
    func testCustomFragmentBlendAndOffscreenFormatUseSharedUploader() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let renderer = try QuadRenderer(device: device)
        let source = """
        fragment float4 greenMaterial(VertexOut input [[stage_in]],
            texture2d<float> image [[texture(0)]], sampler sampling [[sampler(0)]]) {
            float4 color = image.sample(sampling, input.texCoord) * input.color;
            return float4(0, color.r, 0, color.a);
        }
        """
        let pipeline = try renderer.pipeline(source: .one, destination: .zero,
            pixelFormat: .rgba8Unorm, fragmentSource: source, fragmentFunction: "greenMaterial")
        XCTAssertTrue(pipeline === (try renderer.pipeline(source: .one, destination: .zero,
            pixelFormat: .rgba8Unorm, fragmentSource: source, fragmentFunction: "greenMaterial")))
        let image = try XCTUnwrap(device.makeTexture(descriptor:
            .texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)))
        var white: UInt32 = .max
        image.replace(region: MTLRegionMake2D(0,0,1,1), mipmapLevel: 0, withBytes: &white, bytesPerRow: 4)
        let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 8, height: 8, mipmapped: false)
        targetDescriptor.usage = [.renderTarget]
        let target = try XCTUnwrap(device.makeTexture(descriptor: targetDescriptor))
        let command = try XCTUnwrap(queue.makeCommandBuffer())
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,1,1)
        let encoder = try XCTUnwrap(command.makeRenderCommandEncoder(descriptor: pass))
        let points: [SIMD2<Float>] = [SIMD2(0,0),SIMD2(8,0),SIMD2(8,8),SIMD2(0,0),SIMD2(8,8),SIMD2(0,8)]
        let vertices = points.map { QuadRenderer.Vertex(position: $0, texCoord: .zero, color: SIMD4<Float>(0.5,0,0,0.5)) }
        let hidden = vertices.map { QuadRenderer.Vertex(position: $0.position + SIMD2(repeating: 100), texCoord: .zero, color: $0.color) }
        renderer.beginFrame(commandBuffer: command)
        renderer.encode(texture: image, vertices: vertices + Array(repeating: hidden, count: 2000).flatMap { $0 },
            viewportSize: CGSize(width: 8,height: 8), encoder: encoder, pipeline: pipeline)
        encoder.endEncoding()
        let readback = try XCTUnwrap(device.makeBuffer(length: 256*8, options: .storageModeShared))
        let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from: target, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x:0,y:0,z:0),
            sourceSize: MTLSize(width:8,height:8,depth:1), to: readback, destinationOffset: 0,
            destinationBytesPerRow: 256, destinationBytesPerImage: 2048)
        blit.endEncoding(); command.commit(); command.waitUntilCompleted()
        XCTAssertNil(command.error)
        let pixel = readback.contents().assumingMemoryBound(to: UInt8.self).advanced(by: 4*256+4*4)
        XCTAssertEqual(pixel[0],0); XCTAssertEqual(Int(pixel[1]),128,accuracy:1)
        XCTAssertEqual(pixel[2],0); XCTAssertEqual(Int(pixel[3]),128,accuracy:1)
    }
}
