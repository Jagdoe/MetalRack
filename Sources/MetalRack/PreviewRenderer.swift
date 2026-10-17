import Metal
import MetalKit
import simd

// MARK: - PreviewRenderer

/// Renders a minimal Metal scene that can be used to verify device and pipeline setup.
public final class PreviewRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice?

    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLRenderPipelineState?

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    vertex VertexOut metalRackVertex(uint vertexID [[vertex_id]]) {
        const float4 positions[3] = {
            float4(-0.8, -0.8, 0.0, 1.0),
            float4(0.0, 0.8, 0.0, 1.0),
            float4(0.8, -0.8, 0.0, 1.0)
        };

        const float4 colors[3] = {
            float4(0.9, 0.2, 0.2, 1.0),
            float4(0.95, 0.75, 0.2, 1.0),
            float4(0.2, 0.8, 0.4, 1.0)
        };

        VertexOut output;
        output.position = positions[vertexID];
        output.color = colors[vertexID];
        return output;
    }

    fragment float4 metalRackFragment(VertexOut input [[stage_in]]) {
        return input.color;
    }
    """

    public override init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()

        if
            let device,
            let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
            let vertexFunction = library.makeFunction(name: "metalRackVertex"),
            let fragmentFunction = library.makeFunction(name: "metalRackFragment")
        {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            self.pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
        } else {
            self.pipelineState = nil
        }

        super.init()
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    public func draw(in view: MTKView) {
        guard
            let passDescriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else {
            return
        }

        if let pipelineState {
            encoder.setRenderPipelineState(pipelineState)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
