#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import "MRUIKit.h"
@implementation MRBundleResources
+ (NSString *)pathForResource:(NSString *)name {
    if ([name isAbsolutePath]) return name;
    NSString *path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:name];
    return [NSFileManager.defaultManager fileExistsAtPath:path] ? path : ([NSBundle.mainBundle pathForResource:name.lastPathComponent ofType:nil] ?: path);
}
@end
@implementation MRNode (UIConvenience)
- (CGPoint)convertAnchorRelativePointToWorld:(CGPoint)point { return [self convertToWorldSpace:MRPointAdd(point,MRPoint(self.anchorPoint.x*self.contentSize.width,self.anchorPoint.y*self.contentSize.height))]; }
- (void)removeChildByTag:(NSInteger)tag cleanup:(BOOL)cleanup { MRNode *child=[self getChildByTag:tag]; if(child)[self removeChild:child cleanup:cleanup]; }
- (CGPoint)convertTouchToNodeSpace:(MRPointerEvent *)event { return [event locationInNode:self]; }
- (CGRect)recursiveBoundingBox { return CGRectApplyAffineTransform(self.subtreeBounds,CGAffineTransformMakeScale(self.scaleX,self.scaleY)); }
@end
@implementation MRSprite (Resources)
- (instancetype)initWithFrameName:(NSString *)name { return [self initWithFrame:[[MRSceneRuntime sharedRuntime].resources frameNamed:name]]; }
- (instancetype)initWithTexture:(MRTexture *)texture { return [self initWithTexture:texture rect:(CGRect){CGPointZero,texture.pixelSize}]; }
+ (instancetype)spriteWithFrame:(MRSpriteFrame *)frame { return [[self alloc] initWithFrame:frame]; }
+ (instancetype)spriteWithFrameName:(NSString *)name { MRSpriteFrame *frame=[[MRSceneRuntime sharedRuntime].resources frameNamed:name]; NSAssert(frame,@"Missing sprite frame %@",name); return [self spriteWithFrame:frame]; }
+ (instancetype)spriteWithFile:(NSString *)file {
    NSError *error=nil; MRTexture *texture=[[MRSceneRuntime sharedRuntime].resources textureNamed:file error:&error];
    NSAssert(texture,@"Cannot load image %@: %@",file,error); return [self spriteWithTexture:texture];
}
+ (instancetype)spriteWithTexture:(MRTexture *)texture { return [self spriteWithTexture:texture rect:(CGRect){CGPointZero,texture.pixelSize}]; }
+ (instancetype)spriteWithTexture:(MRTexture *)texture rect:(CGRect)rect { return [[self alloc] initWithTexture:texture rect:rect]; }
- (instancetype)initWithTexture:(MRTexture *)texture rect:(CGRect)rect {
    return [self initWithFrame:[[MRSpriteFrame alloc] initWithTexture:texture pixelRect:rect originalSize:rect.size trimOffset:CGPointZero pixelsPerPoint:1 rotated:NO]];
}
- (MRTexture *)texture { return self.frame.texture; }
- (CGRect)textureRect { return self.frame.pixelRect; }
- (void)setTextureRect:(CGRect)rect {
    MRSpriteFrame *frame=self.frame;
    self.frame=[[MRSpriteFrame alloc] initWithTexture:frame.texture pixelRect:rect
        originalSize:CGSizeMake(rect.size.width/frame.pixelsPerPoint,rect.size.height/frame.pixelsPerPoint)
        trimOffset:CGPointZero pixelsPerPoint:frame.pixelsPerPoint rotated:NO];
}
- (BOOL)isDisplayingFrame:(MRSpriteFrame *)frame { return self.frame==frame; }
@end
@implementation MRLayer
- (instancetype)init { if ((self=[super init])) self.contentSize=[MRSceneRuntime sharedRuntime].winSize; return self; }
- (void)setIsTouchEnabled:(BOOL)enabled { if(_isTouchEnabled==enabled)return;_isTouchEnabled=enabled; if(self.inScene)[self registerInput]; }
- (void)registerInput {
    [self.environment.input removeReceiver:self];
    if(_isTouchEnabled)[self.environment.input addReceiver:self priority:_inputPriority swallows:_swallowsPointers];
}
- (void)didEnterScene { [super didEnterScene]; [self registerInput]; }
- (BOOL)pointerBegan:(MRPointerEvent *)event { [self pointersBegan:[NSSet setWithObject:event]]; return YES; }
- (void)pointerMoved:(MRPointerEvent *)event { [self pointersMoved:[NSSet setWithObject:event]]; }
- (void)pointerEnded:(MRPointerEvent *)event { [self pointersEnded:[NSSet setWithObject:event]]; }
- (void)pointerCancelled:(MRPointerEvent *)event { [self pointersCancelled:[NSSet setWithObject:event]]; }
- (void)pointersBegan:(NSSet *)events {}
- (void)pointersMoved:(NSSet *)events {}
- (void)pointersEnded:(NSSet *)events {}
- (void)pointersCancelled:(NSSet *)events {}
@end
@implementation MRScene
- (instancetype)init { if((self=[super init]))self.contentSize=[MRSceneRuntime sharedRuntime].winSize;return self; }
@end
static void MRDrawColorQuad(MRRenderContext *context,CGSize size,MRColor4F bl,MRColor4F br,MRColor4F tl,MRColor4F tr) {
    CGPoint points[4]={{0,0},{size.width,0},{0,size.height},{size.width,size.height}};
    MRColor4F colors[4]={bl,br,tl,tr}; int order[6]={0,1,2,2,1,3}; MRRenderVertex vertices[6];
    for(int i=0;i<6;i++){int j=order[i];MRColor4F c=colors[j];vertices[i]=(MRRenderVertex){points[j].x,points[j].y,0,0,c.r*c.a,c.g*c.a,c.b*c.a,c.a};}
    [context drawVertices:vertices count:6 texture:0 blend:(MRBlendFunction){MRBlendOne,MRBlendOneMinusSourceAlpha} sampling:(MRTextureSampling){MRFilterNearest,MRFilterNearest,MRAddressClamp,MRAddressClamp}];
}
@implementation MRColorLayer
+ (instancetype)layerWithColor:(MRRenderColor)c { CGSize s=[MRSceneRuntime sharedRuntime].winSize;return [self layerWithColor:c width:s.width height:s.height]; }
+ (instancetype)layerWithColor:(MRRenderColor)c width:(CGFloat)w height:(CGFloat)h { return [[self alloc] initWithColor:c width:w height:h]; }
- (instancetype)initWithColor:(MRRenderColor)c width:(CGFloat)w height:(CGFloat)h {if((self=[super init])){_color=MRRGB(c.r,c.g,c.b);_opacity=c.a;self.contentSize=CGSizeMake(w,h);}return self;}
- (void)draw:(MRRenderContext *)context {MRColor4F c=MRFloatColorFromRGB(_color);c.a=_opacity/255.f;MRDrawColorQuad(context,self.contentSize,c,c,c,c);}
@end
@implementation MRGradientLayer
- (instancetype)initWithColor:(MRRenderColor)a fadingTo:(MRRenderColor)b {
    CGSize size=[MRSceneRuntime sharedRuntime].winSize;
    if((self=[super initWithColor:MRRGBA(a.r,a.g,a.b,255) width:size.width height:size.height])){
        _startColor=MRRGB(a.r,a.g,a.b);_endColor=MRRGB(b.r,b.g,b.b);_startOpacity=a.a;_endOpacity=b.a;_vector=CGPointMake(0,-1);
    }return self;
}
- (void)setColor:(MRColor3B)color {[super setColor:color];_startColor=color;}

