#pragma once
#import "MRNode.h"
#import "MRActionTypes.h"

FOUNDATION_EXPORT NSString *const MRTextureErrorDomain;
typedef struct { float minX,minY,maxX,maxY; } MRNormalizedRegion;

/// Owns a native premultiplied RGBA texture. Pixel rows start at the top; density is an atlas
/// policy supplied by the caller, never inferred from filename suffixes.
@interface MRTexture : NSObject
@property(nonatomic, readonly) uint32_t identifier;
@property(nonatomic, readonly) CGSize pixelSize;
@property(nonatomic, readonly, retain) MRRenderContext *context;
- (instancetype)initWithContext:(MRRenderContext *)context image:(CGImageRef)image error:(NSError **)error;
@property(nonatomic, readonly) BOOL hasMipmaps;
- (void)generateMipmaps;
- (void)replaceRGBA:(const void *)pixels;
- (instancetype)initWithContext:(MRRenderContext *)context width:(int)width height:(int)height rgba:(const void *)pixels;
@end

@interface MRSpriteFrame : NSObject
@property(nonatomic, readonly, retain) MRTexture *texture;
@property(nonatomic, readonly) CGRect pixelRect;
@property(nonatomic, readonly) CGRect pointRect;
@property(nonatomic, readonly) CGSize originalSize;
@property(nonatomic, readonly) CGPoint trimOffset;
@property(nonatomic, readonly) CGFloat pixelsPerPoint;
@property(nonatomic, readonly) BOOL rotated;
- (MRSpriteFrame *)frameByCroppingToRect:(CGRect)logicalRect NS_SWIFT_NAME(cropped(to:));
/// originalSize and trimOffset are logical points; pixelRect is stored pixels.
- (instancetype)initWithTexture:(MRTexture *)texture pixelRect:(CGRect)rect
                  originalSize:(CGSize)size trimOffset:(CGPoint)offset
                pixelsPerPoint:(CGFloat)density rotated:(BOOL)rotated;
@end

@interface MRSprite : MRNode <MRRGBAProtocol>
@property(nonatomic, retain) MRSpriteFrame *frame;
@property(nonatomic, assign) MRColor3B color;
@property(nonatomic, assign) uint8_t opacity;
@property(nonatomic, assign) BOOL flipX;
@property(nonatomic, assign) BOOL flipY;
@property(nonatomic, assign) MRBlendFunction blend;
@property(nonatomic, assign) MRTextureSampling sampling;
- (instancetype)initWithFrame:(MRSpriteFrame *)frame;
/// Six local-space triangle vertices, retaining the frame's trim/rotation/UVs.
/// Returns zero for an empty or fully transparent sprite.
- (NSUInteger)writeLocalVertices:(MRRenderVertex *)vertices;
/// Regions use normalized top-left coordinates of the visible sprite quad.
- (void)drawRegions:(const MRNormalizedRegion *)regions count:(NSUInteger)count context:(MRRenderContext *)context;
@end
