#import "MRSnapshot.h"
#include <MetalRackImageProcessing.h>
#include <limits.h>

MRTexture *MRCaptureNodes(NSArray<MRNode *> *nodes, MRRenderContext *context, CGRect bounds, CGFloat density) {
    NSCParameterAssert(nodes && context && isfinite(density) && density>0);
    CGFloat pw=ceil(bounds.size.width*density),ph=ceil(bounds.size.height*density);
    NSCParameterAssert(pw>0 && ph>0 && pw<=INT_MAX && ph<=INT_MAX);
    int width=(int)pw,height=(int)ph;
    NSCParameterAssert((size_t)width<=SIZE_MAX/4/(size_t)height);
    NSMutableData *pixels=[NSMutableData dataWithLength:(size_t)width*height*4];
    MRTexture *texture=([[MRTexture alloc] initWithContext:context width:width height:height rgba:pixels.bytes]);
    // Use the rounded pixel canvas in logical points to retain exact density.
    [context beginTarget:texture.identifier size:CGSizeMake(width/density,height/density) clear:YES color:(MRRenderColor){0,0,0,0}];
    [context multiplyTransform:CGAffineTransformMakeTranslation(-bounds.origin.x,-bounds.origin.y)];
    for (MRNode *node in nodes) [node visit:context];
    [context endTarget];
    return texture;
}
MRTexture *MRCaptureNode(MRNode *node,MRRenderContext *context,CGRect bounds,CGFloat density) {
    NSCParameterAssert(node);return MRCaptureNodes(@[node],context,bounds,density);
}
MRSprite *MRCreateNodeOutline(MRNode *node, MRRenderContext *context, CGPoint center, CGFloat density, CGFloat thickness) {
    NSCParameterAssert(isfinite(thickness) && thickness>=0 && isfinite(density) && density>0);
    CGRect bounds=CGRectApplyAffineTransform(node.subtreeBounds,node.nodeToParentTransform);
    CGFloat radius=ceil(thickness*density),pad=radius+2;
    CGFloat w=2*(ceil(MAX(fabs(CGRectGetMinX(bounds)-center.x),fabs(CGRectGetMaxX(bounds)-center.x))*density)+pad);
    CGFloat h=2*(ceil(MAX(fabs(CGRectGetMinY(bounds)-center.y),fabs(CGRectGetMaxY(bounds)-center.y))*density)+pad);
    NSCParameterAssert(w>0 && h>0 && w<=INT_MAX && h<=INT_MAX && radius<=INT_MAX);
    int width=(int)w,height=(int)h;
    NSCParameterAssert((size_t)width<=SIZE_MAX/4/(size_t)height);
    CGRect canvas=CGRectMake(center.x-w/(2*density),center.y-h/(2*density),w/density,h/density);
    MRTexture *capture=MRCaptureNode(node,context,canvas,density);
    NSMutableData *source=[NSMutableData dataWithLength:(size_t)width*height*4];
    [context readTexture:capture.identifier rect:CGRectMake(0,0,width,height) rgba:source.mutableBytes];
    NSMutableData *ring=[NSMutableData dataWithLength:source.length];
    MRCreateOutlineMask(source.bytes,width,height,(int)radius,ring.mutableBytes);
    MRTexture *texture=([[MRTexture alloc] initWithContext:context width:width height:height rgba:ring.bytes]);
    MRSpriteFrame *frame=([[MRSpriteFrame alloc] initWithTexture:texture pixelRect:CGRectMake(0,0,width,height)
        originalSize:canvas.size trimOffset:CGPointZero pixelsPerPoint:density rotated:NO]);
    MRSprite *outline=([[MRSprite alloc] initWithFrame:frame]);
    outline.position=center;
    outline.sampling=(MRTextureSampling){MRFilterNearest,MRFilterNearest,MRAddressClamp,MRAddressClamp};
    return outline;
}
MRSprite *MRCreateNodeSilhouette(MRNode *node,MRRenderContext *context,CGRect bounds,CGFloat density) {
    MRTexture *capture=MRCaptureNode(node,context,bounds,density);CGSize size=capture.pixelSize;
    NSMutableData *pixels=[NSMutableData dataWithLength:(NSUInteger)size.width*size.height*4];
    [context readTexture:capture.identifier rect:(CGRect){CGPointZero,size} rgba:pixels.mutableBytes];
    uint8_t *bytes=pixels.mutableBytes;for(NSUInteger i=0;i<pixels.length;i+=4)bytes[i]=bytes[i+1]=bytes[i+2]=bytes[i+3];
    [capture replaceRGBA:bytes];
    MRSprite *sprite=[[MRSprite alloc]initWithFrame:[[MRSpriteFrame alloc]initWithTexture:capture pixelRect:(CGRect){CGPointZero,size} originalSize:bounds.size trimOffset:CGPointZero pixelsPerPoint:density rotated:NO]];
    sprite.position=CGPointMake(CGRectGetMidX(bounds),CGRectGetMidY(bounds));return sprite;
}
MRSprite *MRCreateNodeHalo(MRNode *node,MRRenderContext *context,CGPoint center,CGFloat density,CGFloat thickness,NSUInteger limit,uint8_t step) {
    NSCParameterAssert(limit && isfinite(density) && density>0 && isfinite(thickness) && thickness>=0);
    CGRect bounds=CGRectApplyAffineTransform(node.subtreeBounds,node.nodeToParentTransform);
    CGFloat radius=ceil(thickness*density),pad=radius+2;
    CGFloat w=2*(ceil(MAX(fabs(CGRectGetMinX(bounds)-center.x),fabs(CGRectGetMaxX(bounds)-center.x))*density)+pad);
    CGFloat h=2*(ceil(MAX(fabs(CGRectGetMinY(bounds)-center.y),fabs(CGRectGetMaxY(bounds)-center.y))*density)+pad);
    NSCParameterAssert(w>0 && h>0 && w<=INT_MAX && h<=INT_MAX && radius<=INT_MAX);
    CGRect canvas=CGRectMake(center.x-w/(2*density),center.y-h/(2*density),w/density,h/density);
    MRTexture *capture=MRCaptureNode(node,context,canvas,density);
    int width=(int)w,height=(int)h,r=(int)radius;
    NSMutableData *pixels=[NSMutableData dataWithLength:(size_t)width*height*4],*output=[NSMutableData dataWithLength:pixels.length];
    [context readTexture:capture.identifier rect:CGRectMake(0,0,width,height) rgba:pixels.mutableBytes];
    const uint8_t *source=pixels.bytes;uint8_t *dest=output.mutableBytes;
    for(int y=0;y<height;y++)for(int x=0;x<width;x++){
        size_t index=((size_t)y*width+x)*4;if(source[index+3]==255)continue;NSUInteger count=0;
        for(int dx=-r;dx<=r && count<limit;dx++)for(int dy=-r;dy<=r && count<limit;dy++)
            if(dx*dx+dy*dy<=r*r && x+dx>=0 && y+dy>=0 && x+dx<width && y+dy<height && source[((size_t)(y+dy)*width+x+dx)*4+3]==255)count++;
        uint8_t alpha=(uint8_t)MIN((NSUInteger)255,count*step);dest[index]=dest[index+1]=dest[index+2]=dest[index+3]=alpha;
    }
    [capture replaceRGBA:output.bytes];MRSprite *sprite=[[MRSprite alloc]initWithFrame:[[MRSpriteFrame alloc]initWithTexture:capture pixelRect:CGRectMake(0,0,width,height) originalSize:canvas.size trimOffset:CGPointZero pixelsPerPoint:density rotated:NO]];
    sprite.position=center;return sprite;
}
