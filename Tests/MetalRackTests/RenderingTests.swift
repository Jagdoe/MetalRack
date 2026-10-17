import XCTest
import MetalKit
@testable import MetalRack

final class RenderingTests: XCTestCase {
    func testAspectFitRoundTripAndLetterbox() {
        let viewport = SceneViewport(logicalSize: CGSize(width: 100, height: 50), displaySize: CGSize(width: 200, height: 200))
        XCTAssertEqual(viewport.scale, 2)
        XCTAssertEqual(viewport.offset, CGPoint(x: 0, y: 50))
        let point = CGPoint(x: 30, y: 20)
        XCTAssertEqual(viewport.logicalPoint(from: viewport.displayPoint(from: point)), point)
    }

    func testEmptyViewportDoesNotProduceInvalidCoordinates() {
        let viewport = SceneViewport(logicalSize: .zero, displaySize: .zero)
        XCTAssertEqual(viewport.scale, 0)
        XCTAssertEqual(viewport.offset, .zero)
        XCTAssertNil(viewport.logicalPoint(from: .zero))
    }

    // Exercises inline and pooled uploads, growth of one slot then reuse of the smaller
    // slots, and premultiplied compositing with actual GPU readback.
    func testGPUBufferGrowthAndPremultipliedAlpha() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let renderer = try QuadRenderer(device: device)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        descriptor.usage = .shaderRead
        let white = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var pixel: UInt32 = 0xffffffff
        white.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
        let corners: [SIMD2<Float>] = [SIMD2(0,0), SIMD2(8,0), SIMD2(8,8), SIMD2(0,0), SIMD2(8,8), SIMD2(0,8)]
        let quad = corners.map { QuadRenderer.Vertex(position: $0, texCoord: .zero, color: SIMD4(0.5, 0, 0, 0.5)) }
        for count in [1, 2000, 40, 40, 2000, 40, 40] {
            let targetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 8, height: 8, mipmapped: false)
            targetDescriptor.usage = .renderTarget
            let target = try XCTUnwrap(device.makeTexture(descriptor: targetDescriptor))
            let readback = try XCTUnwrap(device.makeBuffer(length: 256 * 8, options: .storageModeShared))
            let command = try XCTUnwrap(queue.makeCommandBuffer())
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 1, 1)
            let encoder = try XCTUnwrap(command.makeRenderCommandEncoder(descriptor: pass))
            renderer.beginFrame(commandBuffer: command)
            // Extra geometry is offscreen, so the center must have exactly one blend.
            let hidden = quad.map { QuadRenderer.Vertex(position: $0.position + SIMD2(repeating: 100), texCoord: $0.texCoord, color: $0.color) }
            let vertices = quad + Array(repeating: hidden, count: count - 1).flatMap { $0 }
            renderer.encode(texture: white, vertices: vertices, viewportSize: CGSize(width: 8, height: 8), encoder: encoder)
            encoder.endEncoding()
            let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
            blit.copy(from: target, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0,y: 0,z: 0), sourceSize: MTLSize(width: 8,height: 8,depth: 1), to: readback, destinationOffset: 0, destinationBytesPerRow: 256, destinationBytesPerImage: 2048)
            blit.endEncoding()
            command.commit(); command.waitUntilCompleted()
            XCTAssertNil(command.error)
            let bytes = readback.contents().assumingMemoryBound(to: UInt8.self)
            let center = 4 * 256 + 4 * 4
            XCTAssertEqual(Int(bytes[center]), 128, accuracy: 1)
            XCTAssertEqual(Int(bytes[center+1]), 0)
            XCTAssertEqual(Int(bytes[center+2]), 128, accuracy: 1)
            XCTAssertEqual(bytes[center+3], 255)
        }
    }
}
