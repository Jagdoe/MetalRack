#pragma once
#import "MRActionTypes.h"

/// Serial scene-clock scheduling. Callbacks have the signature -(void)tick:(MRTime)dt.
/// Targets stay alive until explicitly unscheduled. No wall-clock timers or
/// application run-loop policy are embedded in the scheduler.
@interface MRScheduler : NSObject
@property(nonatomic, assign) MRTime timeScale;
+ (instancetype)sharedScheduler;
- (void)scheduleUpdateForTarget:(id)target priority:(NSInteger)priority paused:(BOOL)paused NS_SWIFT_NAME(scheduleUpdate(target:priority:paused:));
- (void)unscheduleUpdateForTarget:(id)target;
- (void)scheduleSelector:(SEL)selector forTarget:(id)target interval:(MRTime)interval paused:(BOOL)paused NS_SWIFT_NAME(schedule(_:target:interval:paused:));
/// repeat is the number of additional invocations; NSUIntegerMax means forever.
- (void)scheduleSelector:(SEL)selector forTarget:(id)target interval:(MRTime)interval
                 repeat:(NSUInteger)repeat delay:(MRTime)delay paused:(BOOL)paused NS_SWIFT_NAME(schedule(_:target:interval:repeat:delay:paused:));
- (void)unscheduleSelector:(SEL)selector forTarget:(id)target NS_SWIFT_NAME(unschedule(_:target:));
- (void)unscheduleAllForTarget:(id)target NS_SWIFT_NAME(unscheduleAll(target:));
- (void)pauseTarget:(id)target NS_SWIFT_NAME(pause(target:));
- (void)resumeTarget:(id)target NS_SWIFT_NAME(resume(target:));
- (BOOL)isTargetPaused:(id)target;
- (void)tick:(MRTime)seconds;
@end
