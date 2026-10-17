import MetalKit
import QuartzCore
import simd
import ImageIO

/// General sprite renderer derived from ZombieSwift MetalRack's direct-quad path.
/// Keeps snapshot separation, texture caching, ordered batching, and triple buffering.
public final class SpriteRenderer: NSObject, MTKViewDelegate {
    public typealias Vertex = QuadRenderer.Vertex
    private struct Batch {
        let texture: MTLTexture
        let start: Int
        var count: Int
    }

    public let device: MTLDevice
    public let textures: SpriteTextureLibrary
    public var makeSnapshot: ((TimeInterval) -> SpriteSnapshot)?
    public var onFailure: ((String) -> Void)?

    private let queue: MTLCommandQueue
    private let core: QuadRenderer
    private var previousTime: CFTimeInterval?

    public init(bundle: Bundle = .main, atlasResource: String? = nil) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw MetalRackError.setup("Metal is unavailable")
        }
        self.device = device; self.queue = queue
        core = try QuadRenderer(device: device)
        textures = try SpriteTextureLibrary(device: device, bundle: bundle, atlasResource: atlasResource)
        super.init()
    }

    public func resetClock() { previousTime = nil }
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard view.drawableSize.width > 0, view.drawableSize.height > 0,
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer(), let makeSnapshot else { return }
        let now = CACurrentMediaTime()
        let delta = previousTime.map { min(max(now - $0, 0), 0.1) } ?? 0
        previousTime = now
        let snapshot = makeSnapshot(delta)
        do {
            let (vertices, batches) = try geometry(for: snapshot, viewport: view.drawableSize)
            guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            core.beginFrame(commandBuffer: command)
            for batch in batches {
                core.encode(texture: batch.texture, vertices: Array(vertices[batch.start..<(batch.start + batch.count)]),
                            viewportSize: view.drawableSize, encoder: encoder)
            }
            encoder.endEncoding()
            let report = onFailure
            command.addCompletedHandler { if let error = $0.error { report?(error.localizedDescription) } }
            command.present(drawable)
            command.commit()
        } catch {
            view.isPaused = true
            onFailure?(error.localizedDescription)
        }
    }

    private func geometry(for snapshot: SpriteSnapshot, viewport: CGSize) throws -> ([Vertex], [Batch]) {
        var vertices: [Vertex] = []
        var batches: [Batch] = []
        func append(_ quad: [Vertex], texture: MTLTexture) {
            if let last = batches.last, last.texture === texture {
                batches[batches.count - 1].count += quad.count
            } else {
                batches.append(Batch(texture: texture, start: vertices.count, count: quad.count))
            }
            vertices.append(contentsOf: quad)
        }
        let background = try textures.region(named: snapshot.backgroundImage)
        let scaleToFill = max(viewport.width / CGFloat(background.texture.width),
                              viewport.height / CGFloat(background.texture.height))
        let backgroundSize = CGSize(width: CGFloat(background.texture.width) * scaleToFill,
                                    height: CGFloat(background.texture.height) * scaleToFill)
        let backgroundSprite = SpriteSnapshot.Sprite(image: snapshot.backgroundImage,
            position: CGPoint(x: viewport.width / 2, y: viewport.height / 2), size: backgroundSize)
        append(quad(for: backgroundSprite, region: background, scale: 1, offset: .zero), texture: background.texture)

        let mapping = SceneViewport(logicalSize: snapshot.logicalSize, displaySize: viewport)
        let scale = mapping.scale
        let offset = mapping.offset
        // Stable ordering preserves translucent compositing within each layer.
        let sprites = snapshot.sprites.enumerated().sorted {
            $0.element.zIndex == $1.element.zIndex ? $0.offset < $1.offset : $0.element.zIndex < $1.element.zIndex
        }
        for entry in sprites {
            let sprite = entry.element
            let center = CGPoint(x: sprite.position.x * scale + offset.x, y: sprite.position.y * scale + offset.y)
            let radius = hypot(sprite.size.width, sprite.size.height) * scale
            guard center.x + radius >= 0, center.y + radius >= 0,
                  center.x - radius <= viewport.width, center.y - radius <= viewport.height else { continue }
            let region = try textures.region(named: sprite.image)
            append(quad(for: sprite, region: region, scale: scale, offset: offset), texture: region.texture)
        }
        return (vertices, batches)
    }

    private func quad(for sprite: SpriteSnapshot.Sprite, region: SpriteTextureLibrary.Region,
                      scale: CGFloat, offset: CGPoint) -> [Vertex] {
        let width = sprite.size.width, height = sprite.size.height
        let left = -width * sprite.anchor.x, top = -height * sprite.anchor.y
        let corners = [CGPoint(x: left, y: top), CGPoint(x: left + width, y: top),
                       CGPoint(x: left + width, y: top + height), CGPoint(x: left, y: top + height)]
        let sine = sin(sprite.rotation), cosine = cos(sprite.rotation)
        let positions = corners.map { point in
            SIMD2<Float>(Float((sprite.position.x + point.x * cosine - point.y * sine) * scale + offset.x),
                         Float((sprite.position.y + point.x * sine + point.y * cosine) * scale + offset.y))
        }
        let uv = region.uvRect
        let u0 = sprite.flippedX ? uv.maxX : uv.minX, u1 = sprite.flippedX ? uv.minX : uv.maxX
        let coordinates = [SIMD2<Float>(Float(u0), Float(uv.minY)), SIMD2<Float>(Float(u1), Float(uv.minY)),
                           SIMD2<Float>(Float(u1), Float(uv.maxY)), SIMD2<Float>(Float(u0), Float(uv.maxY))]
        return [0, 1, 2, 0, 2, 3].map { Vertex(position: positions[$0], texCoord: coordinates[$0], color: SIMD4(sprite.tint.x * sprite.tint.w, sprite.tint.y * sprite.tint.w, sprite.tint.z * sprite.tint.w, sprite.tint.w)) }
    }

    #if DEBUG && os(macOS)
    /// Uses the real shader and scene geometry for automated GPU rendering checks.
    public func capture(_ snapshot: SpriteSnapshot, size: CGSize, to url: URL) throws {
        let (vertices, batches) = try geometry(for: snapshot, viewport: size)
        let width = Int(size.width), height = Int(size.height)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                 width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private
        let rowBytes = ((width * 4 + 255) / 256) * 256
        guard let target = device.makeTexture(descriptor: descriptor),
              let readback = device.makeBuffer(length: rowBytes * height, options: .storageModeShared),
              let command = queue.makeCommandBuffer() else {
            throw MetalRackError.setup("Cannot allocate capture buffers.")
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            throw MetalRackError.setup("Cannot encode capture.")
        }
        core.beginFrame(commandBuffer: command)
        for batch in batches {
            core.encode(texture: batch.texture, vertices: Array(vertices[batch.start..<(batch.start + batch.count)]),
                        viewportSize: size, encoder: encoder)
        }
        encoder.endEncoding()
        guard let blit = command.makeBlitCommandEncoder() else { throw MetalRackError.setup("Cannot read capture.") }
        blit.copy(from: target, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: width, height: height, depth: 1), to: readback,
                  destinationOffset: 0, destinationBytesPerRow: rowBytes, destinationBytesPerImage: rowBytes * height)
        blit.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        let data = Data(bytes: readback.contents(), count: rowBytes * height)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: rowBytes, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                                    .union(.byteOrder32Little), provider: provider,
                                  decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let output = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw MetalRackError.setup("Cannot write capture.")
        }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw MetalRackError.setup("Cannot finish capture.") }
    }
    #endif
}
