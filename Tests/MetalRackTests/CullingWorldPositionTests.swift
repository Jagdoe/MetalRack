#if os(iOS)
import XCTest
import MetalRackScene
import MetalRackUI

private final class PositionCountingSprite: MRDefinitionSprite {
    var refreshes = 0
    var refreshedPosition = CGPoint.zero
    override var localDrawBounds: CGRect { CGRect(x: 0, y: 0, width: 16, height: 16) }
    override func updateWorldPositionCache() {
        refreshes += 1
        super.updateWorldPositionCache()
        refreshedPosition = getWorldPosition()
    }
}

final class CullingWorldPositionTests: XCTestCase {
    func testOnePositionRefreshPerVisitIncludingOffscreenAndNestedSprites() {
        let layer = MRCullLayer(), child = PositionCountingSprite()
        let nested = PositionCountingSprite()
        child.addChild(nested)
        layer.addChild(child)
        let context = MRRenderContext()
        for position in [CGPoint.zero, CGPoint(x: 100000, y: 100000)] {
            child.position = position
            child.refreshes = 0; nested.refreshes = 0
            layer.visit(context)
            XCTAssertEqual(child.refreshes, 1)
            XCTAssertEqual(child.refreshedPosition, child.getWorldPosition())
            XCTAssertEqual(nested.refreshes, position == .zero ? 1 : 0)
        }
        child.remove(fromParentAndCleanup: false)
        child.position = .zero; child.refreshes = 0
        child.visit(context)
        XCTAssertEqual(child.refreshes, 1)
    }
}
#endif
