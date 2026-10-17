import Foundation
import CoreGraphics
import ImageIO
import Metal

/// Retained textures and atlas regions, shared by every scene in a renderer.
public final class SpriteTextureLibrary {
    private struct Frame: Decodable {
        let x: Int
        let y: Int
        let w: Int
        let h: Int
    }
    private struct Atlas: Decodable {
        struct Entry: Decodable { let frame: Frame }
        struct Metadata: Decodable {
            struct Size: Decodable { let w: Int; let h: Int }
            let image: String
            let size: Size
        }
        let frames: [String: Entry]
        let meta: Metadata
    }
    public struct Region {
        public let texture: MTLTexture
        public let uvRect: CGRect
        public let aspectRatio: CGFloat
    }

    private let device: MTLDevice
    private let bundle: Bundle
    private let atlas: Atlas?
    private var cache: [String: MTLTexture] = [:]
    private var additionalRegions: [String: Region] = [:]

    public init(device: MTLDevice, bundle: Bundle = .main, atlasResource: String? = nil) throws {
        self.device = device
        self.bundle = bundle
        if let atlasResource {
            guard let url = bundle.url(forResource: atlasResource, withExtension: "json") else {
                throw MetalRackError.resource(atlasResource + ".json")
            }
            atlas = try JSONDecoder().decode(Atlas.self, from: Data(contentsOf: url))
        } else { atlas = nil }
        if let atlas { _ = try texture(named: atlas.meta.image) }

    }

    public func region(named name: String) throws -> Region {
        if let region = additionalRegions[name] { return region }
        if let atlas, let entry = atlas.frames[name] {
            let f = entry.frame
            return Region(
                texture: try texture(named: atlas.meta.image),
                uvRect: CGRect(x: CGFloat(f.x) / CGFloat(atlas.meta.size.w),
                               y: CGFloat(f.y) / CGFloat(atlas.meta.size.h),
                               width: CGFloat(f.w) / CGFloat(atlas.meta.size.w),
                               height: CGFloat(f.h) / CGFloat(atlas.meta.size.h)),
                aspectRatio: CGFloat(f.w) / CGFloat(f.h)
            )
        }
        let image = try texture(named: name)
        return Region(texture: image, uvRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                      aspectRatio: CGFloat(image.width) / CGFloat(image.height))
    }

    /// Namespaced atlases let scenes add art without modifying the shared space atlas.
    public func registerAtlas(resource: String, prefix: String) throws {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw MetalRackError.resource(resource + ".json")
        }
        let atlas = try JSONDecoder().decode(Atlas.self, from: Data(contentsOf: url))
        let texture = try texture(named: atlas.meta.image)
        for (name, entry) in atlas.frames {
            let frame = entry.frame
            additionalRegions[prefix + name] = Region(texture: texture,
                uvRect: CGRect(x: CGFloat(frame.x) / CGFloat(atlas.meta.size.w),
                               y: CGFloat(frame.y) / CGFloat(atlas.meta.size.h),
                               width: CGFloat(frame.w) / CGFloat(atlas.meta.size.w),
                               height: CGFloat(frame.h) / CGFloat(atlas.meta.size.h)),
                aspectRatio: CGFloat(frame.w) / CGFloat(frame.h))
        }
    }

    private func texture(named name: String) throws -> MTLTexture {
        if let existing = cache[name] { return existing }
        let file = name as NSString
        guard let url = bundle.url(forResource: file.deletingPathExtension, withExtension: file.pathExtension),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw MetalRackError.resource(name) }
        guard let texture = TextureUpload.makeTexture(device: device, image: image,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
            throw MetalRackError.setup("Cannot allocate texture \(name)")
        }
        texture.label = name
        cache[name] = texture
        return texture
    }
}

public enum MetalRackError: LocalizedError {
    case resource(String)
    case setup(String)
    public var errorDescription: String? {
        switch self {
        case .resource(let name): return "Cannot load artwork: \(name)."
        case .setup(let message): return message
        }
    }
}
