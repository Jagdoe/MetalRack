import MetalKit
import simd

/// Shared premultiplied-alpha triangle pipeline. One instance is used serially by one scene.
/// Call beginFrame once per command buffer, then encode any number of ordered batches.
public final class QuadRenderer {
    public struct Vertex {
        public var position: SIMD2<Float>
        public var texCoord: SIMD2<Float>
        public var color: SIMD4<Float>
        public init(position: SIMD2<Float>, texCoord: SIMD2<Float>, color: SIMD4<Float>) {
            self.position = position; self.texCoord = texCoord; self.color = color
        }
    }
    public let device: MTLDevice
    public let pipelineState: MTLRenderPipelineState
    public let samplerState: MTLSamplerState
    private static let inlineVertexByteLimit = 4096
    private static let vertexBufferAlignment = 256
    private static let vertexBufferCount = 3
    private static let initialVertexBufferCapacity = 256 * 1024
    private let availableFrames = DispatchSemaphore(value: 3)
    private var frameVertexBuffers: [MTLBuffer?] = Array(repeating: nil, count: vertexBufferCount)
    private var frameVertexBufferIndex = 0
    private var frameVertexBufferOffset = 0
    private var frameVertexBufferCapacity = initialVertexBufferCapacity

    public init(device: MTLDevice) throws {
        self.device = device
        // Copy the shader file directly: a top-level directory named Resources
        // makes an iOS resource bundle ambiguous to the code-signing tool.
        guard let url = Bundle.module.url(forResource: "QuadShaders", withExtension: "txt")
            ?? Bundle.module.url(forResource: "QuadShaders", withExtension: "txt", subdirectory: "Resources") else {
            throw MetalRackError.resource("QuadShaders.txt")
        }
        let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "quadVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "quadFragment")
        let color = descriptor.colorAttachments[0]!
        color.pixelFormat = .bgra8Unorm
        color.isBlendingEnabled = true
        color.sourceRGBBlendFactor = .one
        color.sourceAlphaBlendFactor = .one
        color.destinationRGBBlendFactor = .oneMinusSourceAlpha
        color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        let sampling = MTLSamplerDescriptor()
        sampling.minFilter = .linear; sampling.magFilter = .linear
        sampling.sAddressMode = .clampToEdge; sampling.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: sampling) else {
            throw MetalRackError.setup("Cannot create sampler")
        }
        samplerState = sampler
    }

    public func encode(texture: MTLTexture, vertices: [Vertex], viewportSize: CGSize,
                       encoder: MTLRenderCommandEncoder) {
        guard !vertices.isEmpty, setVertexBuffer(vertices: vertices,
            length: MemoryLayout<Vertex>.stride * vertices.count, encoder: encoder, device: device) else { return }
        encoder.setRenderPipelineState(pipelineState)
        var viewport = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
        encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }
    public func beginFrame(commandBuffer: MTLCommandBuffer) {
        availableFrames.wait()
        let semaphore = availableFrames
        commandBuffer.addCompletedHandler { _ in semaphore.signal() }
        frameVertexBufferIndex = (frameVertexBufferIndex + 1) % Self.vertexBufferCount
        frameVertexBufferOffset = 0
        if frameVertexBuffers[frameVertexBufferIndex] == nil {
            frameVertexBuffers[frameVertexBufferIndex] = device.makeBuffer(
                length: frameVertexBufferCapacity,
                options: [.storageModeShared]
            )
        }
    }

    private func setVertexBuffer(
        vertices: [Vertex],
        length: Int,
        encoder: MTLRenderCommandEncoder,
        device: MTLDevice
    ) -> Bool {
        if length <= Self.inlineVertexByteLimit {
            encoder.setVertexBytes(vertices, length: length, index: 0)
            return true
        }

        let alignedOffset = alignedFrameVertexBufferOffset()
        ensureFrameVertexBufferCapacity(alignedOffset + length, device: device)
        guard let buffer = frameVertexBuffers[frameVertexBufferIndex] else { return false }

        buffer.contents()
            .advanced(by: alignedOffset)
            .copyMemory(from: vertices, byteCount: length)
        encoder.setVertexBuffer(buffer, offset: alignedOffset, index: 0)
        frameVertexBufferOffset = alignedOffset + length
        return true
    }

    private func alignedFrameVertexBufferOffset() -> Int {
        let alignment = Self.vertexBufferAlignment
        return ((frameVertexBufferOffset + alignment - 1) / alignment) * alignment
    }

    private func ensureFrameVertexBufferCapacity(_ requiredCapacity: Int, device: MTLDevice) {
        guard requiredCapacity > (frameVertexBuffers[frameVertexBufferIndex]?.length ?? 0) else { return }
        var capacity = frameVertexBufferCapacity
        while capacity < requiredCapacity {
            capacity *= 2
        }
        frameVertexBufferCapacity = capacity
        frameVertexBuffers[frameVertexBufferIndex] = device.makeBuffer(
            length: capacity,
            options: [.storageModeShared]
        )
    }


}
