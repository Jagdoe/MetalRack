import XCTest
import MetalKit
import MetalRackScene
@testable import MetalRack

final class NativeSubmissionTests: XCTestCase {
    private final class ClassifiedRenderer: SceneRenderer {
        var classification: (UInt32, UInt32) = (0, 0)
        override func nativeMaterial(texture: UInt32, vertices: UnsafeBufferPointer<MRRenderVertex>, blend: MRBlendFunction) -> (material: UInt32, attributes: UInt32) { classification }
    }
    func testAllNativeSamplerConfigurations() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try SceneRenderer(device: device)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:8,height:8,mipmapped:true)
        renderer.textures[7] = try XCTUnwrap(device.makeTexture(descriptor:descriptor))
        let vertices = [MRRenderVertex(x:0,y:0,u:0,v:0,r:1,g:1,b:1,a:1)]
        for _ in 0..<2 {
            for texture: UInt32 in [0,7] { for bits in 0..<16 {
                let sampling = MRTextureSampling(minFilter:bits&1==0 ? MRFilterNearest:MRFilterLinear,
                    magFilter:bits&2==0 ? MRFilterNearest:MRFilterLinear,
                    sAddress:bits&4==0 ? MRAddressClamp:MRAddressRepeat,
                    tAddress:bits&8==0 ? MRAddressClamp:MRAddressRepeat)
                vertices.withUnsafeBufferPointer { renderer.enqueueNative(vertices:$0,texture:texture,
                    blend:MRBlendFunction(src:MRBlendOne,dst:MRBlendZero),sampling:sampling,
                    clip:CGRect(x:0,y:0,width:8,height:8),logicalSize:CGSize(width:8,height:8)) }
                let expected = renderer.sampler(minFilter:bits&1==0 ? .nearest:.linear,
                    magFilter:bits&2==0 ? .nearest:.linear,sAddress:bits&4==0 ? .clampToEdge:.repeat,
                    tAddress:bits&8==0 ? .clampToEdge:.repeat,mipFilter:texture==7 && bits&1 != 0 ? .linear:.notMipmapped)
                XCTAssertTrue(renderer.batches.last!.sampler === expected)
            }}
        }
    }
    func testNativeBatchBoundariesAndGPUParity() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        func run(coalesce: Bool) throws -> ([UInt8], Int) {
            let renderer = try ClassifiedRenderer(device: device)
            renderer.coalescesAdjacentBatches = coalesce
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 16, height: 16, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            renderer.textures[99] = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            renderer.selectTarget(99, 16, 16); renderer.begin(0, 0, 1, 1)
            let positions: [(Float, Float)] = [(1,1),(13,1),(13,13),(1,1),(13,13),(1,13)]
            let vertices = positions.map { MRRenderVertex(x:$0.0,y:$0.1,u:0,v:0,r:0.25,g:0,b:0,a:0.25) }
            var blend = MRBlendFunction(src:MRBlendOne,dst:MRBlendOneMinusSourceAlpha)
            let linear = MRTextureSampling(minFilter:MRFilterLinear,magFilter:MRFilterLinear,sAddress:MRAddressClamp,tAddress:MRAddressClamp)
            let nearest = MRTextureSampling(minFilter:MRFilterNearest,magFilter:MRFilterNearest,sAddress:MRAddressRepeat,tAddress:MRAddressClamp)
            var textureID: UInt32 = 0
            func submit(_ sampling: MRTextureSampling = linear, _ clip: CGRect = CGRect(x:0,y:0,width:16,height:16), _ size: CGSize = CGSize(width:16,height:16), _ count: Int = 6) {
                vertices.withUnsafeBufferPointer { buffer in
                    renderer.enqueueNative(vertices: UnsafeBufferPointer(start:buffer.baseAddress,count:count),texture:textureID,blend:blend,sampling:sampling,clip:clip,logicalSize:size)
                }
            }
            submit()
            let savedBatch = renderer.batches[0]
            for _ in 1..<200 { submit() }
            XCTAssertEqual(savedBatch.vertices.count,6,"Retained Batch snapshots preserve value semantics")
            XCTAssertEqual(renderer.batches.count,coalesce ? 1 : 200)
            XCTAssertEqual(renderer.batches.last!.vertices.count,coalesce ? 1200 : 6)
            XCTAssertEqual(renderer.batches[0].vertices[0].position,SIMD2(1,15))
            XCTAssertEqual(renderer.batches[0].vertices[0].color,SIMD4(0.25,0,0,0.25))
            submit(nearest); submit(nearest)
            renderer.classification = (1,0); submit(nearest)
            renderer.classification = (1,2); submit(nearest)
            submit(nearest,CGRect(x:2,y:2,width:10,height:10))
            submit(nearest,CGRect(x:2,y:2,width:10,height:10),CGSize(width:32,height:32))
            submit(linear,CGRect(x:0,y:0,width:16,height:16),CGSize(width:16,height:16),4)
            submit()
            var whitePixel: UInt32 = .max
            withUnsafePointer(to: &whitePixel) { renderer.uploadTexture(7,width:1,height:1,pixels:$0) }
            textureID = 7; submit()
            blend.dst = MRBlendOne; submit()
            blend.src = MRBlendSourceAlpha; submit()
            XCTAssertEqual(renderer.batches.count,coalesce ? 11 : 211)
            let count = renderer.batches.count
            var pixels = [UInt8](repeating:0,count:16*16*4)
            pixels.withUnsafeMutableBytes { renderer.readTexture(99,x:0,y:0,width:16,height:16,pixels:$0.baseAddress!) }
            return (pixels,count)
        }
        let reference = try run(coalesce:false), optimized = try run(coalesce:true)
        XCTAssertEqual(optimized.0,reference.0,"Coalescing must preserve exact GPU pixels across all state boundaries")
    }
}
