#pragma once
#import "MRNode.h"
#import "MRActionTypes.h"
/// Node-owned registrations use weak callback relays. They suspend on scene exit
/// and resume with accumulated timer state when reattached to the same driver.
@interface MRNode (Scheduling)
- (void)schedule:(SEL)selector;
- (void)schedule:(SEL)selector interval:(MRTime)interval;
- (void)unschedule:(SEL)selector;
- (void)scheduleUpdate;
- (void)scheduleUpdateWithPriority:(NSInteger)priority;
- (void)unscheduleUpdate;
- (void)unscheduleAllSelectors;
- (void)pauseSceneCallbacks;
- (void)resumeSceneCallbacks;
- (void)update:(MRTime)seconds;
@end
