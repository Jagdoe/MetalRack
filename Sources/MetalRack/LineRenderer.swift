import Metal
import MetalKit
import simd
import QuartzCore

// MARK: - LineSegment

/// Describes one animated line path between two points.
public struct LineSegment: Equatable {
    public let start: CGPoint
    public let end: CGPoint
    public let usesCurve: Bool
    public let tickImageName: String

    public init(start: CGPoint, end: CGPoint, usesCurve: Bool = true, tickImageName: String) {
        self.start = start
        self.end = end
        self.usesCurve = usesCurve
        self.tickImageName = tickImageName
    }
}

// MARK: - LineRenderer

/// Draws animated sprite ticks along line segments using Metal.
public final class LineRenderer: NSObject, MTKViewDelegate {
    private typealias LineVertex = QuadRenderer.Vertex

    public let device: MTLDevice?

    public var segments: [LineSegment] = [] {
        didSet {
            if segments != oldValue {
                animationStates.removeAll()
            }
            refreshTexture()
        }
    }

    private struct LineAnimationState {
        var angle1: CGFloat
        var angle2: CGFloat
        let angle1Original: CGFloat
        let angle2Original: CGFloat
        let adjust1Max: CGFloat
        let adjust2Max: CGFloat
        var movementPercent: CGFloat
        var reverse1: Bool
        var reverse2: Bool
    }

    private let commandQueue: MTLCommandQueue?
    private var texture: MTLTexture?
    private var tickCache: [String: Tick] = [:]
    private var animationStates: [Int: LineAnimationState] = [:]
    private var lastUpdateTime: CFTimeInterval?