+ (instancetype)layerWithColor:(MRRenderColor)a fadingTo:(MRRenderColor)b {return [self layerWithColor:a fadingTo:b alongVector:CGPointMake(0,-1)];}
+ (instancetype)layerWithColor:(MRRenderColor)a fadingTo:(MRRenderColor)b alongVector:(CGPoint)v {
    MRGradientLayer *layer=[[self alloc]initWithColor:a width:[MRSceneRuntime sharedRuntime].winSize.width height:[MRSceneRuntime sharedRuntime].winSize.height];
    layer.opacity=255;layer.startColor=MRRGB(a.r,a.g,a.b);layer.endColor=MRRGB(b.r,b.g,b.b);layer.startOpacity=a.a;layer.endOpacity=b.a;layer.vector=v;return layer;
}
- (void)draw:(MRRenderContext *)context {
    CGPoint v=MRPointNormalize(_vector);CGFloat denom=fabs(v.x)+fabs(v.y);
    if(!denom)denom=1;
    MRColor4F a=MRFloatColorFromRGB(_startColor),b=MRFloatColorFromRGB(_endColor);a.a=_startOpacity/255.f;b.a=_endOpacity/255.f;
    MRColor4F colors[4];CGPoint corners[4]={{-1,-1},{1,-1},{-1,1},{1,1}};
    for(int i=0;i<4;i++){float t=(1+MRPointDot(corners[i],v)/denom)/2;colors[i]=MRRGBAFloat(a.r+(b.r-a.r)*t,a.g+(b.g-a.g)*t,a.b+(b.b-a.b)*t,(a.a+(b.a-a.a)*t)*self.opacity/255.f);}
    MRDrawColorQuad(context,self.contentSize,colors[0],colors[1],colors[2],colors[3]);
}
@end
@implementation MRSystemText
+ (instancetype)labelWithString:(NSString *)s fontName:(NSString *)name fontSize:(CGFloat)size {return [self labelWithString:s dimensions:CGSizeZero alignment:MRTextAlignmentCenter fontName:name fontSize:size];}
+ (instancetype)labelWithString:(NSString *)s dimensions:(CGSize)d alignment:(MRTextAlignment)a fontName:(NSString *)name fontSize:(CGFloat)size {
    MRSystemText *label=[[self alloc]init];label->_fontName=[name copy];label->_fontSize=size;label->_dimensions=d;label->_alignment=a;label.string=s;return label;
}
- (void)setString:(NSString *)string { _string=[string copy];[self rebuild]; }
- (void)setFontName:(NSString *)fontName {_fontName=[fontName copy];if(_string)[self rebuild];}
- (void)setFontSize:(CGFloat)fontSize {_fontSize=fontSize;if(_string)[self rebuild];}
- (void)setDimensions:(CGSize)dimensions {_dimensions=dimensions;if(_string)[self rebuild];}
- (void)setAlignment:(MRTextAlignment)alignment {_alignment=alignment;if(_string)[self rebuild];}
- (void)rebuild {
    UIFont *font=[UIFont fontWithName:_fontName?:@"Helvetica" size:MAX(.01,_fontSize)]?:[UIFont systemFontOfSize:MAX(.01,_fontSize)];
    NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.alignment=_alignment==MRTextAlignmentLeft?NSTextAlignmentLeft:_alignment==MRTextAlignmentRight?NSTextAlignmentRight:NSTextAlignmentCenter;
    NSDictionary *attrs=@{NSFontAttributeName:font,NSForegroundColorAttributeName:UIColor.whiteColor,NSParagraphStyleAttributeName:style};
    CGSize size=_dimensions;
    if(size.width<=0||size.height<=0){CGSize measured=[_string boundingRectWithSize:CGSizeMake(size.width>0?size.width:CGFLOAT_MAX,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:attrs context:nil].size;if(size.width<=0)size.width=ceil(measured.width);if(size.height<=0)size.height=ceil(measured.height);}
    if(size.width<=0||size.height<=0){self.frame=nil;self.contentSize=size;return;}
    CGFloat density=[MRSceneRuntime sharedRuntime].pixelsPerPoint;
    UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=density;format.opaque=NO;
    UIGraphicsImageRenderer *r=[[UIGraphicsImageRenderer alloc]initWithSize:size format:format];
    UIImage *image=[r imageWithActions:^(UIGraphicsImageRendererContext *ctx){[self->_string drawInRect:(CGRect){CGPointZero,size} withAttributes:attrs];}];
    NSError *error=nil;MRTexture *texture=[[MRTexture alloc]initWithContext:[MRSceneRuntime sharedRuntime].context image:image.CGImage error:&error];NSAssert(texture,@"System text rasterization failed: %@",error);
    self.frame=[[MRSpriteFrame alloc]initWithTexture:texture pixelRect:(CGRect){CGPointZero,texture.pixelSize} originalSize:size trimOffset:CGPointZero pixelsPerPoint:density rotated:NO];
}
@end
@implementation MRRenderSurface
+ (instancetype)surfaceWithSize:(CGSize)size pixelsPerPoint:(CGFloat)density {
    MRRenderSurface *surface=[self new];int width=ceil(size.width*density),height=ceil(size.height*density);
    NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)width*height*4];
    MRTexture *texture=[[MRTexture alloc]initWithContext:[MRSceneRuntime sharedRuntime].context width:width height:height rgba:data.bytes];
    MRSpriteFrame *frame=[[MRSpriteFrame alloc]initWithTexture:texture pixelRect:CGRectMake(0,0,width,height) originalSize:size trimOffset:CGPointZero pixelsPerPoint:density rotated:NO];
    surface->_sprite=[[MRSprite alloc]initWithFrame:frame];surface.contentSize=size;[surface addChild:surface->_sprite];return surface;
}
- (void)begin {[self.sprite.texture.context beginTarget:self.sprite.texture.identifier size:self.contentSize clear:NO color:MRRGBA(0,0,0,0)];}
- (void)beginWithClear:(float)r g:(float)g b:(float)b a:(float)a {[self.sprite.texture.context beginTarget:self.sprite.texture.identifier size:self.contentSize clear:YES color:MRRGBA(r*255,g*255,b*255,a*255)];}
- (void)end {[self.sprite.texture.context endTarget];}
- (UIImage *)image {
    MRTexture *texture=self.sprite.texture;size_t width=texture.pixelSize.width,height=texture.pixelSize.height;
    NSMutableData *data=[NSMutableData dataWithLength:width*height*4];[texture.context readTexture:texture.identifier rect:CGRectMake(0,0,width,height) rgba:data.mutableBytes];
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGImageRef cg=CGImageCreate(width,height,8,32,width*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big,provider,NULL,NO,kCGRenderingIntentDefault);
    UIImage *image=[UIImage imageWithCGImage:cg scale:self.sprite.frame.pixelsPerPoint orientation:UIImageOrientationUp];CGImageRelease(cg);CGColorSpaceRelease(space);CGDataProviderRelease(provider);return image;
}
@end
#endif
