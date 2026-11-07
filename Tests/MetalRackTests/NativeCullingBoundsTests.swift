import XCTest
import MetalRackScene

private final class CullingPaintNode: MRNode {
    var paint = CGRect.null
    override var localDrawBounds: CGRect { paint }
}

final class NativeCullingBoundsTests: XCTestCase {
    private func bounds(_ node: MRNode) -> CGRect {
        node.paintedBounds.applying(node.nodeToWorldTransform)
    }
    func testChildOutsideParentAndNonSpriteGroupAreIncluded() {
        let tower = CullingPaintNode(); tower.paint = CGRect(x: 0, y: 0, width: 20, height: 80)
        tower.position = CGPoint(x: -60, y: 0)
        let group = MRNode(); tower.addChild(group)
        let sails = CullingPaintNode(); sails.paint = CGRect(x: 0, y: 0, width: 140, height: 140)
        sails.contentSize = sails.paint.size
        sails.anchorPoint = CGPoint(x: 0.5, y: 0.5); sails.position = CGPoint(x: 10, y: 70)
        group.addChild(sails)
        XCTAssertEqual(bounds(tower), CGRect(x: -120, y: 0, width: 140, height: 140))
        XCTAssertTrue(bounds(tower).intersects(CGRect(x: 0, y: 0, width: 100, height: 100)))
    }
    func testTrimmedPaintOutsideLogicalCanvasAndHiddenStatesAreConservative() {
        let root = MRNode(); XCTAssertTrue(root.paintedBounds.isNull)
        let child = CullingPaintNode(); root.addChild(child)
        child.contentSize = CGSize(width: 20, height: 80)
        child.paint = CGRect(x: -3, y: -5, width: 26, height: 90)
        XCTAssertEqual(bounds(root), child.paint)
        child.visible = false
        XCTAssertEqual(bounds(root), child.paint) // Temporary state cannot shrink painted geometry.
        root.removeChild(child)
        XCTAssertTrue(root.paintedBounds.isNull)
    }
    func testAnimatedChildTransformsAndReparentingStayCurrent() {
        let root = MRNode(), child = CullingPaintNode(), other = MRNode()
        root.addChild(child); child.paint = CGRect(x: 0, y: 0, width: 20, height: 10)
        XCTAssertEqual(bounds(root), child.paint)
        child.position = CGPoint(x: 50, y: 30); child.rotation = 90
        let rotated = bounds(root)
        XCTAssertEqual(rotated.minX, 50, accuracy: 0.001)
        XCTAssertEqual(rotated.minY, 10, accuracy: 0.001)
        XCTAssertEqual(rotated.width, 10, accuracy: 0.001)
        XCTAssertEqual(rotated.height, 20, accuracy: 0.001)
        child.removeFromParent(); other.addChild(child)
        XCTAssertTrue(root.paintedBounds.isNull)
        XCTAssertEqual(bounds(other), rotated)
    }
    func testAncestorScaleMirroringAndChildRotationUseWorldCoordinates() {
        let camera = MRNode(), root = MRNode(), child = CullingPaintNode()
        camera.position = CGPoint(x: 120, y: 50); camera.scale = 2
        root.position = CGPoint(x: 30, y: 40); root.scaleX = -1
        camera.addChild(root); root.addChild(child)
        child.position = CGPoint(x: 12, y: 8); child.rotation = 35
        child.paint = CGRect(x: -3, y: -2, width: 30, height: 20)
        child.contentSize = child.paint.size; child.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let expected = child.paint.applying(child.nodeToWorldTransform)
        let actual = bounds(root)
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.001)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.001)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.001)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.001)
    }
}
