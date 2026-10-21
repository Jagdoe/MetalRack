#import "MRSprite.h"
#include <limits.h>
NSString *const MRTextureErrorDomain=@"MetalRack.Scene.Texture";
@implementation MRTexture
- (void)generateMipmaps { [_context generateMipmapsForTexture:_identifier];_hasMipmaps=YES; }
- (void)replaceRGBA:(const void *)pixels { [_context replaceTexture:_identifier width:(int)_pixelSize.width height:(int)_pixelSize.height rgba:pixels]; if (_hasMipmaps) [_context generateMipmapsForTexture:_identifier]; }
- (instancetype)initWithContext:(MRRenderContext *)context image:(CGImageRef)image error:(NSError **)error {
    size_t width=image ? CGImageGetWidth(image) : 0, height=image ? CGImageGetHeight(image) : 0;
    if (!context || !width || !height || width>INT_MAX || height>INT_MAX || width>SIZE_MAX/4/height) {
        if (error) *error=[NSError errorWithDomain:MRTextureErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:@"Invalid native image dimensions or context"}];
        return nil;
    }
    NSMutableData *rgba=[NSMutableData dataWithLength:width*height*4];
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap=CGBitmapContextCreate(rgba.mutableBytes,width,height,8,width*4,space,
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!bitmap) {
        if (error) *error=[NSError errorWithDomain:MRTextureErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey:@"Cannot decode native RGBA image"}];
        return nil;
    }
    CGContextSetBlendMode(bitmap,kCGBlendModeCopy);
    CGContextSetInterpolationQuality(bitmap,kCGInterpolationNone);
    CGContextDrawImage(bitmap,CGRectMake(0,0,width,height),image);
    CGContextRelease(bitmap);
    return [self initWithContext:context width:(int)width height:(int)height rgba:rgba.bytes];
}
- (instancetype)initWithContext:(MRRenderContext *)context width:(int)width height:(int)height rgba:(const void *)pixels {
    NSParameterAssert(context && width>0 && height>0 && pixels);
    if ((self=[super init])) {
        _context=(context); _pixelSize=CGSizeMake(width,height);
        _identifier=[context uploadWidth:width height:height rgba:pixels];
    }
    return self;
}
- (void)dealloc { [_context removeTexture:_identifier];   }
@end
@implementation MRSpriteFrame
- (CGRect)pointRect { return CGRectMake(_pixelRect.origin.x/_pixelsPerPoint,_pixelRect.origin.y/_pixelsPerPoint,(_rotated ? _pixelRect.size.height : _pixelRect.size.width)/_pixelsPerPoint,(_rotated ? _pixelRect.size.width : _pixelRect.size.height)/_pixelsPerPoint); }
- (MRSpriteFrame *)frameByCroppingToRect:(CGRect)crop {
    CGFloat w=(_rotated?_pixelRect.size.height:_pixelRect.size.width)/_pixelsPerPoint;
    CGFloat h=(_rotated?_pixelRect.size.width:_pixelRect.size.height)/_pixelsPerPoint;
    CGRect visible=CGRectMake((_originalSize.width-w)/2+_trimOffset.x,(_originalSize.height-h)/2+_trimOffset.y,w,h);
    CGRect part=CGRectIntersection(visible,crop);if(CGRectIsEmpty(part))return nil;
    CGRect rect;
    if(_rotated)rect=CGRectMake(_pixelRect.origin.x+(part.origin.y-visible.origin.y)*_pixelsPerPoint,_pixelRect.origin.y+(part.origin.x-visible.origin.x)*_pixelsPerPoint,part.size.height*_pixelsPerPoint,part.size.width*_pixelsPerPoint);
    else rect=CGRectMake(_pixelRect.origin.x+(part.origin.x-visible.origin.x)*_pixelsPerPoint,_pixelRect.origin.y+(CGRectGetMaxY(visible)-CGRectGetMaxY(part))*_pixelsPerPoint,part.size.width*_pixelsPerPoint,part.size.height*_pixelsPerPoint);
    CGPoint offset=CGPointMake(CGRectGetMidX(part)-crop.origin.x-crop.size.width/2,CGRectGetMidY(part)-crop.origin.y-crop.size.height/2);
    return [[MRSpriteFrame alloc]initWithTexture:_texture pixelRect:rect originalSize:crop.size trimOffset:offset pixelsPerPoint:_pixelsPerPoint rotated:_rotated];
}
- (instancetype)initWithTexture:(MRTexture *)texture pixelRect:(CGRect)rect
                  originalSize:(CGSize)size trimOffset:(CGPoint)offset
                pixelsPerPoint:(CGFloat)density rotated:(BOOL)rotated {
    NSParameterAssert(texture && density>0 && size.width>=0 && size.height>=0);
    NSParameterAssert(rect.size.width>0 && rect.size.height>0 && CGRectContainsRect((CGRect){CGPointZero,texture.pixelSize},rect));
    if ((self=[super init])) {
        _texture=(texture); _pixelRect=rect; _originalSize=size;
        _trimOffset=offset; _pixelsPerPoint=density; _rotated=rotated;
    }
    return self;
}

@end
@implementation MRSprite
- (instancetype)init { return [self initWithFrame:nil]; }
- (instancetype)initWithFrame:(MRSpriteFrame *)frame {
    if ((self=[super init])) {
        self.anchorPoint=CGPointMake(.5,.5); _color=(MRColor3B){255,255,255}; _opacity=255;
        _blend=(MRBlendFunction){MRBlendOne,MRBlendOneMinusSourceAlpha};
        _sampling=(MRTextureSampling){MRFilterLinear,MRFilterLinear,MRAddressClamp,MRAddressClamp};
        self.frame=frame;
    }
    return self;
}

