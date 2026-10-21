#import "MRText.h"

@implementation MRTextGlyph
- (instancetype)initWithFrame:(MRSpriteFrame *)frame origin:(CGPoint)origin {
    NSParameterAssert(frame && isfinite(origin.x) && isfinite(origin.y));
    if ((self=[super init])) { _frame=frame; _origin=origin; }
    return self;
}
@end

@implementation MRTextAtlas {
    CGFontRef _font;
}
- (instancetype)initWithFont:(CGFontRef)font referenceEm:(CGFloat)em
                     glyphs:(NSDictionary<NSNumber *,MRTextGlyph *> *)glyphs {
    NSParameterAssert(font && isfinite(em) && em>0 && glyphs);
    if ((self=[super init])) { _font=CGFontRetain(font); _referenceEm=em; _glyphs=[glyphs copy]; }
    return self;
}
- (void)dealloc { CGFontRelease(_font); }
- (CTFontRef)createFontAtSize:(CGFloat)size {
    NSParameterAssert(isfinite(size) && size>0);
    return CTFontCreateWithGraphicsFont(_font,size,NULL,NULL);
}
@end

@implementation MRText {
    NSMutableArray<MRSprite *> *_glyphSprites;
}
- (instancetype)initWithAtlas:(MRTextAtlas *)atlas text:(NSString *)text fontSize:(CGFloat)size {
    NSParameterAssert(atlas && text && isfinite(size) && size>0);
    if ((self=[super init])) {
        _atlas=atlas; _text=[text copy]; _fontSize=size;
        _color=(MRColor3B){255,255,255}; _opacity=255;
        _glyphSprites=[NSMutableArray array];
        [self layoutText];
    }
    return self;
}
- (void)setText:(NSString *)text {
    NSParameterAssert(text);
    if ([_text isEqualToString:text]) return;
    _text=[text copy]; [self layoutText];
}
- (void)setFontSize:(CGFloat)size {
    NSParameterAssert(isfinite(size) && size>0);
    if (_fontSize==size) return;
    _fontSize=size; [self layoutText];
}
- (void)setMaximumWidth:(CGFloat)width {
    NSParameterAssert(isfinite(width) && width>=0);
    if (_maximumWidth==width) return;
    _maximumWidth=width; [self layoutText];
}
- (void)setCentered:(BOOL)centered {
    if (_centered==centered) return;
    _centered=centered; [self layoutText];
}
- (void)setLineSpacing:(CGFloat)spacing {
    NSParameterAssert(isfinite(spacing) && spacing>=0);
    if (_lineSpacing==spacing) return;
    _lineSpacing=spacing; [self layoutText];
}
- (void)setHorizontalInset:(CGFloat)inset {
    NSParameterAssert(isfinite(inset) && inset>=0);
    if (_horizontalInset==inset) return;
    _horizontalInset=inset; [self layoutText];
}
- (void)setColor:(MRColor3B)color {
    _color=color;
    for (MRSprite *sprite in _glyphSprites) sprite.color=color;
}
- (void)setOpacity:(uint8_t)opacity {
    _opacity=opacity;
    for (MRSprite *sprite in _glyphSprites) sprite.opacity=opacity;
}
- (void)layoutText {
    // Remove only our glyphs; callers can retain their own decorations/children.
    for (MRSprite *sprite in _glyphSprites) [sprite removeFromParent];
    [_glyphSprites removeAllObjects];
    CTFontRef font=[_atlas createFontAtSize:_fontSize];
    NSDictionary *attributes=@{(__bridge id)kCTFontAttributeName:(__bridge id)font,
                               (__bridge id)kCTLigatureAttributeName:@0};
    NSAttributedString *attributed=[[NSAttributedString alloc] initWithString:_text attributes:attributes];
    CTTypesetterRef typesetter=CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
    NSMutableArray *lines=[NSMutableArray array];
    BOOL paragraph=_maximumWidth>0;
    CGFloat available=paragraph ? MAX(.01,_maximumWidth-2*_horizontalInset) : CGFLOAT_MAX;
    CFIndex offset=0,length=attributed.length;
    do {
        CFIndex count=paragraph ? CTTypesetterSuggestLineBreak(typesetter,offset,available) : length;
        if (count<1 && offset<length) count=1;
        CTLineRef line=CTTypesetterCreateLine(typesetter,CFRangeMake(offset,count));
        [lines addObject:CFBridgingRelease(line)]; offset+=count;
    } while (offset<length);
    if (paragraph && [_text hasSuffix:@"\n"]) {
        [lines addObject:CFBridgingRelease(CTTypesetterCreateLine(typesetter,CFRangeMake(length,0)))];
    }
    _lineCount=lines.count;
    CGFloat step=_lineSpacing>0 ? _lineSpacing : _fontSize*1.2;
    CGFloat nominalHeight=_fontSize+(lines.count-1)*step;
    CGFloat baseline=CTFontGetDescent(font)+MAX(0,(_fontSize-CTFontGetAscent(font)-CTFontGetDescent(font))/2);
    CGFloat artScale=_fontSize/_atlas.referenceEm,widest=0;
    CGRect ink=CGRectNull;
    for (NSUInteger row=0;row<lines.count;row++) {
        CTLineRef line=(__bridge CTLineRef)lines[row];
        CGFloat advance=CTLineGetTypographicBounds(line,NULL,NULL,NULL);
        if (paragraph) advance-=CTLineGetTrailingWhitespaceWidth(line);
        advance=MAX(0,advance); widest=MAX(widest,advance+2*_horizontalInset);
        CGFloat x=_horizontalInset+(_centered && paragraph ? (_maximumWidth-2*_horizontalInset-advance)/2 : 0);
        CGFloat y=baseline+(lines.count-1-row)*step;
        for (id object in (__bridge NSArray *)CTLineGetGlyphRuns(line)) {
            CTRunRef run=(__bridge CTRunRef)object;
            // A fallback face's glyph IDs belong to a different painted repertoire.
            NSDictionary *runAttributes=(__bridge NSDictionary *)CTRunGetAttributes(run);
            CTFontRef runFont=(__bridge CTFontRef)runAttributes[(__bridge id)kCTFontAttributeName];
            CFStringRef expected=CTFontCopyPostScriptName(font);
            CFStringRef actual=runFont ? CTFontCopyPostScriptName(runFont) : NULL;
            BOOL sameFace=actual && CFEqual(expected,actual);
            CFRelease(expected); if (actual) CFRelease(actual);
            if (!sameFace) continue;
            CFIndex count=CTRunGetGlyphCount(run);
            // Query directly into owned buffers; Core Text may not expose pointers.
            NSMutableData *idData=[NSMutableData dataWithLength:count*sizeof(CGGlyph)];
            NSMutableData *positionData=[NSMutableData dataWithLength:count*sizeof(CGPoint)];
            CGGlyph *ids=idData.mutableBytes; CGPoint *positions=positionData.mutableBytes;
            CTRunGetGlyphs(run,CFRangeMake(0,0),ids);
            CTRunGetPositions(run,CFRangeMake(0,0),positions);
            for (CFIndex i=0;i<count;i++) {
                MRTextGlyph *glyph=_atlas.glyphs[@(ids[i])];
                if (!glyph) continue;
                MRSprite *sprite=[[MRSprite alloc] initWithFrame:glyph.frame];
                sprite.anchorPoint=CGPointZero; sprite.scaleX=artScale; sprite.scaleY=artScale;
                sprite.position=CGPointMake(x+positions[i].x+glyph.origin.x*artScale,
                                            y+positions[i].y+glyph.origin.y*artScale);
                sprite.color=_color; sprite.opacity=_opacity;
                [self addChild:sprite]; [_glyphSprites addObject:sprite];
                // Full frame canvas includes painted contours and shadows.
                CGRect bounds={sprite.position,CGSizeMake(sprite.contentSize.width*artScale,sprite.contentSize.height*artScale)};
                ink=CGRectIsNull(ink) ? bounds : CGRectUnion(ink,bounds);
            }
        }
    }
    CGFloat left=CGRectIsNull(ink) ? 0 : MIN(0,CGRectGetMinX(ink));
    CGFloat bottom=CGRectIsNull(ink) ? 0 : MIN(0,CGRectGetMinY(ink));
    CGFloat width=_centered && paragraph ? _maximumWidth : widest,height=nominalHeight;
    if (!CGRectIsNull(ink)) { width=MAX(width,CGRectGetMaxX(ink)); height=MAX(height,CGRectGetMaxY(ink)); }
    for (MRSprite *sprite in _glyphSprites) sprite.position=CGPointMake(sprite.position.x-left,sprite.position.y-bottom);
    self.contentSize=CGSizeMake(width-left,height-bottom);
    _inkBounds=CGRectIsNull(ink) ? ink : CGRectOffset(ink,-left,-bottom);
    CFRelease(typesetter); CFRelease(font);
}
@end
