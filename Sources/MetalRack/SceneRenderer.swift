#if canImport(MetalKit)
import MetalKit
import MetalRackScene
#if canImport(UIKit)
import UIKit
#endif

/// Ordered native Metal draw submission and render-target ownership.
/// Applications provide materials and scene policy through the hooks below.
open class SceneRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let quads: QuadRenderer
    public weak var view: MTKView?
    public var textures: [UInt32: MTLTexture] = [:]
    public let white: MTLTexture
    public var logicalSize = CGSize.zero
    public struct Batch {
        public var material: UInt32 = 0
        public var attributes: UInt32 = 0
        public let vertices: [QuadRenderer.Vertex]
        public let texture: MTLTexture
        public let source: MTLBlendFactor
        public let destination: MTLBlendFactor
        public let coordinateSize: CGSize
        public let clip: CGRect
        public let sampler: MTLSamplerState
        public init(material: UInt32 = 0, attributes: UInt32 = 0,
                    vertices: [QuadRenderer.Vertex], texture: MTLTexture,
                    source: MTLBlendFactor, destination: MTLBlendFactor, clip: CGRect, sampler: MTLSamplerState, coordinateSize: CGSize = .zero) {
            self.material = material; self.attributes = attributes
            self.vertices = vertices; self.texture = texture
            self.source = source; self.destination = destination
            self.clip = clip; self.sampler = sampler; self.coordinateSize = coordinateSize
        }
    }
    public var batches: [Batch] = []
    public var screenBatches: [Batch] = []
    public var target: UInt32 = 0
    public var targetViewport = CGSize.zero
    public var targetClear: MTLClearColor?
    public var clear = MTLClearColorMake(0,0,0,1)
    private var samplers: [String: MTLSamplerState] = [:]
    private var reportedDrawable = false
    private var nativeContext: MRRenderContext?
    private var nativeTargets: [(UInt32, CGSize)] = []

    /// Attach an explicit native scene context. Keep this renderer alive for as
    /// long as its context or textures are in use. Detachment clears callbacks.
    public func attachNativeContext(_ context: MRRenderContext) {
        precondition(nativeContext == nil, "Detach the previous native context first")
        nativeContext = context
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        context.setBackend(MRRenderBackend(context: pointer, beginFrame: { pointer, size in
            let renderer = Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue()
            precondition(renderer.target == 0 && renderer.nativeTargets.isEmpty, "Unclosed native snapshot")
            renderer.logicalSize = size
            renderer.begin(Float(renderer.clear.red), Float(renderer.clear.green), Float(renderer.clear.blue), Float(renderer.clear.alpha))
        }, present: { pointer in
            Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue().present()
        }, upload: { pointer, name, width, height, pixels in
            Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue().uploadTexture(name, width: width, height: height, pixels: pixels!)
        }, removeTexture: { pointer, name in
            Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue().textures.removeValue(forKey: name)
        }, generateMipmaps: { pointer, name in
            Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue().generateMipmaps(name)
        }, draw: { pointer, vertices, count, texture, blend, sampling, clip, size in
            Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue().enqueueNative(
                vertices: UnsafeBufferPointer(start: vertices, count: count), texture: texture,
                blend: blend, sampling: sampling, clip: clip, logicalSize: size)
        }, beginTarget: { pointer, name, size, clear, color in
            let renderer = Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue()
            guard let texture = renderer.textures[name] else { preconditionFailure("Missing native snapshot texture") }
            renderer.flushTarget()
            renderer.nativeTargets.append((renderer.target, renderer.targetViewport))
            renderer.selectTarget(name, Int32(texture.width), Int32(texture.height))
            if clear { renderer.begin(Float(color.r)/255, Float(color.g)/255, Float(color.b)/255, Float(color.a)/255) }
        }, endTarget: { pointer in
            let renderer = Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue()
            precondition(!renderer.nativeTargets.isEmpty, "Unbalanced native snapshot")
            let saved = renderer.nativeTargets.removeLast()
            renderer.flushTarget()
            renderer.selectTarget(saved.0, Int32(saved.1.width), Int32(saved.1.height))
        }, read: { pointer, name, rect, pixels in
            Unmanaged<SceneRenderer>.fromOpaque(pointer!).takeUnretainedValue().readTexture(
                name, x: Int32(rect.minX), y: Int32(rect.minY), width: Int32(rect.width), height: Int32(rect.height), pixels: pixels!)
        }))
    }
    public func detachNativeContext() {
        nativeContext?.setBackend(MRRenderBackend())
        nativeContext = nil
    }
    deinit { nativeContext?.setBackend(MRRenderBackend()) }

    /// Application material classification sees fully transformed native vertices.
    open func nativeMaterial(texture: UInt32, vertices: UnsafeBufferPointer<MRRenderVertex>, blend: MRBlendFunction) -> (material: UInt32, attributes: UInt32) { (0,0) }

    /// Native nodes use y-up logical points. Convert once at the GPU boundary;
    /// both screen and texture targets then use the same top-row-first storage.
    open func enqueueNative(vertices: UnsafeBufferPointer<MRRenderVertex>, texture: UInt32,
                            blend: MRBlendFunction, sampling: MRTextureSampling, clip: CGRect, logicalSize size: CGSize) {
        precondition(size.width > 0 && size.height > 0)
        guard let image = texture == 0 ? white : textures[texture] else { preconditionFailure("Missing native texture") }
        let points = vertices.map { vertex in
            QuadRenderer.Vertex(position: SIMD2(vertex.x, Float(size.height)-vertex.y),
                texCoord: SIMD2(vertex.u, vertex.v), color: SIMD4(vertex.r, vertex.g, vertex.b, vertex.a))
        }
        let rectangle = CGRect(x: clip.minX/size.width, y: 1-clip.maxY/size.height,
                               width: clip.width/size.width, height: clip.height/size.height)
        let appearance = nativeMaterial(texture: texture, vertices: vertices, blend: blend)
        enqueue(Batch(material: appearance.material, attributes: appearance.attributes, vertices: points, texture: image,
            source: MTLBlendFactor(rawValue: UInt(blend.src.rawValue))!,
            destination: MTLBlendFactor(rawValue: UInt(blend.dst.rawValue))!, clip: rectangle,
            sampler: sampler(minFilter: sampling.minFilter == MRFilterNearest ? .nearest : .linear,
                             magFilter: sampling.magFilter == MRFilterNearest ? .nearest : .linear,
                             sAddress: sampling.sAddress == MRAddressRepeat ? .repeat : .clampToEdge,
                             tAddress: sampling.tAddress == MRAddressRepeat ? .repeat : .clampToEdge,
                             mipFilter: image.mipmapLevelCount>1 && sampling.minFilter == MRFilterLinear ? .linear : .notMipmapped), coordinateSize: size))
    }
    public init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw MetalRackError.setup("Cannot create command queue") }
        self.queue = queue
        quads = try QuadRenderer(device: device)
        guard let white = device.makeTexture(descriptor: .texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)) else {
            throw MetalRackError.setup("Cannot create white texture")
        }
        self.white = white
        super.init()
        var pixel: UInt32 = .max
        white.replace(region: MTLRegionMake2D(0,0,1,1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
    }
    public func selectTarget(_ name: UInt32, _ width: Int32, _ height: Int32) {
        if target != name {
            flushTarget()
            if target == 0 { screenBatches = batches; batches = [] }
            target = name
            if target == 0 { batches = screenBatches; screenBatches = [] }
            // A deferred screen draw must keep the pixels it sampled before a
            // later offscreen rewrite. Version only targets still referenced by
            // this frame; ordinary atlas/target ownership stays a single image.
            if target != 0, let image = textures[target], screenBatches.contains(where: { $0.texture === image }) {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:image.pixelFormat,width:image.width,height:image.height,mipmapped:false)
                descriptor.usage = [.shaderRead,.renderTarget]
                let replacement = device.makeTexture(descriptor:descriptor)!
                let command = queue.makeCommandBuffer()!
                let blit = command.makeBlitCommandEncoder()!
                blit.copy(from:image,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:image.width,height:image.height,depth:1),to:replacement,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
                blit.endEncoding();command.commit()
                textures[target] = replacement
            }
        }
        targetViewport = CGSize(width:Int(width),height:Int(height))
    }
    public func flushTarget() {
        guard target != 0, let texture = textures[target], !batches.isEmpty || targetClear != nil else { return }
        let command = queue.makeCommandBuffer()!
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = targetClear == nil ? .load : .clear
        pass.colorAttachments[0].storeAction = .store
        if let color = targetClear { pass.colorAttachments[0].clearColor = color }
        let encoder = command.makeRenderCommandEncoder(descriptor:pass)!
        encode(encoder, command, texture.width, texture.height, texture.pixelFormat)
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        precondition(command.status == .completed, "Metal render target failed: \(String(describing:command.error))")
        batches.removeAll(keepingCapacity:true); targetClear = nil
    }
    public func sampler(minFilter: MTLSamplerMinMagFilter, magFilter: MTLSamplerMinMagFilter,
                        sAddress: MTLSamplerAddressMode, tAddress: MTLSamplerAddressMode, mipFilter: MTLSamplerMipFilter = .notMipmapped) -> MTLSamplerState {
        let key = "\(minFilter.rawValue),\(magFilter.rawValue),\(sAddress.rawValue),\(tAddress.rawValue),\(mipFilter.rawValue)"
        if let cached = samplers[key] { return cached }
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = minFilter; descriptor.magFilter = magFilter; descriptor.mipFilter = mipFilter
        descriptor.sAddressMode = sAddress; descriptor.tAddressMode = tAddress
        let result = device.makeSamplerState(descriptor: descriptor)!
        samplers[key] = result
        return result
    }
    #if canImport(UIKit)
    public func install(in host: UIView) {
        if logicalSize == .zero { logicalSize = host.bounds.size }
        let view = MTKView(frame: host.bounds, device: device)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.isUserInteractionEnabled = false
        view.isPaused = true; view.enableSetNeedsDisplay = false
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm
        view.contentScaleFactor = host.window?.screen.nativeScale ?? UIScreen.main.nativeScale
        view.autoResizeDrawable = true
        host.addSubview(view)
        self.view = view
    }

    #endif

    open func pipeline(for batch: Batch, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        try! quads.pipeline(source: batch.source, destination: batch.destination, pixelFormat: pixelFormat)
    }
    open func prepareFragment(for batch: Batch, encoder: MTLRenderCommandEncoder, width: Int, height: Int) {}
    open func didStartDrawing(width: Int, height: Int, batchCount: Int) {}
    open func didEncodeFrame(command: MTLCommandBuffer, startTime: CFTimeInterval) {}
    open func present() {
        defer { batches.removeAll(keepingCapacity: true) }
        autoreleasepool { view?.draw() }
    }
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    public func draw(in view: MTKView) {
        let start = CACurrentMediaTime()
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor, let command = queue.makeCommandBuffer() else { return }
        pass.colorAttachments[0].clearColor = clear; pass.colorAttachments[0].loadAction = .clear
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        if !reportedDrawable {
            didStartDrawing(width: drawable.texture.width, height: drawable.texture.height, batchCount: batches.count)
            reportedDrawable = true
        }
        encode(encoder, command, drawable.texture.width, drawable.texture.height, view.colorPixelFormat)
        encoder.endEncoding(); command.present(drawable)
        didEncodeFrame(command: command, startTime: start)
        command.commit()
    }
    private func encode(_ encoder: MTLRenderCommandEncoder, _ command: MTLCommandBuffer, _ w: Int, _ h: Int, _ format: MTLPixelFormat) {
        quads.beginFrame(commandBuffer: command)
        for batch in batches {
            let x = max(0, min(w, Int((batch.clip.minX * Double(w)).rounded(.down))))
            let y = max(0, min(h, Int((batch.clip.minY * Double(h)).rounded(.down))))
            let right = max(x, min(w, Int((batch.clip.maxX * Double(w)).rounded(.up))))
            let bottom = max(y, min(h, Int((batch.clip.maxY * Double(h)).rounded(.up))))
            guard right > x, bottom > y else { continue }
            encoder.setScissorRect(MTLScissorRect(x:x,y:y,width:right-x,height:bottom-y))
            prepareFragment(for: batch, encoder: encoder, width: w, height: h)
            quads.encode(texture: batch.texture, vertices: batch.vertices,
                viewportSize: batch.coordinateSize == .zero ? logicalSize : batch.coordinateSize, encoder: encoder,
                pipeline: pipeline(for: batch, pixelFormat: format), sampler: batch.sampler)
        }
    }
    public func begin(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
    if target != 0 {
        batches.removeAll(keepingCapacity:true)
        targetClear = MTLClearColorMake(Double(r),Double(g),Double(b),Double(a))
        return
    }
    batches.removeAll(keepingCapacity:true)
    clear = MTLClearColorMake(Double(r),Double(g),Double(b),Double(a))
}
    public func uploadTexture(_ name: UInt32, width: Int32, height: Int32, pixels: UnsafeRawPointer) {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:Int(width),height:Int(height),mipmapped:false)
    descriptor.usage = [.shaderRead, .renderTarget]
    let texture = device.makeTexture(descriptor:descriptor)!
    texture.replace(region:MTLRegionMake2D(0,0,Int(width),Int(height)),mipmapLevel:0,withBytes:pixels,bytesPerRow:Int(width)*4)
    textures[name] = texture
}
    public func generateMipmaps(_ name: UInt32) {
        flushTarget()
        guard let source = textures[name] else { preconditionFailure("Missing native mipmap source") }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: source.pixelFormat,width: source.width,height: source.height,mipmapped: true)
        descriptor.usage = [.shaderRead,.renderTarget]
        let destination = device.makeTexture(descriptor: descriptor)!
        let command = queue.makeCommandBuffer()!, encoder = command.makeBlitCommandEncoder()!
        encoder.copy(from: source,sourceSlice: 0,sourceLevel: 0,sourceOrigin: MTLOrigin(x: 0,y: 0,z: 0),sourceSize: MTLSize(width: source.width,height: source.height,depth: 1),to: destination,destinationSlice: 0,destinationLevel: 0,destinationOrigin: MTLOrigin(x: 0,y: 0,z: 0))
        encoder.generateMipmaps(for: destination);encoder.endEncoding();command.commit();command.waitUntilCompleted()
        precondition(command.status == .completed,"Native mipmap generation failed")
        textures[name] = destination
    }
    public func enqueue(_ batch: Batch) { batches.append(batch) }

    public func readTexture(_ name: UInt32, x: Int32, y: Int32, width: Int32, height: Int32, pixels: UnsafeMutableRawPointer) {
    flushTarget()
    guard let texture = textures[name] else { preconditionFailure("Missing Metal readback texture") }
    texture.getBytes(pixels,bytesPerRow:Int(width)*4,from:MTLRegionMake2D(Int(x),Int(y),Int(width),Int(height)),mipmapLevel:0)
}
    public func clearRectangle(_ color: UnsafePointer<Float>, rect: UnsafePointer<Int32>) {
    guard let image = textures[target] else { preconditionFailure("Missing clear target") }
    let left = max(0,Int(rect[0])), top = max(0,Int(rect[1]))
    let right = min(image.width,Int(rect[0]+rect[2])), bottom = min(image.height,Int(rect[1]+rect[3]))
    guard right > left && bottom > top else { return }
    let points = [(left,top),(right,top),(left,bottom),(left,bottom),(right,top),(right,bottom)]
    let vertices = points.map { point in
        QuadRenderer.Vertex(position:SIMD2(Float(point.0)*Float(logicalSize.width)/Float(image.width),Float(point.1)*Float(logicalSize.height)/Float(image.height)),texCoord:.zero,color:SIMD4(color[0],color[1],color[2],color[3]))
    }
    batches.append(.init(vertices:vertices,texture:white,source:.one,destination:.zero,clip:CGRect(x:0,y:0,width:1,height:1),sampler:quads.samplerState))
}
}
#endif
