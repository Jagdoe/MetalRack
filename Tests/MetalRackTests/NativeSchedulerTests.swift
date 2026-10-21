import XCTest
import MetalRackScene

private final class ClockTarget: NSObject {
    var handler: (Float) -> Void = { _ in }
    @objc func update(_ seconds: Float) { handler(seconds) }
    @objc func timer(_ seconds: Float) { handler(seconds) }
}
private final class FrameLog: NSObject {
    var phases: [String] = []
    var updatedPositions: [CGFloat] = []
    var drawnPositions: [CGFloat] = []
}
private final class FrameNode: MRNode {
    var record: (() -> Void)?
    override func draw(_ context: MRRenderContext!) { record?() }
}
final class NativeSchedulerTests: XCTestCase {
    func testFrameDriverActionsPrecedeGameUpdatesAndDrawing() {
        let log = FrameLog(), context = MRRenderContext(), scheduler = MRScheduler()
        var backend = MRRenderBackend()
        backend.context = Unmanaged.passUnretained(log).toOpaque()
        backend.beginFrame = { pointer, _ in
            Unmanaged<FrameLog>.fromOpaque(pointer!).takeUnretainedValue().phases.append("begin")
        }
        backend.draw = { _, _, _, _, _, _, _, _ in }
        backend.present = { pointer in
            Unmanaged<FrameLog>.fromOpaque(pointer!).takeUnretainedValue().phases.append("present")
        }
        context.setBackend(backend)
        let driver = MRSceneDriver(context: context,scheduler: scheduler)
        driver.logicalSize = CGSize(width: 8,height: 8)
        let actor = FrameNode(), listener = ClockTarget()
        actor.record = { [weak actor] in
            log.phases.append("draw"); log.drawnPositions.append(actor!.position.x)
        }
        listener.handler = { [weak actor] _ in
            log.phases.append("update"); log.updatedPositions.append(actor!.position.x)
        }
        driver.scene = actor
        scheduler.scheduleUpdate(target: listener,priority: 0,paused: false)
        actor.run(MRMoveBy(duration: 1,position: CGPoint(x: 10,y: 0)))
        driver.step(0); driver.step(0.5)
        XCTAssertEqual(Array(log.phases.suffix(4)), ["update","begin","draw","present"])
        XCTAssertEqual(log.updatedPositions, [0,5])
        XCTAssertEqual(log.drawnPositions, [0,5])
        driver.paused = true; driver.step(1)
        XCTAssertEqual(actor.position.x, 5)
        XCTAssertEqual(log.drawnPositions.count, 2)
        driver.paused = false; driver.step(0.5)
        XCTAssertEqual(actor.position.x, 10)
        scheduler.unscheduleAll(target: listener)
        context.setBackend(MRRenderBackend())
    }
    func testWarmupIntervalsPauseAndElapsedDelivery() {
        let scheduler = MRScheduler(), target = ClockTarget()
        var deltas: [Float] = []
        target.handler = { deltas.append($0) }
        scheduler.schedule(#selector(ClockTarget.timer(_:)),target: target,interval: 0.1,paused: false)
        scheduler.tick(0.2)
        XCTAssertTrue(deltas.isEmpty)
        scheduler.tick(0.06); scheduler.tick(0.06)
        XCTAssertEqual(deltas.count, 1)
        XCTAssertEqual(deltas[0], 0.12,accuracy: 0.00001)
        scheduler.tick(0.3)
        XCTAssertEqual(deltas.count, 2, "An overrun delivers one accumulated delta, without catch-up callbacks")
        XCTAssertEqual(deltas[1], 0.3,accuracy: 0.00001)
        scheduler.pause(target: target); scheduler.tick(2)
        XCTAssertEqual(deltas.count, 2)
        scheduler.resume(target: target); scheduler.tick(0.11)
        XCTAssertEqual(deltas.count, 3)
        XCTAssertEqual(deltas[2], 0.11,accuracy: 0.00001)
    }
    func testStablePriorityAndCancellationDuringUpdate() {
        let scheduler = MRScheduler()
        var order: [String] = []
        let first = ClockTarget(), second = ClockTarget(), early = ClockTarget(), cancelled = ClockTarget()
        first.handler = { _ in order.append("first"); scheduler.unscheduleAll(target: cancelled) }
        second.handler = { _ in order.append("second") }
        early.handler = { _ in order.append("early") }
        cancelled.handler = { _ in order.append("cancelled") }
        scheduler.scheduleUpdate(target: first,priority: 0,paused: false)
        scheduler.scheduleUpdate(target: second,priority: 0,paused: false)
        scheduler.scheduleUpdate(target: early,priority: -1,paused: false)
        scheduler.scheduleUpdate(target: cancelled,priority: 1,paused: false)
        scheduler.tick(0.1)
        XCTAssertEqual(order, ["early","first","second"])
        scheduler.unscheduleAll(target: first)
        scheduler.unscheduleAll(target: second)
        scheduler.unscheduleAll(target: early)
    }
    func testDelayedRepeatAndReplacementTimerSurvivesCancellation() {
        let scheduler = MRScheduler(), target = ClockTarget()
        var deltas: [Float] = []
        target.handler = { deltas.append($0) }
        scheduler.schedule(#selector(ClockTarget.timer(_:)),target: target,interval: 0.1,repeat: 1,delay: 0.2,paused: false)
        scheduler.tick(0); scheduler.tick(0.25); scheduler.tick(0.06); scheduler.tick(1)
        XCTAssertEqual(deltas.count, 2)
        XCTAssertEqual(deltas[0], 0.25,accuracy: 0.00001)
        XCTAssertEqual(deltas[1], 0.11,accuracy: 0.00001)
        var calls = 0
        target.handler = { _ in
            calls += 1
            if calls == 1 {
                scheduler.unschedule(#selector(ClockTarget.timer(_:)),target: target)
                scheduler.schedule(#selector(ClockTarget.timer(_:)),target: target,interval: 0,paused: false)
            }
        }
        scheduler.schedule(#selector(ClockTarget.timer(_:)),target: target,interval: 0,repeat: 0,delay: 0,paused: false)
        scheduler.tick(0); scheduler.tick(0.1)
        XCTAssertEqual(calls, 1)
        scheduler.tick(0.1) // replacement timer warms up
        scheduler.tick(0.1)
        XCTAssertEqual(calls, 2)
        scheduler.unscheduleAll(target: target)
    }
}
