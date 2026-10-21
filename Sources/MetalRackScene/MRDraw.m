#import "MRDraw.h"
#include <math.h>
void MRDrawLine(MRRenderContext *context,CGPoint a,CGPoint b,CGFloat width,MRRenderColor color) {
    CGFloat length=hypot(b.x-a.x,b.y-a.y);if(length<=0||width<=0||!color.a)return;
    CGFloat dx=-(b.y-a.y)/length*width*.5,dy=(b.x-a.x)/length*width*.5;
    CGPoint points[4]={{a.x+dx,a.y+dy},{b.x+dx,b.y+dy},{a.x-dx,a.y-dy},{b.x-dx,b.y-dy}};
    int order[6]={0,1,2,2,1,3};MRRenderVertex vertices[6];float alpha=color.a/255.f;
    for(int i=0;i<6;i++){CGPoint p=points[order[i]];vertices[i]=(MRRenderVertex){p.x,p.y,0,0,color.r/255.f*alpha,color.g/255.f*alpha,color.b/255.f*alpha,alpha};}
    [context drawVertices:vertices count:6 texture:0 blend:(MRBlendFunction){MRBlendOne,MRBlendOneMinusSourceAlpha} sampling:(MRTextureSampling){MRFilterNearest,MRFilterNearest,MRAddressClamp,MRAddressClamp}];
}
void MRDrawCircle(MRRenderContext *context,CGPoint center,CGFloat radius,CGFloat angle,NSUInteger segments,BOOL radial,CGFloat width,MRRenderColor color) {
    NSCParameterAssert(segments>=3 && isfinite(radius) && radius>=0);CGPoint last={center.x+cos(angle)*radius,center.y+sin(angle)*radius};
    CGPoint first=last;for(NSUInteger i=1;i<=segments;i++){CGFloat a=angle+2*M_PI*i/segments;CGPoint next={center.x+cos(a)*radius,center.y+sin(a)*radius};MRDrawLine(context,last,next,width,color);last=next;}
    if(radial)MRDrawLine(context,center,first,width,color);
}
