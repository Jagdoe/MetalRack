#pragma once
#import "MRUIKit.h"
@interface MRSceneTransition : MRNode
@property(nonatomic, readonly) MRNode *incomingScene;
@property(nonatomic, readonly) MRTime duration;
+ (instancetype)transitionWithDuration:(MRTime)duration scene:(MRNode *)scene;
/// Finish before a new scene operation interrupts an active transition.
- (void)completeTransition;
- (void)prepareOutgoing:(MRNode *)scene completion:(void (^)(void))completion;
@end
@interface MRFadeTransition : MRSceneTransition
+ (instancetype)transitionWithDuration:(MRTime)duration scene:(MRNode *)scene withColor:(MRColor3B)color;
@end
@interface MRCrossFadeTransition : MRSceneTransition
@end
