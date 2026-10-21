#pragma once
#import "MetalRackScene.h"
#ifndef MR_PARTICLE_COLOR_TYPE
#define MR_PARTICLE_COLOR_TYPE
typedef struct { float r,g,b,a; } MRColor4F;
#endif
typedef NS_ENUM(NSInteger,MRParticlePosition) { MRParticlePositionFree,MRParticlePositionRelative,MRParticlePositionGrouped };
typedef NS_ENUM(NSInteger,MRParticleAnimation) { MRParticleAnimationLoop,MRParticleAnimationRandomStart,MRParticleAnimationOnce,MRParticleAnimationRandomFrame };
enum { MRParticleModeGravity,MRParticleModeRadius };
enum { MRParticleDurationInfinite=-1,MRParticleSizeUnchanged=-1,MRParticleRadiusUnchanged=-1 };
@interface MRParticles : MRNode
@property (nonatomic,readonly) BOOL active;
@property (nonatomic,readonly) NSUInteger	particleCount;
@property (nonatomic,readwrite,assign) float duration;
@property (nonatomic,readwrite,assign) CGPoint sourcePosition;
@property (nonatomic,readwrite,assign) CGPoint posVar;
@property (nonatomic,readwrite,assign) float life;
@property (nonatomic,readwrite,assign) float lifeVar;
@property (nonatomic,readwrite,assign) float angle;
@property (nonatomic,readwrite,assign) float angleVar;
@property (nonatomic,readwrite,assign) CGPoint gravity;
@property (nonatomic,readwrite,assign) float speed;
@property (nonatomic,readwrite,assign) float speedVar;
@property (nonatomic,readwrite,assign) float tangentialAccel;
@property (nonatomic,readwrite,assign) float tangentialAccelVar;
@property (nonatomic,readwrite,assign) float radialAccel;
@property (nonatomic,readwrite,assign) float radialAccelVar;
@property (nonatomic,readwrite,assign) float startRadius;
@property (nonatomic,readwrite,assign) float startRadiusVar;
@property (nonatomic,readwrite,assign) float endRadius;
@property (nonatomic,readwrite,assign) float endRadiusVar;
@property (nonatomic,readwrite,assign) float rotatePerSecond;
@property (nonatomic,readwrite,assign) float rotatePerSecondVar;
@property (nonatomic,readwrite,assign) float startSize;
@property (nonatomic,readwrite,assign) float startSizeVar;
@property (nonatomic,readwrite,assign) float endSize;
@property (nonatomic,readwrite,assign) float endSizeVar;
@property (nonatomic,readwrite,assign) float startScale;
@property (nonatomic,readwrite,assign) float startScaleVar;
@property (nonatomic,readwrite,assign) float endScale;
@property (nonatomic,readwrite,assign) float endScaleVar;
@property (nonatomic,readwrite,assign) MRColor4F startColor;
@property (nonatomic,readwrite,assign) MRColor4F startColorVar;
@property (nonatomic,readwrite,assign) MRColor4F endColor;
@property (nonatomic,readwrite,assign) MRColor4F endColorVar;
@property (nonatomic,readwrite,assign) float startSpin;
@property (nonatomic,readwrite,assign) float startSpinVar;
@property (nonatomic,readwrite,assign) float endSpin;
@property (nonatomic,readwrite,assign) float endSpinVar;
@property (nonatomic,readwrite,assign) float emissionRate;
@property (nonatomic,readwrite,assign) NSUInteger totalParticles;
@property (nonatomic,readwrite, strong) MRTexture * texture;
@property (nonatomic,readwrite) MRBlendFunction blendFunc;
@property (nonatomic,readwrite) BOOL blendAdditive;
@property (nonatomic,readwrite) MRParticlePosition positionType;
@property (nonatomic,readwrite) BOOL autoRemoveOnFinish;
@property (nonatomic,readwrite) NSInteger emitterMode;
@property (nonatomic,readwrite) MRParticleAnimation animationType;
@property(nonatomic, strong) MRAnimation *animation;
+ (instancetype)particleWithFile:(NSString *)file;
- (instancetype)initWithFile:(NSString *)file;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithTotalParticles:(NSUInteger)number;
- (void)stopSystem;
- (void)resetSystem;
- (BOOL)isFull;
- (void)updateWithNoTime;
@end
