import XCTest
import MetalRackScene

final class NativeActionTests: XCTestCase {
    func testRotateToStartsFromCurrentTargetAngleIncludingReuse() {
        let action = MRRotateTo(duration: 1, angle: 40)!
        let first = MRNode(); first.rotation = 25
        first.run(action); first.advanceTime(0)
        XCTAssertEqual(first.rotation, 25, accuracy: 0.0001)
        first.advanceTime(0.5)
        XCTAssertEqual(first.rotation, 32.5, accuracy: 0.0001)
        first.stopAllActions()
        let second = MRNode(); second.rotation = -30
        second.run(action); second.advanceTime(0)
        XCTAssertEqual(second.rotation, -30, accuracy: 0.0001)
        second.advanceTime(0.5)
        XCTAssertEqual(second.rotation, 5, accuracy: 0.0001)
    }

    func testIntervalFirstTickPauseAndSequenceBoundaries() throws {
        let root = MRNode(), actor = MRNode()
        root.addChild(actor)
        let horizontal = MRMoveBy(duration: 0.5,position: CGPoint(x: 10,y: 0))!
        let vertical = MRMoveBy(duration: 0.5,position: CGPoint(x: 0,y: 10))!
        let sequence = MRSequence(one: horizontal,two: vertical)!
        sequence.tag = 42
        actor.run(sequence)
        root.advanceTime(0.25) // Existing action contract: initial tick samples t=0.
        XCTAssertEqual(actor.position, .zero)
        actor.actionsPaused = true
        root.advanceTime(2)
        XCTAssertEqual(actor.position, .zero)
        actor.actionsPaused = false
        root.advanceTime(0.5)
        XCTAssertEqual(actor.position.x, 10, accuracy: 0.00001)
        XCTAssertEqual(actor.position.y, 0, accuracy: 0.00001)
        root.advanceTime(0.25)
        XCTAssertEqual(actor.position.y, 5, accuracy: 0.00001)
        root.advanceTime(0.25)
        XCTAssertEqual(actor.position, CGPoint(x: 10,y: 10))
        XCTAssertEqual(actor.numberOfRunningActions, 0)
        XCTAssertNil(actor.action(byTag: 42))
        XCTAssertNil(sequence.target)
    }

    func testCallbackCanCancelAndReplaceActionsDuringTick() {
        let actor = MRNode()
        let cancelled = MRMoveBy(duration: 2,position: CGPoint(x: 100,y: 0))!
        let replacement = MRMoveBy(duration: 1,position: CGPoint(x: 4,y: 0))!
        let callback = MRCallBlock(block: {
            actor.stopAllActions()
            actor.run(replacement)
        })!
        actor.run(MRSequence(one: MRDelayTime(duration: 0.1),two: callback))
        actor.run(cancelled)
        actor.advanceTime(0.1)
        actor.advanceTime(0.1)
        XCTAssertEqual(actor.position, .zero)
        XCTAssertEqual(actor.numberOfRunningActions, 1)
        XCTAssertNil(cancelled.target)
        actor.advanceTime(0.5)
        XCTAssertEqual(actor.position, .zero)
        actor.advanceTime(0.5)
        XCTAssertEqual(actor.position.x, 2, accuracy: 0.00001)
        actor.advanceTime(0.5)
        XCTAssertEqual(actor.position.x, 4, accuracy: 0.00001)
        XCTAssertEqual(actor.numberOfRunningActions, 0)
    }
    func testEasingReverseTimeAndActionOwnership() {
        let actor = MRNode()
        let eased = MREaseIn(action: MRMoveBy(duration: 1,position: CGPoint(x: 10,y: 0)),rate: 2)!
        actor.run(eased)
        actor.advanceTime(0); actor.advanceTime(0.5)
        XCTAssertEqual(actor.position.x, 2.5,accuracy: 0.00001)
        actor.stopAllActions()
        actor.position = .zero
        actor.run(MRReverseTime(action: MRMoveBy(duration: 1,position: CGPoint(x: 10,y: 0))))
        actor.advanceTime(0)
        XCTAssertEqual(actor.position.x, 10,accuracy: 0.00001)
        actor.advanceTime(0.5)
        XCTAssertEqual(actor.position.x, 5,accuracy: 0.00001)
        actor.advanceTime(0.5)
        XCTAssertEqual(actor.position.x, 0,accuracy: 0.00001)
        weak var released: MRNode?
        autoreleasepool {
            let temporary = MRNode()
            released = temporary
            temporary.run(MRRepeatForever(action: MRMoveBy(duration: 1,position: CGPoint(x: 1,y: 0))))
        }
        XCTAssertNil(released, "Actions must not retain their owning node")
    }

    func testRepeatForeverConsumesEveryCompletedCycleAndRemainder() {
        let actor = MRNode()
        let repeatAction = MRRepeatForever(action: MRMoveBy(duration: 1, position: CGPoint(x: 10, y: 0)))!
        actor.run(repeatAction)
        actor.advanceTime(0)
        actor.advanceTime(3.25)
        XCTAssertEqual(actor.position.x, 32.5, accuracy: 0.0001)
        XCTAssertEqual(repeatAction.innerAction.elapsed, 0.25, accuracy: 0.0001)
        actor.advanceTime(0.1)
        XCTAssertEqual(actor.position.x, 33.5, accuracy: 0.0001)
    }

    func testOscillatingLimbMovesImmediatelyAfterLargeCatchupSteps() {
        let limb = MRNode()
        let cycle = MRSequence(one: MRRotateBy(duration: 0.2, angle: 30),
                               two: MRRotateBy(duration: 0.2, angle: -30))!
        let repeatAction = MRRepeatForever(action: cycle)!
        limb.run(repeatAction)
        limb.advanceTime(0)
        limb.advanceTime(20)
        limb.advanceTime(20)
        XCTAssertLessThan(repeatAction.innerAction.elapsed, cycle.duration)
        let before = limb.rotation
        limb.advanceTime(0.04)
        XCTAssertGreaterThan(abs(limb.rotation - before), 1)
    }

    func testRepeatCatchupHonorsCancellationFromInnerCallback() {
        let actor = MRNode()
        var completions = 0
        let callback = MRCallBlock(block: {
            completions += 1
            if completions == 2 { actor.stopAllActions() }
        })!
        actor.run(MRRepeatForever(action: MRSequence(one: MRDelayTime(duration: 0.1), two: callback)))
        actor.advanceTime(0)
        actor.advanceTime(10)
        XCTAssertEqual(completions, 2)
        XCTAssertEqual(actor.numberOfRunningActions, 0)
    }

    func testZeroDurationRepeatRemainsBounded() {
        let actor = MRNode()
        actor.run(MRRepeatForever(action: MRDelayTime(duration: 0)))
        actor.advanceTime(0)
        actor.advanceTime(10)
        XCTAssertEqual(actor.numberOfRunningActions, 1)
    }

}
