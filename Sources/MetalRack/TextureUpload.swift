import CoreGraphics
import Metal

public enum TextureUpload {
    /// Uploads decoded pixels once in the core's premultiplied BGRA format.
    public static func makeTexture(device: MTLDevice, image: CGImage,
                                   flipVertically: Bool = false,
                                   colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()) -> MTLTexture? {
        let width = image.width, height = image.height, rowBytes = image.width * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        let decoded = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return false }
            context.interpolationQuality = .high
            if flipVertically {
                context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard decoded else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        pixels.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: rowBytes)
        }
        return texture
    }
}