    private let core: QuadRenderer?
    public struct Tick {
        public let texture: MTLTexture
        public let size: CGSize
        public init(texture: MTLTexture, size: CGSize) { self.texture = texture; self.size = size }
    }
    private let textureLoader: (MTLDevice, String) -> Tick?
    private var tickSize = CGSize(width: 24, height: 26)
    public init(textureLoader: @escaping (MTLDevice, String) -> Tick?) {
        self.textureLoader = textureLoader
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()

        let core = device.flatMap { try? QuadRenderer(device: $0) }
        self.core = core
        self.texture = nil

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

        defer {
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        guard
            let texture
        else {
            return
        }

        let time = CACurrentMediaTime()
        let delta = lastUpdateTime.map { max(0, min(time - $0, 1.0 / 15.0)) } ?? (1.0 / 60.0)
        lastUpdateTime = time
        let vertices = makeVertices(delta: delta)
        guard !vertices.isEmpty else { return }

        core?.beginFrame(commandBuffer: commandBuffer)
        core?.encode(texture: texture, vertices: vertices, viewportSize: view.bounds.size, encoder: encoder)
    }

    private func makeVertices(delta: CFTimeInterval) -> [LineVertex] {
        let spriteSize = tickSize
        let spacing = max(spriteSize.width * 1.5, 1)
        let travelSpeed: CGFloat = 16.0 / 30.0
        let distortionAngleMin: CGFloat = 15
        let distortionAngleDelta: CGFloat = 30
        let wiggleMax: CGFloat = 20
        var vertices: [LineVertex] = []

        for (segmentIndex, segment) in segments.enumerated() {
            let dx = segment.end.x - segment.start.x
            let dy = segment.end.y - segment.start.y
            let length = sqrt(dx * dx + dy * dy)
            guard length > 12 else { continue }

            let tickCount = min(100, max(2, Int(length / spacing)))
            let control1: CGPoint
            let control2: CGPoint
            if segment.usesCurve {
                var state = animationStates[segmentIndex] ?? makeLineAnimationState(
                    segmentIndex: segmentIndex,
                    distortionAngleMin: distortionAngleMin,
                    distortionAngleDelta: distortionAngleDelta,
                    wiggleMax: wiggleMax
                )
                updateLineAnimationState(&state, delta: CGFloat(delta), travelSpeed: travelSpeed)
                animationStates[segmentIndex] = state
                control1 = controlPoint(
                    start: segment.start,
                    delta: CGPoint(x: dx, y: dy),
                    fraction: 0.33,
                    angleDegrees: state.angle1
                )
                control2 = controlPoint(
                    start: segment.start,
                    delta: CGPoint(x: dx, y: dy),
                    fraction: 0.67,
                    angleDegrees: state.angle2
                )
                appendCurveTicks(
                    tickCount: tickCount,
                    segment: segment,
                    control1: control1,
                    control2: control2,
                    movementPercent: state.movementPercent,
                    spriteSize: spriteSize,
                    to: &vertices
                )
            } else {
                control1 = CGPoint(x: segment.start.x + dx * 0.33, y: segment.start.y + dy * 0.33)
                control2 = CGPoint(x: segment.start.x + dx * 0.67, y: segment.start.y + dy * 0.67)
                appendCurveTicks(
                    tickCount: tickCount,
                    segment: segment,
                    control1: control1,
                    control2: control2,
                    movementPercent: 0,
                    spriteSize: spriteSize,
                    to: &vertices
                )
            }
        }

        return vertices
    }

    private func makeLineAnimationState(
        segmentIndex: Int,
        distortionAngleMin: CGFloat,
        distortionAngleDelta: CGFloat,
        wiggleMax: CGFloat
    ) -> LineAnimationState {
        let seed = CGFloat(segmentIndex + 1)
        let angle1 = signedOscillation(seed: seed * 1.31, minimum: distortionAngleMin, delta: distortionAngleDelta)
        let angle2 = pseudoRandom(seed: seed * 2.17) >= 0.5 ? -angle1 : angle1
        return LineAnimationState(
            angle1: angle1,
            angle2: angle2,
            angle1Original: angle1,
            angle2Original: angle2,
            adjust1Max: (wiggleMax / 2) + pseudoRandom(seed: seed * 3.43) * (wiggleMax / 2),
            adjust2Max: (wiggleMax / 2) + pseudoRandom(seed: seed * 5.29) * (wiggleMax / 2),
            movementPercent: 0,
            reverse1: false,
            reverse2: false
        )
    }

    private func updateLineAnimationState(
        _ state: inout LineAnimationState,
        delta: CGFloat,
        travelSpeed: CGFloat
    ) {
        updateLineAngle(
            angle: &state.angle1,
            original: state.angle1Original,
            adjustMax: state.adjust1Max,
            reverse: &state.reverse1
        )
        updateLineAngle(
            angle: &state.angle2,
            original: state.angle2Original,
            adjustMax: state.adjust2Max,
            reverse: &state.reverse2
        )
        state.movementPercent += travelSpeed * delta
        if state.movementPercent >= 1 {
            state.movementPercent -= 1
        }
    }

    private func updateLineAngle(
        angle: inout CGFloat,
        original: CGFloat,
        adjustMax: CGFloat,
        reverse: inout Bool
    ) {
        let minimumAngle = original - adjustMax
        let maximumAngle = original + adjustMax
        let remaining = min(maximumAngle - angle, angle - minimumAngle)
        let percentRemaining = min(max(remaining / max(adjustMax, 0.001), 0), 100)
        let amount = (0.5 * percentRemaining) + (0.5 / 8)
        if angle < minimumAngle || angle > maximumAngle {
            reverse.toggle()
        }
        angle += reverse ? -amount : amount
    }

    private func appendCurveTicks(
        tickCount: Int,
        segment: LineSegment,
        control1: CGPoint,
        control2: CGPoint,
        movementPercent: CGFloat,
        spriteSize: CGSize,
        to vertices: inout [LineVertex]
    ) {
        var points: [CGPoint] = []
        points.reserveCapacity(tickCount)
        for index in 0..<tickCount {
            let progress = (CGFloat(index) + movementPercent) / CGFloat(tickCount)
            points.append(
                bezierPoint(
                    start: segment.start,
                    control1: control1,
                    control2: control2,
                    end: segment.end,
                    t: progress
                )
            )
        }

        for index in points.indices {
            let previousIndex = max(0, index - 1)
            let nextIndex = min(points.count - 1, index + 1)
            let nextPoint = nextIndex > index ? points[nextIndex] : segment.end
            let previousPoint = points[previousIndex]
            let angle = atan2(nextPoint.y - previousPoint.y, nextPoint.x - previousPoint.x)
            appendQuad(
                centeredAt: points[index],
                size: spriteSize,
                angle: angle,
                to: &vertices
            )
        }
    }

    private func refreshTexture() {
        guard let device else { return }
        let tickImageName = segments.first?.tickImageName ?? ""
        let tick = tickCache[tickImageName] ?? textureLoader(device, tickImageName)
        if let tick { tickCache[tickImageName] = tick }
        texture = tick?.texture
        tickSize = tick?.size ?? CGSize(width: 24, height: 26)
    }

    private func signedOscillation(seed: CGFloat, minimum: CGFloat, delta: CGFloat) -> CGFloat {
        let magnitude = minimum + (pseudoRandom(seed: seed) * delta)
        return cos(seed * 1.7) >= 0 ? magnitude : -magnitude
    }

    private func pseudoRandom(seed: CGFloat) -> CGFloat {
        let value = sin(seed * 12.9898) * 43_758.5453
        return value - floor(value)
    }

    private func controlPoint(start: CGPoint, delta: CGPoint, fraction: CGFloat, angleDegrees: CGFloat) -> CGPoint {
        let rotated = CGPoint(
            x: delta.x * cos(angleDegrees * (.pi / 180)) - delta.y * sin(angleDegrees * (.pi / 180)),
            y: delta.x * sin(angleDegrees * (.pi / 180)) + delta.y * cos(angleDegrees * (.pi / 180))
        )
        return CGPoint(x: start.x + rotated.x * fraction, y: start.y + rotated.y * fraction)
    }

    private func bezierPoint(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let inverse = 1 - t
        let a = inverse * inverse * inverse
        let b = 3 * inverse * inverse * t
        let c = 3 * inverse * t * t
        let d = t * t * t
        return CGPoint(
            x: (a * start.x) + (b * control1.x) + (c * control2.x) + (d * end.x),
            y: (a * start.y) + (b * control1.y) + (c * control2.y) + (d * end.y)
        )
    }

    private func appendQuad(centeredAt center: CGPoint, size: CGSize, angle: CGFloat, to vertices: inout [LineVertex]) {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let corners = [
            CGPoint(x: -halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: -halfHeight),
            CGPoint(x: halfWidth, y: halfHeight),
            CGPoint(x: -halfWidth, y: halfHeight)
        ]
        let rotated = corners.map { corner -> SIMD2<Float> in
            let x = corner.x * cos(angle) - corner.y * sin(angle) + center.x
            let y = corner.x * sin(angle) + corner.y * cos(angle) + center.y
            return SIMD2(Float(x), Float(y))
        }

        let texCoords: [SIMD2<Float>] = [
            SIMD2(0, 0),
            SIMD2(1, 0),
            SIMD2(1, 1),
            SIMD2(0, 1)
        ]

        let triangleIndices = [0, 1, 2, 0, 2, 3]
        for index in triangleIndices {
            vertices.append(LineVertex(position: rotated[index], texCoord: texCoords[index], color: SIMD4(repeating: 1)))
        }
    }

}
