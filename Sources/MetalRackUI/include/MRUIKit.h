#pragma once
#import "MetalRackScene.h"
#import <UIKit/UIKit.h>
#import <float.h>
#import <math.h>

static inline CGPoint MRPoint(CGFloat x,CGFloat y) { return CGPointMake(x,y); }
static inline MRColor3B MRRGB(uint8_t r,uint8_t g,uint8_t b) { return (MRColor3B){r,g,b}; }
static inline MRRenderColor MRRGBA(uint8_t r,uint8_t g,uint8_t b,uint8_t a) { return (MRRenderColor){r,g,b,a}; }
#ifndef MR_PARTICLE_COLOR_TYPE
#define MR_PARTICLE_COLOR_TYPE
typedef struct { float r,g,b,a; } MRColor4F;
#endif
static inline MRColor4F MRRGBAFloat(float r,float g,float b,float a) { return (MRColor4F){r,g,b,a}; }
static inline MRColor4F MRFloatColorFromRGB(MRColor3B c) { return MRRGBAFloat(c.r/255.f,c.g/255.f,c.b/255.f,1); }
static inline CGPoint MRPointSubtract(CGPoint a,CGPoint b) { return MRPointSub(a,b); }
static inline CGPoint MRPointScale(CGPoint a,CGFloat s) { return MRPointMult(a,s); }
static inline CGFloat MRPointLength(CGPoint a) { return hypot(a.x,a.y); }
static inline CGPoint MRPointNormalize(CGPoint a) { CGFloat n=MRPointLength(a); return n ? MRPointScale(a,1/n) : CGPointZero; }
static inline BOOL MRPointFuzzyEqual(CGPoint a,CGPoint b,CGFloat variance) { return fabs(a.x-b.x)<=variance && fabs(a.y-b.y)<=variance; }
static inline CGFloat MRPointDistance(CGPoint a,CGPoint b) { return MRPointLength(MRPointSub(a,b)); }
static inline CGFloat MRPointDot(CGPoint a,CGPoint b) { return a.x*b.x+a.y*b.y; }
static inline CGFloat MRPointAngle(CGPoint a) { return atan2(a.y,a.x); }
static inline CGPoint MRPointForAngle(CGFloat a) { return MRPoint(cos(a),sin(a)); }
static inline CGPoint MRPointNegate(CGPoint a) { return MRPointNeg(a); }
static inline CGPoint MRPointLerp(CGPoint a,CGPoint b,CGFloat t) { return MRPointAdd(a,MRPointScale(MRPointSub(b,a),t)); }
static inline CGPoint MRPointClamp(CGPoint a,CGPoint lo,CGPoint hi) { return MRPoint(MAX(lo.x,MIN(hi.x,a.x)),MAX(lo.y,MIN(hi.y,a.y))); }
static inline CGFloat MRRadiansToDegrees(CGFloat a) { return a*180/M_PI; }
static inline CGFloat MRDegreesToRadians(CGFloat a) { return a*M_PI/180; }
static inline float MRRandomUnit(void) { return arc4random()/(float)UINT32_MAX; }
static inline float MRRandomSigned(void) { return MRRandomUnit()*2-1; }

@interface MRNode (UIConvenience)
- (void)removeChildByTag:(NSInteger)tag cleanup:(BOOL)cleanup;
- (CGPoint)convertTouchToNodeSpace:(MRPointerEvent *)event;
- (CGRect)recursiveBoundingBox;
- (CGPoint)convertAnchorRelativePointToWorld:(CGPoint)point;
@end
@interface MRSprite (Resources)
+ (instancetype)spriteWithFrame:(MRSpriteFrame *)frame;
+ (instancetype)spriteWithFrameName:(NSString *)name;
+ (instancetype)spriteWithFile:(NSString *)file;
+ (instancetype)spriteWithTexture:(MRTexture *)texture;
+ (instancetype)spriteWithTexture:(MRTexture *)texture rect:(CGRect)rect;
- (instancetype)initWithTexture:(MRTexture *)texture;
- (instancetype)initWithFrameName:(NSString *)name;
- (instancetype)initWithTexture:(MRTexture *)texture rect:(CGRect)rect;
@property(nonatomic, readonly) MRTexture *texture;
@property(nonatomic) CGRect textureRect;
- (void)setTextureRect:(CGRect)rect;
- (BOOL)isDisplayingFrame:(MRSpriteFrame *)frame;
@end

