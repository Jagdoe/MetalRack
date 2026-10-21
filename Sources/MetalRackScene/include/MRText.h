#pragma once
#import "MRSprite.h"
#import <CoreText/CoreText.h>

NS_ASSUME_NONNULL_BEGIN
/// Painted glyph canvas and its lower-left origin relative to the baseline,
/// measured at the atlas's reference em. Texture density belongs to the frame.
@interface MRTextGlyph : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property(nonatomic, readonly, strong) MRSpriteFrame *frame;
@property(nonatomic, readonly) CGPoint origin;
- (instancetype)initWithFrame:(MRSpriteFrame *)frame origin:(CGPoint)origin;
@end

/// An explicitly supplied font face and reusable painted glyphs keyed by CGGlyph.
/// The caller owns artwork/coverage policy. Spaces advance without a sprite;
/// unpainted glyphs are skipped. No installed-font lookup or fallback rasterizer.
@interface MRTextAtlas : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property(nonatomic, readonly) CGFloat referenceEm;
@property(nonatomic, readonly, copy) NSDictionary<NSNumber *, MRTextGlyph *> *glyphs;
- (instancetype)initWithFont:(CGFontRef)font referenceEm:(CGFloat)em
                     glyphs:(NSDictionary<NSNumber *, MRTextGlyph *> *)glyphs;
- (CTFontRef)createFontAtSize:(CGFloat)size CF_RETURNS_RETAINED;
@end

/// Core Text shaping/word wrapping with native MetalRack glyph sprites.
/// Coordinates, dimensions and options are logical points. Ligatures are disabled
/// to support finite painted repertoires; the caller must supply matching glyphs.
@interface MRText : MRNode <MRRGBAProtocol>
- (instancetype)init NS_UNAVAILABLE;
@property(nonatomic, readonly, strong) MRTextAtlas *atlas;
@property(nonatomic, copy) NSString *text;
@property(nonatomic) CGFloat fontSize;
/// Zero gives an unwrapped single line. Positive widths enable word wrapping.
@property(nonatomic) CGFloat maximumWidth;
@property(nonatomic) BOOL centered;
/// Zero selects 1.2 * fontSize. A positive value is baseline-to-baseline spacing.
@property(nonatomic) CGFloat lineSpacing;
/// Reserved on both sides when measuring/wrapping. Supplied by artwork policy.
@property(nonatomic) CGFloat horizontalInset;
@property(nonatomic, readonly) NSUInteger lineCount;
@property(nonatomic, readonly) CGRect inkBounds;
@property(nonatomic) MRColor3B color;
@property(nonatomic) uint8_t opacity;
- (instancetype)initWithAtlas:(MRTextAtlas *)atlas text:(NSString *)text fontSize:(CGFloat)size;
@end
NS_ASSUME_NONNULL_END
