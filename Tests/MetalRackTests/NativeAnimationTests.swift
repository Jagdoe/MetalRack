import XCTest
import MetalKit
import MetalRack
import MetalRackScene

final class NativeAnimationTests: XCTestCase {
    private func fixture() throws -> (renderer: SceneRenderer, frames: [MRSpriteFrame], sprite: MRSprite) {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let pixels: [UInt8] = [255,255,255,255, 255,0,0,255, 0,255,0,255, 0,0,255,255]
        let texture = pixels.withUnsafeBytes { MRTexture(context: context,width: 4,height: 1,rgba: $0.baseAddress!)! }
        let frames = (0..<4).map { index in
            MRSpriteFrame(texture: texture,pixelRect: CGRect(x: index,y: 0,width: 1,height: 1),
                originalSize: CGSize(width: 1,height: 1),trimOffset: .zero,pixelsPerPoint: 1,rotated: false)!
        }
        return (renderer,frames,MRSprite(frame: frames[0])!)
    }
    func testFirstTickAndLongFrameRetainEffectCadence() throws {
        let f = try fixture(); defer { withExtendedLifetime(f) {} }
        let animation = MRAnimation(frames: Array(f.frames.dropFirst()),delay: 0.1)
        let action = MRAnimate(animation: animation)
        f.sprite.run(action)
        XCTAssertTrue(f.sprite.frame === f.frames[0])
        f.sprite.advanceTime(0)
        XCTAssertTrue(f.sprite.frame === f.frames[1])
        f.sprite.advanceTime(0.25)
        XCTAssertTrue(f.sprite.frame === f.frames[2], "A long frame must not skip the next effect image")
        f.sprite.advanceTime(0.01)
        XCTAssertTrue(f.sprite.frame === f.frames[3])
        f.sprite.advanceTime(0.1)
        XCTAssertEqual(f.sprite.numberOfRunningActions, 0)
        XCTAssertTrue(f.sprite.frame === f.frames[3])
    }
    func testRestorationOnCancellationCompletionAndReuse() throws {
        let f = try fixture(); defer { withExtendedLifetime(f) {} }
        let animation = MRAnimation(frames: [f.frames[1],f.frames[2]],delay: 0.1)
        animation.restoreOriginalFrame = true
        let action = MRAnimate(animation: animation)
        f.sprite.run(action); f.sprite.advanceTime(0); f.sprite.advanceTime(0.11)
        XCTAssertTrue(f.sprite.frame === f.frames[2])
        f.sprite.stopAllActions()
        XCTAssertTrue(f.sprite.frame === f.frames[0])
        XCTAssertNil(action.target)
        f.sprite.frame = f.frames[3]
        f.sprite.run(action); f.sprite.advanceTime(0); f.sprite.advanceTime(0.11); f.sprite.advanceTime(0.11)
        XCTAssertEqual(f.sprite.numberOfRunningActions, 0)
        XCTAssertTrue(f.sprite.frame === f.frames[3], "A restarted action must capture the new original frame")
    }
    func testDelayUnitsAndFrameNotifications() throws {
        let f = try fixture(); defer { withExtendedLifetime(f) {} }
        let frames = [1.0,3.0,2.0].enumerated().map { index, units in
            MRAnimationFrame(spriteFrame: f.frames[index+1],delayUnits: Float(units),userInfo: ["step": index+1])
        }
        let animation = MRAnimation(frames: frames,delayPerUnit: 0.1)
        XCTAssertEqual(animation.totalDelayUnits, 6)
        XCTAssertEqual(animation.duration, 0.6,accuracy: 0.00001)
        let notice = expectation(description: "Each newly displayed frame notifies once")
        notice.expectedFulfillmentCount = 3
        let observer = NotificationCenter.default.addObserver(forName: .MRAnimationFrameDisplayed,object: f.sprite,queue: nil) { notification in
            XCTAssertTrue(notification.object is MRSprite)
            XCTAssertTrue((1...3).contains((notification.userInfo?["step"] as? Int) ?? 0))
            notice.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        f.sprite.run(MRAnimate(animation: animation))
        f.sprite.advanceTime(0); f.sprite.advanceTime(0.11)
        XCTAssertTrue(f.sprite.frame === f.frames[2])
        f.sprite.advanceTime(0.2)
        XCTAssertTrue(f.sprite.frame === f.frames[2])
        f.sprite.advanceTime(0.1)
        XCTAssertTrue(f.sprite.frame === f.frames[3])
        f.sprite.advanceTime(0.2)
        wait(for: [notice],timeout: 0.1)
    }
    func testCopiesAndReversePreserveExplicitDurationAndFrameOrder() throws {
        let f = try fixture(); defer { withExtendedLifetime(f) {} }
        let animation = MRAnimation(frames: Array(f.frames.dropFirst()),delay: 0.1)
        let action = MRAnimate(duration: 0.6,animation: animation,restoreOriginalFrame: false)
        let copy = try XCTUnwrap(action.copy() as? MRAnimate)
        let reverse = try XCTUnwrap(action.reverse() as? MRAnimate)
        XCTAssertTrue(copy.animation === animation)
        XCTAssertEqual(copy.duration, action.duration)
        XCTAssertEqual(reverse.duration, action.duration)
        XCTAssertTrue(reverse.animation.frames.first?.spriteFrame === f.frames[3])
        XCTAssertTrue(reverse.animation.frames.last?.spriteFrame === f.frames[1])
        f.sprite.run(reverse); f.sprite.advanceTime(0)
        XCTAssertTrue(f.sprite.frame === f.frames[3])
        f.sprite.advanceTime(0.21)
        XCTAssertTrue(f.sprite.frame === f.frames[2])
        f.sprite.advanceTime(0.2)
        XCTAssertTrue(f.sprite.frame === f.frames[1])
        f.sprite.advanceTime(0.2)
        XCTAssertEqual(f.sprite.numberOfRunningActions, 0)
    }
}
