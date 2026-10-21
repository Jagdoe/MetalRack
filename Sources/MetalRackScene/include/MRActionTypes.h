#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <float.h>
#include <math.h>
typedef float MRTime;
typedef struct { uint8_t r,g,b; } MRColor3B;
static inline MRColor3B MRColor3BMake(uint8_t r,uint8_t g,uint8_t b) { return (MRColor3B){r,g,b}; }
static inline CGPoint MRPointAdd(CGPoint a,CGPoint b) { return CGPointMake(a.x+b.x,a.y+b.y); }
static inline CGPoint MRPointSub(CGPoint a,CGPoint b) { return CGPointMake(a.x-b.x,a.y-b.y); }
static inline CGPoint MRPointNeg(CGPoint a) { return CGPointMake(-a.x,-a.y); }
static inline CGPoint MRPointMult(CGPoint a,CGFloat s) { return CGPointMake(a.x*s,a.y*s); }
#define MR_ACTION_LOG(...) ((void)0)
@protocol MRRGBAProtocol <NSObject>
@property(nonatomic, assign) MRColor3B color;
@property(nonatomic, assign) uint8_t opacity;
@end
