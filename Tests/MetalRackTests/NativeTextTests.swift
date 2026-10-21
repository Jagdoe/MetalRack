import XCTest
import CoreText
import MetalKit
import MetalRack
import MetalRackScene

final class NativeTextTests: XCTestCase {
    private func fixture(_ context: MRRenderContext) throws -> (MRTextAtlas, CTFont) {
        let font = CTFontCreateWithName("Georgia" as CFString,32,nil)
        let graphics = CTFontCopyGraphicsFont(font,nil)
        let pixels = [UInt8](repeating: 255,count: 4*6*4)
        let texture = try XCTUnwrap(pixels.withUnsafeBytes { MRTexture(context: context,width: 4,height: 6,rgba: $0.baseAddress!) })
        let frame = try XCTUnwrap(MRSpriteFrame(texture: texture,pixelRect: CGRect(x: 0,y: 0,width: 4,height: 6),
            originalSize: CGSize(width: 4,height: 6),trimOffset: .zero,pixelsPerPoint: 1,rotated: false))
        var glyphs: [NSNumber: MRTextGlyph] = [:]
        for character in "AVB".utf16 {
            var character = character, glyph: CGGlyph = 0
            XCTAssertTrue(CTFontGetGlyphsForCharacters(font,&character,&glyph,1))
            glyphs[NSNumber(value: glyph)] = MRTextGlyph(frame: frame,origin: CGPoint(x: -2,y: -2))
        }
        return (MRTextAtlas(font: graphics,referenceEm: 32,glyphs: glyphs),font)
    }
    func testShapedAdvancesBearingsAndTrailingSpace() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        defer { withExtendedLifetime(renderer) {} }
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let (atlas,font) = try fixture(context)
        let label = MRText(atlas: atlas,text: "AV",fontSize: 32)
        label.horizontalInset = 1.6
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "AV",attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTLigatureAttributeName as String): 0]))
        let run = try XCTUnwrap((CTLineGetGlyphRuns(line) as? [CTRun])?.first)
        var positions = [CGPoint](repeating: .zero,count: 2)
        CTRunGetPositions(run,CFRange(location: 0,length: 2),&positions)
        XCTAssertEqual(label.children.count,2)
        XCTAssertEqual(label.children[1].position.x-label.children[0].position.x,positions[1].x-positions[0].x,accuracy: 0.00001)
        XCTAssertEqual(label.children[0].position.x,0,accuracy: 0.00001,"Negative glyph bearing is normalized into the container")
        let expected = CTLineGetTypographicBounds(line,nil,nil,nil)+3.2+0.4
        XCTAssertEqual(label.contentSize.width,expected,accuracy: 0.00001)
        XCTAssertTrue(CGRect(origin: .zero,size: label.contentSize).insetBy(dx: -0.001,dy: -0.001).contains(label.inkBounds))
        let width = label.contentSize.width
        label.text = "AV "
        XCTAssertGreaterThan(label.contentSize.width,width)
        XCTAssertEqual(label.children.count,2,"Space has advance without a painted glyph")
        XCTAssertEqual(renderer.textures.count,1)
    }
    func testWrapExplicitReturnsEmptyTextAndOwnedChildren() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        defer { withExtendedLifetime(renderer) {} }
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let (atlas,_) = try fixture(context)
        let label = MRText(atlas: atlas,text: "A\nB\n",fontSize: 16)
        label.maximumWidth = 80; label.centered = true
        XCTAssertEqual(label.lineCount,3)
        XCTAssertEqual(label.contentSize.width,80)
        XCTAssertEqual(label.children[0].position.y-label.children[1].position.y,19.2,accuracy: 0.00001)
        label.lineSpacing = 25
        XCTAssertEqual(label.children[0].position.y-label.children[1].position.y,25,accuracy: 0.00001)
        let decoration = MRNode(); label.addChild(decoration)
        label.text = "AV AV AV AV"; label.maximumWidth = 30
        XCTAssertGreaterThan(label.lineCount,1)
        XCTAssertTrue(decoration.parent === label)
        label.text = ""
        XCTAssertEqual(label.lineCount,1)
        XCTAssertEqual(label.children.count,1)
        XCTAssertTrue(label.inkBounds.isNull)
        XCTAssertEqual(label.contentSize.height,16)
        XCTAssertEqual(renderer.textures.count,1,"Updating counters must reuse the painted glyph atlas")
    }
    func testTintFadeAndRebuildReachNativeMetalPixels() throws {
        let renderer = try SceneRenderer(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        defer { withExtendedLifetime(renderer) {} }
        let context = MRRenderContext(); renderer.attachNativeContext(context)
        let (atlas,_) = try fixture(context)
        let label = MRText(atlas: atlas,text: "A",fontSize: 32)
        label.color = MRColor3B(r: 255,g: 0,b: 0)
        let fade = try XCTUnwrap(MRFadeTo(duration: 1,opacity: 128))
        _ = label.run(fade); label.advanceTime(0); label.advanceTime(1)
        XCTAssertEqual(label.opacity,128)
        label.text = "B"
        let glyph = try XCTUnwrap(label.children.first as? MRSprite)
        XCTAssertEqual(glyph.opacity,128); XCTAssertEqual(glyph.color.r,255); XCTAssertEqual(glyph.color.g,0)
        var rgba = [UInt8](repeating: 0,count: 64*64*4)
        let target = try XCTUnwrap(rgba.withUnsafeBytes { MRTexture(context: context,width: 64,height: 64,rgba: $0.baseAddress!) })
        context.beginFrame(with: CGSize(width: 64,height: 64))
        context.beginTarget(target.identifier,size: CGSize(width: 64,height: 64),clear: true,color: MRRenderColor(r: 0,g: 0,b: 0,a: 0))
        label.visit(context); context.endTarget()
        rgba.withUnsafeMutableBytes { context.readTexture(target.identifier,rect: CGRect(x: 0,y: 0,width: 64,height: 64),rgba: $0.baseAddress!) }
        let nonempty = stride(from: 0,to: rgba.count,by: 4).filter { rgba[$0+3]>0 }
        XCTAssertFalse(nonempty.isEmpty)
        XCTAssertTrue(nonempty.contains { rgba[$0] == 128 && rgba[$0+3] == 128 })
        XCTAssertTrue(nonempty.allSatisfy { rgba[$0+1] == 0 && rgba[$0+2] == 0 && rgba[$0] == rgba[$0+3] })
    }
}
