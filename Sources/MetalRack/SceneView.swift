#if canImport(UIKit) && canImport(MetalKit)
import UIKit
import MetalKit
import MetalRackScene

/// UIKit host for the native scene path. Scene coordinates are view points, y-up;
/// the drawable uses the screen's native density. Application pause/save/scene
/// decisions remain with the owner, which controls `isRunning` explicitly.
public final class SceneView: MTKView {
    public let renderer: SceneRenderer
    public let context: MRRenderContext
    public let driver: MRSceneDriver
    public let input: MRInput
    public var scene: MRNode? {
        get { driver.scene }
        set { cancelPointers(); driver.scene = newValue }
    }
    public var isRunning = false {
        didSet {
            guard oldValue != isRunning else { return }
            if !isRunning { cancelPointers() }
            updateClock()
        }
    }
    private final class FrameTarget: NSObject {
        weak var owner: SceneView?
        @objc func frame(_ link: CADisplayLink) { owner?.frame(link) }
    }
    private let frameTarget = FrameTarget()
    private var clock: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var pointerIDs: [ObjectIdentifier: UInt] = [:]
    private var nextPointerID: UInt = 1

    public init(frame: CGRect, renderer: SceneRenderer, scheduler: MRScheduler = MRScheduler(), input: MRInput = MRInput()) {
        self.renderer = renderer
        self.input = input
        context = MRRenderContext()
        driver = MRSceneDriver(context: context,scheduler: scheduler,input: input)
        super.init(frame: frame,device: renderer.device)
        renderer.attachNativeContext(context)
        renderer.view = self
        delegate = renderer
        colorPixelFormat = .bgra8Unorm
        isPaused = true                 // The scene driver presents completed frames.
        enableSetNeedsDisplay = false
        autoResizeDrawable = true
        isMultipleTouchEnabled = true
        frameTarget.owner = self
        let link = CADisplayLink(target: frameTarget,selector: #selector(FrameTarget.frame(_:)))
        link.isPaused = true
        link.add(to: .main,forMode: .common)
        clock = link
        driver.logicalSize = bounds.size
    }
    @available(*,unavailable)
    public required init(coder: NSCoder) { fatalError("Create SceneView with its native renderer") }
    deinit {
        clock?.invalidate()
        input.cancelAllPointers()
        renderer.detachNativeContext()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        driver.logicalSize = bounds.size
    }
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if let screen = window?.screen { contentScaleFactor = screen.nativeScale }
        else { cancelPointers() }
        updateClock()
    }
    private func updateClock() {
        lastTimestamp = nil
        clock?.preferredFramesPerSecond = preferredFramesPerSecond
        clock?.isPaused = !isRunning || window == nil
    }
    private func frame(_ link: CADisplayLink) {
        guard isRunning, window != nil, bounds.width>0, bounds.height>0 else { return }
        let elapsed = lastTimestamp.map { max(0,link.timestamp-$0) } ?? 0
        lastTimestamp = link.timestamp
        driver.step(Float(elapsed))
    }
    /// Explicit focus/lifecycle cancellation, also used by stop and scene changes.
    public func cancelPointers() {
        pointerIDs.removeAll()
        input.cancelAllPointers()
    }
    private func sample(_ touch: UITouch, id: UInt) -> MRPointerEvent {
        func scenePoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x-bounds.minX,y: bounds.maxY-point.y)
        }
        return MRPointerEvent(identifier: id,position: scenePoint(touch.location(in: self)),
            previousPosition: scenePoint(touch.previousLocation(in: self)),timestamp: touch.timestamp)
    }
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isRunning else { return }
        for touch in touches {
            guard isRunning else { break }
            let id = nextPointerID; nextPointerID &+= 1
            pointerIDs[ObjectIdentifier(touch)] = id
            input.begin(sample(touch,id: id))
        }
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = pointerIDs[ObjectIdentifier(touch)] else { continue }
            input.move(sample(touch,id: id))
        }
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = pointerIDs.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            input.end(sample(touch,id: id))
        }
    }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = pointerIDs.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            input.cancel(sample(touch,id: id))
        }
    }
}
#endif
