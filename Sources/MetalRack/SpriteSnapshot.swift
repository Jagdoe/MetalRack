import CoreGraphics
import simd

/// A game-independent frame: game code owns simulation; MetalRack owns drawing.
public struct SpriteSnapshot {
    public struct Sprite {
        public var image: String
        public var position: CGPoint
        public var size: CGSize
        public var rotation: CGFloat = 0
        public var tint = SIMD4<Float>(repeating: 1)
        public var anchor = CGPoint(x: 0.5, y: 0.5)
        public var flippedX = false
        public var zIndex = 0
        public init(image: String, position: CGPoint, size: CGSize, rotation: CGFloat = 0,
                    tint: SIMD4<Float> = SIMD4(repeating: 1), anchor: CGPoint = CGPoint(x: 0.5, y: 0.5),
                    flippedX: Bool = false, zIndex: Int = 0) {
            self.image = image; self.position = position; self.size = size; self.rotation = rotation
            self.tint = tint; self.anchor = anchor; self.flippedX = flippedX; self.zIndex = zIndex
        }
    }

    public var logicalSize: CGSize
    public var backgroundImage: String
    public var sprites: [Sprite]
    public init(logicalSize: CGSize, backgroundImage: String, sprites: [Sprite]) {
        self.logicalSize = logicalSize; self.backgroundImage = backgroundImage; self.sprites = sprites
    }
}
