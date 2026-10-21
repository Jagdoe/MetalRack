#pragma once
#import "MRRenderContext.h"
#import "MRScheduler.h"
#import "MRInput.h"
NS_ASSUME_NONNULL_BEGIN
/// Services belonging to one live scene driver. Nodes hold this weakly; the
/// driver owns it. Attachment/detachment controls callback and input lifetime.
@interface MRSceneEnvironment : NSObject
@property(nonatomic, readonly, strong) MRRenderContext *context;
@property(nonatomic, readonly, strong) MRScheduler *scheduler;
@property(nonatomic, readonly, strong) MRInput *input;
- (instancetype)initWithContext:(MRRenderContext *)context scheduler:(MRScheduler *)scheduler input:(MRInput *)input;
@end
NS_ASSUME_NONNULL_END
