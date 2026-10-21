import XCTest
import MetalRackScene

private final class PointerReceiver: NSObject, MRPointerReceiver {
    let name: String
    var record: ((String) -> Void)?
    var begin: ((MRPointerEvent) -> Bool)?
    var moved: ((MRPointerEvent) -> Void)?
    var ended: ((MRPointerEvent) -> Void)?
    var cancelled: ((MRPointerEvent) -> Void)?
    init(_ name: String) { self.name = name }
    func pointerBegan(_ event: MRPointerEvent) -> Bool { record?("\(name):begin:\(event.identifier)"); return begin?(event) ?? true }
    func pointerMoved(_ event: MRPointerEvent) { record?("\(name):move:\(event.identifier)"); moved?(event) }
    func pointerEnded(_ event: MRPointerEvent) { record?("\(name):end:\(event.identifier)"); ended?(event) }
    func pointerCancelled(_ event: MRPointerEvent) { record?("\(name):cancel:\(event.identifier)"); cancelled?(event) }
}
final class NativeInputTests: XCTestCase {
    private func event(_ id: UInt, x: CGFloat = 10) -> MRPointerEvent {
        MRPointerEvent(identifier: id,position: CGPoint(x: x,y: 20),previousPosition: CGPoint(x: x-1,y: 19),timestamp: 1)
    }
    func testPriorityStableTiesClaimsAndSwallowing() {
        let input = MRInput(), a = PointerReceiver("a"), b = PointerReceiver("b"), c = PointerReceiver("c"), d = PointerReceiver("d")
        var events: [String] = []
        for receiver in [a,b,c,d] { receiver.record = { events.append($0) } }
        a.begin = { _ in false }
        input.add(receiver: d,priority: 10,swallows: false)
        input.add(receiver: a,priority: -5,swallows: true)
        input.add(receiver: b,priority: -5,swallows: false)
        input.add(receiver: c,priority: -5,swallows: true)
        input.begin(event(1)); input.move(event(1,x: 30)); input.end(event(1,x: 31))
        XCTAssertEqual(events,["a:begin:1","b:begin:1","c:begin:1","b:move:1","c:move:1","b:end:1","c:end:1"])
        input.end(event(1)); input.move(event(1))
        XCTAssertEqual(events.count,7,"Terminal samples retire captures")
    }
    func testIndependentPointersCancellationAndFocusLoss() {
        let input = MRInput(), receiver = PointerReceiver("r")
        var events: [String] = []
        receiver.record = { events.append($0) }
        input.add(receiver: receiver,priority: 0,swallows: true)
        input.begin(event(1)); input.begin(event(2)); input.cancel(event(1)); input.move(event(2)); input.end(event(2))
        XCTAssertEqual(events,["r:begin:1","r:begin:2","r:cancel:1","r:move:2","r:end:2"])
        input.begin(event(3)); input.isEnabled = false
        XCTAssertEqual(events.suffix(2),["r:begin:3","r:cancel:3"])
        let count = events.count
        input.begin(event(4)); input.move(event(3)); input.end(event(3))
        XCTAssertEqual(events.count,count)
        input.isEnabled = true; input.begin(event(4)); input.cancelAllPointers()
        XCTAssertEqual(events.suffix(2),["r:begin:4","r:cancel:4"])
    }
    func testMutationInsideCallbacksCancelsOnceAndDefersNewRegistrations() {
        let input = MRInput(), first = PointerReceiver("first"), next = PointerReceiver("next")
        var events: [String] = []
        first.record = { events.append($0) }; next.record = first.record
        first.begin = { _ in
            input.remove(receiver: first)
            input.add(receiver: next,priority: 0,swallows: true)
            return true
        }
        input.add(receiver: first,priority: 0,swallows: true)
        input.begin(event(1)); input.end(event(1))
        XCTAssertEqual(events,["first:begin:1","first:cancel:1"])
        input.begin(event(2))
        next.moved = { _ in input.remove(receiver: next) }
        input.move(event(2)); input.end(event(2))
        XCTAssertEqual(events.suffix(3),["next:begin:2","next:move:2","next:cancel:2"])
        input.add(receiver: next,priority: 0,swallows: true)
        next.begin = { _ in input.isEnabled = false; return true }
        input.begin(event(3))
        XCTAssertEqual(events.suffix(2),["next:begin:3","next:cancel:3"])
    }
    func testCoordinatesAndWeakReceiverOwnership() {
        let root = MRNode(); root.position = CGPoint(x: 10,y: 20); root.scaleX = 2; root.scaleY = 3
        let child = MRNode(); child.position = CGPoint(x: 4,y: 5); root.addChild(child)
        let current = child.convert(toWorldSpace: CGPoint(x: 2,y: 3))
        let previous = child.convert(toWorldSpace: CGPoint(x: 1,y: 2))
        let sample = MRPointerEvent(identifier: 1,position: current,previousPosition: previous,timestamp: 10)
        XCTAssertEqual(sample.location(in: child),CGPoint(x: 2,y: 3))
        XCTAssertEqual(sample.previousLocation(in: child),CGPoint(x: 1,y: 2))
        let input = MRInput()
        weak var weakReceiver: PointerReceiver?
        autoreleasepool {
            let receiver = PointerReceiver("r"); weakReceiver = receiver
            input.add(receiver: receiver,priority: 0,swallows: true)
            input.begin(event(1))
        }
        XCTAssertNil(weakReceiver,"Input must not retain an unloaded scene through a receiver")
        input.move(event(1)); input.end(event(1)); input.begin(event(2))
    }
}
