import XCTest
import MetalKit
@testable import MetalRack

final class MaterialTests: XCTestCase {
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
