#import "MRScheduler.h"
#include <string.h>

typedef void (*MRClockCallback)(id,SEL,MRTime);
@interface MRClockEntry : NSObject
@property(nonatomic, strong) id target;
@property(nonatomic, assign) SEL selector;
@property(nonatomic, assign) MRClockCallback callback;
@property(nonatomic, assign) NSInteger priority;
@property(nonatomic, assign) BOOL paused;
@property(nonatomic, assign) MRTime interval;
@property(nonatomic, assign) MRTime elapsed;
@property(nonatomic, assign) MRTime delay;
@property(nonatomic, assign) NSUInteger repeat;
@property(nonatomic, assign) NSUInteger invocations;
@property(nonatomic, assign) BOOL waitingForDelay;
@end
@implementation MRClockEntry @end

@implementation MRScheduler {
    NSMutableArray<MRClockEntry *> *_updates, *_timers;
    BOOL _ticking;
}
+ (instancetype)sharedScheduler {
    static MRScheduler *scheduler;
    static dispatch_once_t once;
    dispatch_once(&once,^{ scheduler=[self new]; });
    return scheduler;
}
- (instancetype)init {
    if ((self=[super init])) { _updates=[NSMutableArray new]; _timers=[NSMutableArray new]; _timeScale=1; }
    return self;
}
- (MRClockEntry *)entryForTarget:(id)target selector:(SEL)selector {
    NSParameterAssert(target && selector);
    NSMethodSignature *signature=[target methodSignatureForSelector:selector];
    NSAssert(signature && signature.numberOfArguments==3 && !strcmp(signature.methodReturnType,@encode(void)) &&
        !strcmp([signature getArgumentTypeAtIndex:2],@encode(MRTime)),@"Clock callbacks must take one MRTime and return void");
    MRClockEntry *entry=[MRClockEntry new];
    entry.target=target; entry.selector=selector;
    entry.callback=(MRClockCallback)[target methodForSelector:selector];
    return entry;
}
- (void)scheduleUpdateForTarget:(id)target priority:(NSInteger)priority paused:(BOOL)paused {
    for (MRClockEntry *entry in _updates) if (entry.target==target) { entry.priority=priority; entry.paused=paused; return; }
    MRClockEntry *entry=[self entryForTarget:target selector:@selector(update:)];
    entry.priority=priority; entry.paused=paused; [_updates addObject:entry];
}
- (void)unscheduleUpdateForTarget:(id)target {
    for (MRClockEntry *entry in [_updates copy]) if (entry.target==target) [_updates removeObjectIdenticalTo:entry];
}
- (void)scheduleSelector:(SEL)selector forTarget:(id)target interval:(MRTime)interval paused:(BOOL)paused {
    [self scheduleSelector:selector forTarget:target interval:interval repeat:NSUIntegerMax delay:0 paused:paused];
}
- (void)scheduleSelector:(SEL)selector forTarget:(id)target interval:(MRTime)interval repeat:(NSUInteger)repeat delay:(MRTime)delay paused:(BOOL)paused {
    NSParameterAssert(isfinite(interval) && interval>=0 && isfinite(delay) && delay>=0);
    for (MRClockEntry *entry in _timers) if (entry.target==target && entry.selector==selector) {
        // Changing an existing interval preserves its accumulated elapsed time.
        entry.interval=interval; entry.paused=paused; return;
    }
    MRClockEntry *entry=[self entryForTarget:target selector:selector];
    entry.interval=interval; entry.elapsed=-1; entry.delay=delay;
    entry.waitingForDelay=delay>0; entry.repeat=repeat; entry.paused=paused;
    [_timers addObject:entry];
}
- (void)unscheduleSelector:(SEL)selector forTarget:(id)target {
    for (MRClockEntry *entry in [_timers copy]) if (entry.target==target && entry.selector==selector) [_timers removeObjectIdenticalTo:entry];
}
- (void)unscheduleAllForTarget:(id)target {
    [self unscheduleUpdateForTarget:target];
    for (MRClockEntry *entry in [_timers copy]) if (entry.target==target) [_timers removeObjectIdenticalTo:entry];
}
- (void)setTarget:(id)target paused:(BOOL)paused {
    for (MRClockEntry *entry in _updates) if (entry.target==target) entry.paused=paused;
    for (MRClockEntry *entry in _timers) if (entry.target==target) entry.paused=paused;
}
- (void)pauseTarget:(id)target { [self setTarget:target paused:YES]; }
- (void)resumeTarget:(id)target { [self setTarget:target paused:NO]; }
- (BOOL)isTargetPaused:(id)target {
    for (MRClockEntry *entry in _updates) if (entry.target==target) return entry.paused;
    for (MRClockEntry *entry in _timers) if (entry.target==target) return entry.paused;
    return NO;
}
- (void)tick:(MRTime)seconds {
    NSParameterAssert(isfinite(seconds) && seconds>=0 && isfinite(_timeScale) && _timeScale>=0 && isfinite(seconds*_timeScale));
    NSAssert(!_ticking,@"Scene clocks cannot tick recursively");
    _ticking=YES;
    @try {
        MRTime delta=seconds*_timeScale;
        NSArray *updates=[_updates sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(MRClockEntry *a,MRClockEntry *b) {
            return a.priority<b.priority ? NSOrderedAscending : a.priority>b.priority ? NSOrderedDescending : NSOrderedSame;
        }];
        NSArray *timers=[_timers copy];
        for (MRClockEntry *entry in updates) if (!entry.paused && [_updates containsObject:entry]) entry.callback(entry.target,entry.selector,delta);
        for (MRClockEntry *entry in timers) {
            if (entry.paused || ![_timers containsObject:entry]) continue;
            // The initial tick establishes the timer's origin without consuming
            // delta, matching existing game interval scheduling.
            if (entry.elapsed<0) { entry.elapsed=0; continue; }
            entry.elapsed+=delta;
            MRTime threshold=entry.waitingForDelay ? entry.delay : entry.interval;
            if (entry.elapsed<threshold) continue;
            entry.callback(entry.target,entry.selector,entry.elapsed);
            entry.elapsed=entry.waitingForDelay ? entry.elapsed-entry.delay : 0;
            entry.waitingForDelay=NO;
            if (entry.repeat!=NSUIntegerMax && ++entry.invocations>entry.repeat) [_timers removeObjectIdenticalTo:entry];
        }
    } @finally { _ticking=NO; }
}
@end