typedef NS_ENUM(NSInteger, MRTextAlignment) { MRTextAlignmentLeft,MRTextAlignmentCenter,MRTextAlignmentRight };
@interface MRLayer : MRNode <MRPointerReceiver>
@property(nonatomic) BOOL isTouchEnabled;
@property(nonatomic) NSInteger inputPriority;
@property(nonatomic) BOOL swallowsPointers;
- (void)registerInput;
- (void)pointersBegan:(NSSet<MRPointerEvent *> *)events;
- (void)pointersMoved:(NSSet<MRPointerEvent *> *)events;
- (void)pointersEnded:(NSSet<MRPointerEvent *> *)events;
- (void)pointersCancelled:(NSSet<MRPointerEvent *> *)events;
@end
@interface MRScene : MRNode
@end
@interface MRColorLayer : MRLayer <MRRGBAProtocol>
@property(nonatomic) MRColor3B color;
@property(nonatomic) uint8_t opacity;
+ (instancetype)layerWithColor:(MRRenderColor)color;
+ (instancetype)layerWithColor:(MRRenderColor)color width:(CGFloat)width height:(CGFloat)height;
- (instancetype)initWithColor:(MRRenderColor)color width:(CGFloat)width height:(CGFloat)height;
@end
@interface MRGradientLayer : MRColorLayer
@property(nonatomic) MRColor3B startColor;
@property(nonatomic) MRColor3B endColor;
@property(nonatomic) uint8_t startOpacity;
@property(nonatomic) uint8_t endOpacity;
@property(nonatomic) CGPoint vector;
- (instancetype)initWithColor:(MRRenderColor)start fadingTo:(MRRenderColor)end;
+ (instancetype)layerWithColor:(MRRenderColor)start fadingTo:(MRRenderColor)end;
+ (instancetype)layerWithColor:(MRRenderColor)start fadingTo:(MRRenderColor)end alongVector:(CGPoint)vector;
@end
@interface MRSystemText : MRSprite
@property(nonatomic, copy) NSString *string;
@property(nonatomic, copy) NSString *fontName;
@property(nonatomic) CGFloat fontSize;
@property(nonatomic) CGSize dimensions;
@property(nonatomic) MRTextAlignment alignment;
+ (instancetype)labelWithString:(NSString *)string fontName:(NSString *)font fontSize:(CGFloat)size;
+ (instancetype)labelWithString:(NSString *)string dimensions:(CGSize)dimensions alignment:(MRTextAlignment)alignment fontName:(NSString *)font fontSize:(CGFloat)size;
@end
@interface MRRenderSurface : MRNode
@property(nonatomic, readonly) MRSprite *sprite;
+ (instancetype)surfaceWithSize:(CGSize)size pixelsPerPoint:(CGFloat)density;
- (void)begin;
- (void)beginWithClear:(float)r g:(float)g b:(float)b a:(float)a;
- (void)end;
- (UIImage *)image;
@end
@interface MRMenuItem : MRNode <MRRGBAProtocol>
@property(nonatomic) BOOL isEnabled;
@property(nonatomic) MRColor3B color;
@property(nonatomic) uint8_t opacity;
- (void)activate;
@end
@interface MRMenuItemText : MRMenuItem
+ (void)setFontName:(NSString *)name;
+ (void)setFontSize:(CGFloat)size;
+ (instancetype)itemFromString:(NSString *)text target:(id)target selector:(SEL)selector;
@end
@interface MRMenu : MRLayer
+ (instancetype)menuWithItems:(MRMenuItem *)first,... NS_REQUIRES_NIL_TERMINATION;
- (void)alignItemsVertically;
- (void)alignItemsVerticallyWithPadding:(CGFloat)padding;
- (void)alignItemsHorizontally;
- (void)alignItemsHorizontallyWithPadding:(CGFloat)padding;
@end
#import "MRParticles.h"
#import "MRSceneRuntime.h"
@interface MRBundleResources : NSObject
+ (NSString *)pathForResource:(NSString *)name;
@end
#import "MRSceneTransition.h"
