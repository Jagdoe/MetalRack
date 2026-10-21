#pragma once
#import "MRSprite.h"
#import "MRActionInterval.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSNotificationName const MRAnimationFrameDisplayedNotification;

@interface MRAnimationFrame : NSObject <NSCopying>
@property(nonatomic, readonly, strong) MRSpriteFrame *spriteFrame;
@property(nonatomic, readonly) MRTime delayUnits;
@property(nonatomic, readonly, copy, nullable) NSDictionary *userInfo;
- (instancetype)initWithSpriteFrame:(MRSpriteFrame *)frame delayUnits:(MRTime)units userInfo:(nullable NSDictionary *)userInfo;
@end

/// Immutable frame timing. Uniform animations wrap each sprite frame in one unit.
@interface MRAnimation : NSObject
@property(nonatomic, readonly, copy) NSArray<MRAnimationFrame *> *frames;
@property(nonatomic, readonly) MRTime totalDelayUnits;
@property(nonatomic, readonly) MRTime delayPerUnit;
@property(nonatomic, readonly) MRTime duration;
@property(nonatomic, assign) BOOL restoreOriginalFrame;
- (instancetype)initWithFrames:(NSArray<MRSpriteFrame *> *)frames delay:(MRTime)delay;
- (instancetype)initWithFrames:(NSArray<MRAnimationFrame *> *)frames delayPerUnit:(MRTime)delay;
+ (instancetype)animationWithFrames:(NSArray<MRSpriteFrame *> *)frames delay:(MRTime)delay;
+ (instancetype)animationWithFrames:(NSArray<MRAnimationFrame *> *)frames delayPerUnit:(MRTime)delay;
@end

@interface MRAnimate : MRActionInterval
@property(nonatomic, readonly, strong) MRAnimation *animation;
- (instancetype)initWithAnimation:(MRAnimation *)animation;
- (instancetype)initWithAnimation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore;
- (instancetype)initWithDuration:(MRTime)duration animation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore;
+ (instancetype)actionWithAnimation:(MRAnimation *)animation;
+ (instancetype)actionWithAnimation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore;
+ (instancetype)actionWithDuration:(MRTime)duration animation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore;
@end
NS_ASSUME_NONNULL_END
