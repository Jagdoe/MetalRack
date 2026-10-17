#if canImport(UIKit)
import SwiftUI

// MARK: - EffectSprite

/// Cycles through image frames for simple sprite effects.
public struct EffectSprite<Placeholder: View>: View {
    let candidateNames: [String]
    var opacity: Double = 1
    var scale: CGFloat = 1
    var blendMode: BlendMode = .normal
    var duration: TimeInterval = 0.4
    var repeatCount: Int = 0
    var randomAngle: Bool = false
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var startDate = Date()
    @State private var rotation: Angle = .zero

    public init(candidateNames: [String], opacity: Double = 1, scale: CGFloat = 1,
                blendMode: BlendMode = .normal, duration: TimeInterval = 0.4, repeatCount: Int = 0,
                randomAngle: Bool = false, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.candidateNames = candidateNames; self.opacity = opacity; self.scale = scale
        self.blendMode = blendMode; self.duration = duration; self.repeatCount = repeatCount
        self.randomAngle = randomAngle; self.placeholder = placeholder
    }
    public var body: some View {
        TimelineView(.animation) { context in
            let frameNames = candidateNames.isEmpty ? [""] : candidateNames
            let frameCount = max(frameNames.count, 1)
            let frameDuration = max(duration / Double(frameCount), 0.01)
            let elapsed = max(context.date.timeIntervalSince(startDate), 0)
            let cycleLength = frameDuration * Double(frameCount)
            let cycleIndex = max(Int(elapsed / max(cycleLength, 0.01)), 0)
            let clampedCycleIndex = repeatCount > 0 ? min(cycleIndex, repeatCount) : cycleIndex
            let localElapsed = repeatCount > 0 && cycleIndex >= repeatCount
                ? cycleLength - 0.0001
                : elapsed - (Double(clampedCycleIndex) * cycleLength)
            let frameIndex = min(max(Int(localElapsed / frameDuration), 0), frameCount - 1)

            SpriteImage(candidateNames: [frameNames[frameIndex]], placeholder: placeholder)
                .scaleEffect(scale)
                .opacity(opacity)
                .blendMode(blendMode)
                .rotationEffect(rotation)
                .onAppear {
                    startDate = Date()
                    if randomAngle {
                        rotation = .degrees(Double.random(in: 0 ... 360))
                    }
                }
        }
    }
}

#endif
