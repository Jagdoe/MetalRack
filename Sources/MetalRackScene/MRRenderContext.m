#import "MRRenderContext.h"

static NSValue *MRTransformValue(CGAffineTransform v) { return [NSValue valueWithBytes:&v objCType:@encode(CGAffineTransform)]; }
static NSValue *MRRectValue(CGRect v) { return [NSValue valueWithBytes:&v objCType:@encode(CGRect)]; }
static NSValue *MRSizeValue(CGSize v) { return [NSValue valueWithBytes:&v objCType:@encode(CGSize)]; }
static CGAffineTransform MRGetTransform(NSValue *v) { CGAffineTransform r; [v getValue:&r size:sizeof(r)]; return r; }
static CGRect MRGetRect(NSValue *v) { CGRect r; [v getValue:&r size:sizeof(r)]; return r; }
static CGSize MRGetSize(NSValue *v) { CGSize r; [v getValue:&r size:sizeof(r)]; return r; }

@interface MRRenderContext () {
    MRRenderBackend _backend;
    CGAffineTransform _transform;
    CGRect _clipRect;
    NSMutableArray *_transforms, *_clips, *_targets;
    uint32_t _nextTexture;
}
@end
@implementation MRRenderContext
@synthesize logicalSize = _logicalSize;
+ (instancetype)sharedContext {
    static MRRenderContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ context = [[self alloc] init]; });
    return context;
}
- (id)init {
    if ((self=[super init])) {
        _transforms=[NSMutableArray new]; _clips=[NSMutableArray new]; _targets=[NSMutableArray new];
        _transform=CGAffineTransformIdentity; _nextTexture=1;
    }
    return self;
}

- (CGAffineTransform)transform { return _transform; }
- (CGRect)clipRect { return _clipRect; }
- (void)setBackend:(MRRenderBackend)backend { _backend=backend; }
- (void)beginFrameWithSize:(CGSize)size {
    NSAssert(_backend.beginFrame && _backend.draw && _backend.present,@"A native scene backend must be attached");
    NSParameterAssert(isfinite(size.width) && isfinite(size.height) && size.width>0 && size.height>0);
    NSAssert(!_targets.count,@"Unclosed scene render target");
    _logicalSize=size; _transform=CGAffineTransformIdentity; _clipRect=(CGRect){CGPointZero,size};
    [_transforms removeAllObjects]; [_clips removeAllObjects];
    _backend.beginFrame(_backend.context,size);
}
- (void)present { _backend.present(_backend.context); }
- (void)pushTransform { [_transforms addObject:MRTransformValue(_transform)]; }
- (void)multiplyTransform:(CGAffineTransform)transform { _transform=CGAffineTransformConcat(transform,_transform); }
- (void)popTransform {
    NSAssert(_transforms.count,@"Unbalanced scene transform stack");
    _transform=MRGetTransform([_transforms lastObject]); [_transforms removeLastObject];
}
- (void)pushClipRect:(CGRect)rect {
    [_clips addObject:MRRectValue(_clipRect)];
    _clipRect=CGRectIntersection(_clipRect,CGRectApplyAffineTransform(rect,_transform));
}
- (void)popClipRect {
    NSAssert(_clips.count,@"Unbalanced scene clip stack");
    _clipRect=MRGetRect([_clips lastObject]); [_clips removeLastObject];
}
- (uint32_t)uploadWidth:(int)width height:(int)height rgba:(const void *)pixels {
    NSAssert(_backend.upload,@"A native texture backend must be attached");
    uint32_t identifier=_nextTexture++;
    _backend.upload(_backend.context,identifier,width,height,pixels);
    return identifier;
}
- (void)generateMipmapsForTexture:(uint32_t)identifier {NSAssert(_backend.generateMipmaps,@"Backend must support native mipmap generation");_backend.generateMipmaps(_backend.context,identifier);}
- (void)replaceTexture:(uint32_t)identifier width:(int)width height:(int)height rgba:(const void *)pixels {
    NSParameterAssert(identifier && width>0 && height>0 && pixels);NSAssert(_backend.upload,@"A native backend must be attached");
    _backend.upload(_backend.context,identifier,width,height,pixels);
}
- (void)removeTexture:(uint32_t)identifier { if (_backend.removeTexture) _backend.removeTexture(_backend.context,identifier); }
- (void)drawVertices:(const MRRenderVertex *)vertices count:(size_t)count
            texture:(uint32_t)texture blend:(MRBlendFunction)blend sampling:(MRTextureSampling)sampling {
    if (!count || CGRectIsNull(_clipRect) || CGRectIsEmpty(_clipRect)) return;
    NSMutableData *data=[NSMutableData dataWithLength:sizeof(MRRenderVertex)*count];
    MRRenderVertex *output=data.mutableBytes;
    for (size_t i=0;i<count;i++) {
        CGPoint p=CGPointApplyAffineTransform(CGPointMake(vertices[i].x,vertices[i].y),_transform);
        output[i]=vertices[i]; output[i].x=p.x; output[i].y=p.y;
    }
    _backend.draw(_backend.context,output,count,texture,blend,sampling,_clipRect,_logicalSize);
}
- (void)beginTarget:(uint32_t)texture size:(CGSize)size clear:(BOOL)clear color:(MRRenderColor)color {
    NSAssert(_backend.beginTarget && _backend.endTarget,@"A native snapshot backend must be attached");
    [_targets addObject:@{ @"size":MRSizeValue(_logicalSize),
        @"transform":MRTransformValue(_transform),@"clip":MRRectValue(_clipRect) }];
    _logicalSize=size; _transform=CGAffineTransformIdentity; _clipRect=(CGRect){CGPointZero,size};
    _backend.beginTarget(_backend.context,texture,size,clear,color);
}
- (void)endTarget {
    NSAssert(_targets.count,@"Unbalanced scene render target stack");
    _backend.endTarget(_backend.context);
    NSDictionary *saved=[_targets lastObject];
    _logicalSize=MRGetSize(saved[@"size"]); _transform=MRGetTransform(saved[@"transform"]);
    _clipRect=MRGetRect(saved[@"clip"]); [_targets removeLastObject];
}
- (void)readTexture:(uint32_t)texture rect:(CGRect)rect rgba:(void *)pixels {
    NSAssert(_backend.read,@"A native snapshot readback backend must be attached");
    _backend.read(_backend.context,texture,rect,pixels);
}
@end