- (void)setFrame:(MRSpriteFrame *)frame {
    if (_frame==frame) return;
      _frame=frame; self.contentSize=frame.originalSize;
}
- (CGRect)localDrawBounds {
    if(!_frame)return CGRectNull;
    CGFloat w=(_frame.rotated?_frame.pixelRect.size.height:_frame.pixelRect.size.width)/_frame.pixelsPerPoint;
    CGFloat h=(_frame.rotated?_frame.pixelRect.size.width:_frame.pixelRect.size.height)/_frame.pixelsPerPoint;
    return CGRectMake((self.contentSize.width-w)/2+(_flipX?-_frame.trimOffset.x:_frame.trimOffset.x),(self.contentSize.height-h)/2+(_flipY?-_frame.trimOffset.y:_frame.trimOffset.y),w,h);
}
- (NSUInteger)writeLocalVertices:(MRRenderVertex *)vertices {
    if (!_frame || !_opacity) return 0;
    CGRect rect=_frame.pixelRect;
    CGFloat w=(_frame.rotated ? rect.size.height : rect.size.width)/_frame.pixelsPerPoint;
    CGFloat h=(_frame.rotated ? rect.size.width : rect.size.height)/_frame.pixelsPerPoint;
    CGFloat ox=_flipX ? -_frame.trimOffset.x : _frame.trimOffset.x;
    CGFloat oy=_flipY ? -_frame.trimOffset.y : _frame.trimOffset.y;
    CGFloat left=(self.contentSize.width-w)/2+ox, bottom=(self.contentSize.height-h)/2+oy;
    CGPoint points[4]={{left,bottom},{left+w,bottom},{left,bottom+h},{left+w,bottom+h}};
    CGSize pixels=_frame.texture.pixelSize;
    float u0=CGRectGetMinX(rect)/pixels.width,u1=CGRectGetMaxX(rect)/pixels.width;
    float v0=CGRectGetMinY(rect)/pixels.height,v1=CGRectGetMaxY(rect)/pixels.height;
    // Texture-packer clockwise rotation: bottom-left maps to stored top-left.
    CGPoint uv[4];
    if (_frame.rotated) { uv[0]=CGPointMake(u0,v0); uv[1]=CGPointMake(u0,v1); uv[2]=CGPointMake(u1,v0); uv[3]=CGPointMake(u1,v1); }
    else { uv[0]=CGPointMake(u0,v1); uv[1]=CGPointMake(u1,v1); uv[2]=CGPointMake(u0,v0); uv[3]=CGPointMake(u1,v0); }
    int order[6]={0,1,2,2,1,3};
    float alpha=_opacity/255.f;
    for (int i=0;i<6;i++) {
        int corner=order[i], sample=corner^(_flipX ? 1:0)^(_flipY ? 2:0);
        vertices[i]=(MRRenderVertex){points[corner].x,points[corner].y,uv[sample].x,uv[sample].y,
            _color.r/255.f*alpha,_color.g/255.f*alpha,_color.b/255.f*alpha,alpha};
    }
    return 6;
}
- (void)drawRegions:(const MRNormalizedRegion *)regions count:(NSUInteger)count context:(MRRenderContext *)context {
    MRRenderVertex quad[6]; if (![self writeLocalVertices:quad] || !count) return;
    NSParameterAssert(regions && count<=NSUIntegerMax/(6*sizeof(MRRenderVertex)));
    NSMutableData *data=[NSMutableData dataWithLength:count*6*sizeof(MRRenderVertex)];MRRenderVertex *out=data.mutableBytes;
    MRRenderVertex tl=quad[2],tr=quad[5],bl=quad[0];
    for(NSUInteger i=0;i<count;i++){
        MRNormalizedRegion r=regions[i];NSParameterAssert(r.minX>=0 && r.minY>=0 && r.maxX<=1 && r.maxY<=1 && r.minX<=r.maxX && r.minY<=r.maxY);
        float uv[12]={r.minX,r.minY,r.minX,r.maxY,r.maxX,r.minY,r.maxX,r.minY,r.minX,r.maxY,r.maxX,r.maxY};
        for(NSUInteger j=0;j<6;j++){float u=uv[j*2],v=uv[j*2+1];MRRenderVertex vertex=tl;
            vertex.x=tl.x+u*(tr.x-tl.x)+v*(bl.x-tl.x);vertex.y=tl.y+u*(tr.y-tl.y)+v*(bl.y-tl.y);
            vertex.u=tl.u+u*(tr.u-tl.u)+v*(bl.u-tl.u);vertex.v=tl.v+u*(tr.v-tl.v)+v*(bl.v-tl.v);out[i*6+j]=vertex;}
    }
    [context drawVertices:data.bytes count:count*6 texture:_frame.texture.identifier blend:_blend sampling:_sampling];
}
- (void)draw:(MRRenderContext *)context {
    NSAssert(!_frame || context==_frame.texture.context,@"A sprite must draw with its texture's context");
    MRRenderVertex vertices[6]; NSUInteger count=[self writeLocalVertices:vertices];
    if (count) [context drawVertices:vertices count:count texture:_frame.texture.identifier blend:_blend sampling:_sampling];
}
@end
