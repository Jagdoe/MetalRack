import XCTest
import MetalRackScene

private final class CustomClockNode: MRNode {
    var ticks = 0
    override func advanceTime(_ seconds: Float) { ticks += 1; super.advanceTime(seconds) }
}
final class ActionTraversalTests: XCTestCase {
    func testDormantTreeBenchmark() {
        let root = MRNode()
        for _ in 0..<100 { let branch = MRNode(); root.addChild(branch); for _ in 0..<100 { branch.addChild(MRNode()) } }
        let actor = MRNode(); root.addChild(actor)
        actor.run(MRRepeatForever(action: MRMoveBy(duration: 1, position: CGPoint(x: 1, y: 0))))
        let start = Date.timeIntervalSinceReferenceDate
        for _ in 0..<600 { root.advanceTime(1/60) }
        print("ACTION_TRAVERSAL_BENCH 10000 dormant, 1 active, 600 frames: \((Date.timeIntervalSinceReferenceDate-start)*1000) ms")
        XCTAssertGreaterThan(actor.position.x, 0)
    }
    func testLaterDormantSiblingActivatedInSameTick() {
        let root=MRNode(), first=MRNode(), later=CustomClockNode()
        let leaf=MRNode(); later.addChild(leaf); root.addChild(first); root.addChild(later)
        first.run(MRSequence(one: MRDelayTime(duration: 0.1),two: MRCallBlock(block: { leaf.run(MRMoveBy(duration: 1,position: CGPoint(x: 10,y: 0))) })))
        root.advanceTime(0); root.advanceTime(0.1); root.advanceTime(0.5)
        XCTAssertEqual(leaf.position.x,5,accuracy:0.001)
        XCTAssertEqual(later.ticks,3)
    }
    func testDormantSiblingWithoutOverrideActivatedInSameTick() {
        let root=MRNode(), first=MRNode(), later=MRNode(), leaf=MRNode()
        later.addChild(leaf);root.addChild(first);root.addChild(later)
        first.run(MRSequence(one: MRDelayTime(duration:0.1),two: MRCallBlock(block: { leaf.run(MRMoveBy(duration:1,position:CGPoint(x:10,y:0))) })))
        root.advanceTime(0);root.advanceTime(0.1);root.advanceTime(0.5)
        XCTAssertEqual(leaf.position.x,5,accuracy:0.001)
    }
    func testReparentStopRestartAndPausedAncestor() {
        let root=MRNode(), left=MRNode(), right=MRNode(), actor=MRNode()
        root.addChild(left);root.addChild(right);left.addChild(actor)
        let action=MRMoveBy(duration:1,position:CGPoint(x:10,y:0))!
        actor.run(action);root.advanceTime(0);root.advanceTime(0.25)
        left.removeChild(actor);right.addChild(actor);right.actionsPaused=true
        root.advanceTime(0.25)
        XCTAssertEqual(actor.position.x,5,accuracy:0.001,"Pausing own actions must not pause descendants")
        actor.stopAllActions();root.advanceTime(1)
        XCTAssertEqual(actor.position.x,5,accuracy:0.001)
        actor.run(MRMoveBy(duration:1,position:CGPoint(x:4,y:0)));root.advanceTime(0);root.advanceTime(0.5)
        XCTAssertEqual(actor.position.x,7,accuracy:0.001)
        actor.stopAllActions();actor.removeFromParent();root.advanceTime(0.5)
    }
    func testCustomClockRunsWithoutActionsAndSurvivesReparenting() {
        let root=MRNode(), branch=MRNode(), custom=CustomClockNode()
        root.addChild(branch);branch.addChild(custom);root.advanceTime(0.1)
        XCTAssertEqual(custom.ticks,1)
        custom.removeFromParent();root.advanceTime(0.1);XCTAssertEqual(custom.ticks,1)
        root.addChild(custom);root.advanceTime(0.1);XCTAssertEqual(custom.ticks,2)
    }
    func testCallbackRemovesAndAddsChildrenWithOriginalSnapshotSemantics() {
        let root=MRNode(), actor=MRNode(), later=CustomClockNode(), added=CustomClockNode()
        root.addChild(actor);root.addChild(later)
        actor.run(MRSequence(one: MRDelayTime(duration:0.1),two: MRCallBlock(block: { later.removeFromParent(); root.addChild(added) })))
        root.advanceTime(0);XCTAssertEqual(later.ticks,1)
        root.advanceTime(0.1)
        XCTAssertEqual(later.ticks,1);XCTAssertEqual(added.ticks,0)
        root.advanceTime(0);XCTAssertEqual(added.ticks,1)
    }
    func testSceneRootAdoptionAndPromotionRetainActiveDescendant() {
        let scheduler=MRScheduler()
        let driver=MRSceneDriver(context:MRRenderContext(),scheduler:scheduler)
        driver.logicalSize=CGSize(width:100,height:100)
        let old=MRNode(), actor=MRNode(), wrapper=MRNode()
        old.addChild(actor);driver.scene=old
        actor.run(MRMoveBy(duration:1,position:CGPoint(x:10,y:0)))
        scheduler.tick(0);scheduler.tick(0.25)
        wrapper.addChild(old);driver.scene=wrapper;scheduler.tick(0.25)
        XCTAssertEqual(actor.position.x,5,accuracy:0.001)
        driver.scene=old;scheduler.tick(0.25)
        XCTAssertNil(old.parent);XCTAssertEqual(actor.position.x,7.5,accuracy:0.001)
        scheduler.tick(0.25);XCTAssertEqual(actor.position.x,10,accuracy:0.001)
    }

}
