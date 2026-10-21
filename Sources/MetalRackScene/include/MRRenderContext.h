#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <stdbool.h>

// Values deliberately match Metal's blend-factor vocabulary, not OpenGL enums.
typedef enum {
    MRBlendZero=0, MRBlendOne=1, MRBlendSourceColor=2, MRBlendOneMinusSourceColor=3,
    MRBlendSourceAlpha=4, MRBlendOneMinusSourceAlpha=5, MRBlendDestinationColor=6,
    MRBlendOneMinusDestinationColor=7, MRBlendDestinationAlpha=8,
    MRBlendOneMinusDestinationAlpha=9, MRBlendSourceAlphaSaturated=10
} MRBlendFactor;
typedef struct { MRBlendFactor src, dst; } MRBlendFunction;
typedef struct { float x,y,u,v,r,g,b,a; } MRRenderVertex;
typedef struct { uint8_t r,g,b,a; } MRRenderColor;
typedef enum { MRFilterNearest=0, MRFilterLinear=1 } MRTextureFilter;
typedef enum { MRAddressClamp=0, MRAddressRepeat=1 } MRTextureAddress;
typedef struct {
    MRTextureFilter minFilter,magFilter;
    MRTextureAddress sAddress,tAddress;
} MRTextureSampling;
typedef struct {
    void *context;
    void (*beginFrame)(void *, CGSize);
    void (*present)(void *);
    void (*upload)(void *, uint32_t, int, int, const void *);
    void (*removeTexture)(void *, uint32_t);
    void (*generateMipmaps)(void *, uint32_t);
    void (*draw)(void *, const MRRenderVertex *, size_t, uint32_t,
                 MRBlendFunction, MRTextureSampling, CGRect, CGSize);
    void (*beginTarget)(void *, uint32_t, CGSize, bool, MRRenderColor);
    void (*endTarget)(void *);
    void (*read)(void *, uint32_t, CGRect, void *);
} MRRenderBackend;

// A logical-coordinate scene context. Nodes submit fully specified native
// geometry; there is no matrix mode, implicit texture binding or draw-state shim.
@interface MRRenderContext : NSObject
+ (instancetype)sharedContext;
@property(nonatomic, assign) CGSize logicalSize;
@property(nonatomic, readonly) CGAffineTransform transform;
@property(nonatomic, readonly) CGRect clipRect;
- (void)setBackend:(MRRenderBackend)backend;
- (void)beginFrameWithSize:(CGSize)size;
- (void)present;
- (void)pushTransform;
- (void)multiplyTransform:(CGAffineTransform)transform;
- (void)popTransform;
- (void)pushClipRect:(CGRect)rect;
- (void)popClipRect;
- (uint32_t)uploadWidth:(int)width height:(int)height rgba:(const void *)pixels;
- (void)removeTexture:(uint32_t)identifier;
- (void)generateMipmapsForTexture:(uint32_t)identifier;
- (void)replaceTexture:(uint32_t)identifier width:(int)width height:(int)height rgba:(const void *)pixels;
- (void)drawVertices:(const MRRenderVertex *)vertices count:(size_t)count
            texture:(uint32_t)texture blend:(MRBlendFunction)blend sampling:(MRTextureSampling)sampling;
- (void)beginTarget:(uint32_t)texture size:(CGSize)size clear:(BOOL)clear color:(MRRenderColor)color;
- (void)endTarget;
- (void)readTexture:(uint32_t)texture rect:(CGRect)rect rgba:(void *)pixels;
@end
