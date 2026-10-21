#pragma once
#import "MRNode.h"
#import "MRScheduler.h"
#import "MRSceneEnvironment.h"

NS_ASSUME_NONNULL_BEGIN
/// Native frame orchestration. Platform hosts supply elapsed time and size;
/// application lifecycle, game scene choices and save policy stay outside.
@interface MRSceneDriver : NSObject
@property(nonatomic, readonly, strong) MRRenderContext *context;
@property(nonatomic, readonly, strong) MRScheduler *scheduler;
@property(nonatomic, readonly, strong) MRSceneEnvironment *environment;
@property(nonatomic, strong, nullable) MRNode *scene;
/// Drawn above the scene, with the same native lifecycle and clock.
@property(nonatomic, strong, nullable) MRNode *overlay;
@property(nonatomic, assign) CGSize logicalSize;
@property(nonatomic, assign) BOOL paused;
- (instancetype)initWithContext:(MRRenderContext *)context scheduler:(MRScheduler *)scheduler;
- (instancetype)initWithContext:(MRRenderContext *)context scheduler:(MRScheduler *)scheduler input:(MRInput *)input;
- (void)step:(MRTime)seconds;
- (void)draw;
@end
NS_ASSUME_NONNULL_END
