#if canImport(UIKit)
import UIKit

public extension LineRenderer {
    convenience init(imageLoader: @escaping (String) -> UIImage?) {
        self.init(textureLoader: { device, name in
            guard let image = imageLoader(name), let cgImage = image.cgImage,
                  let texture = TextureUpload.makeTexture(device: device, image: cgImage, flipVertically: true) else { return nil }
            return Tick(texture: texture, size: image.size)
        })
    }
}
#endif
