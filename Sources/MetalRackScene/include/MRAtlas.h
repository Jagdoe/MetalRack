#pragma once
#import "MRSprite.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *const MRAtlasErrorDomain;
/// Loads TexturePacker format-2/3 geometry in physical pixels. The caller supplies
/// density explicitly; the library never interprets application metadata keys.
@interface MRAtlas : NSObject
@property(nonatomic, readonly, copy) NSDictionary<NSString *,MRSpriteFrame *> *frames;
- (BOOL)addFramesFromDictionary:(NSDictionary *)dictionary texture:(MRTexture *)texture
                pixelsPerPoint:(CGFloat)density error:(NSError **)error;
- (nullable MRSpriteFrame *)frameNamed:(NSString *)name;
- (void)removeAllFrames;
- (void)removeFrameNamed:(NSString *)name;
- (void)setFrame:(MRSpriteFrame *)frame named:(NSString *)name;
@end
NS_ASSUME_NONNULL_END
