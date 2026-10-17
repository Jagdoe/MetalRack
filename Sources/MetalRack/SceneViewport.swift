import CoreGraphics

/// Shared display transform for rendering and pointer hit testing, in pixels or points.
public struct SceneViewport {
    public let scale: CGFloat
    public let offset: CGPoint

    public init(logicalSize: CGSize, displaySize: CGSize) {
        guard logicalSize.width > 0, logicalSize.height > 0,
              displaySize.width > 0, displaySize.height > 0,
              logicalSize.width.isFinite, logicalSize.height.isFinite,
              displaySize.width.isFinite, displaySize.height.isFinite else {
            scale = 0; offset = .zero
            return
        }
        scale = min(displaySize.width / logicalSize.width, displaySize.height / logicalSize.height)
        offset = CGPoint(x: (displaySize.width - logicalSize.width * scale) / 2,
                         y: (displaySize.height - logicalSize.height * scale) / 2)
    }

    public func logicalPoint(from point: CGPoint) -> CGPoint? {
        guard scale > 0 else { return nil }
        return CGPoint(x: (point.x - offset.x) / scale, y: (point.y - offset.y) / scale)
    }

    public func displayPoint(from point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + offset.x, y: point.y * scale + offset.y)
    }
}
