#pragma once
#import "MRRenderContext.h"
FOUNDATION_EXPORT void MRDrawLine(MRRenderContext *context,CGPoint start,CGPoint end,CGFloat width,MRRenderColor color);
FOUNDATION_EXPORT void MRDrawCircle(MRRenderContext *context,CGPoint center,CGFloat radius,CGFloat angle,NSUInteger segments,BOOL radialLine,CGFloat width,MRRenderColor color);
