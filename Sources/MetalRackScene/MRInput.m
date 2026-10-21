#import "MRInput.h"

@implementation MRPointerEvent
- (instancetype)initWithIdentifier:(NSUInteger)identifier position:(CGPoint)position
                 previousPosition:(CGPoint)previous timestamp:(NSTimeInterval)timestamp {
    NSParameterAssert(isfinite(position.x) && isfinite(position.y) &&
                      isfinite(previous.x) && isfinite(previous.y) && isfinite(timestamp));
    if ((self=[super init])) { _identifier=identifier; _position=position; _previousPosition=previous; _timestamp=timestamp; }
    return self;
}
- (CGPoint)locationInNode:(MRNode *)node { return [node convertToNodeSpace:_position]; }
- (CGPoint)previousLocationInNode:(MRNode *)node { return [node convertToNodeSpace:_previousPosition]; }
@end

@interface MRInputRegistration : NSObject
@property(nonatomic, weak) id<MRPointerReceiver> receiver;
@property(nonatomic) NSInteger priority;
@property(nonatomic) BOOL swallows;
@property(nonatomic) BOOL removed;
@property(nonatomic) NSUInteger order;
@end
@implementation MRInputRegistration
@end
@interface MRPointerCapture : NSObject
@property(nonatomic, strong) MRPointerEvent *event;
@property(nonatomic, strong) NSMutableArray<MRInputRegistration *> *receivers;
@end
@implementation MRPointerCapture
@end

@implementation MRInput {
    NSMutableArray<MRInputRegistration *> *_registrations;
    NSMutableDictionary<NSNumber *,MRPointerCapture *> *_captures;
    NSUInteger _order;
}
- (instancetype)init {
    if ((self=[super init])) {
        _enabled=YES; _registrations=[NSMutableArray array]; _captures=[NSMutableDictionary dictionary];
    }
    return self;
}
- (void)addReceiver:(id<MRPointerReceiver>)receiver priority:(NSInteger)priority swallows:(BOOL)swallows {
    NSParameterAssert(receiver);
    // Re-registration is explicit replacement and cancels old captures.
    [self removeReceiver:receiver];
    MRInputRegistration *entry=[MRInputRegistration new];
    entry.receiver=receiver; entry.priority=priority; entry.swallows=swallows; entry.order=_order++;
    [_registrations addObject:entry];
    [_registrations sortUsingComparator:^NSComparisonResult(MRInputRegistration *a,MRInputRegistration *b) {
        if (a.priority!=b.priority) return a.priority<b.priority ? NSOrderedAscending : NSOrderedDescending;
        return a.order<b.order ? NSOrderedAscending : (a.order>b.order ? NSOrderedDescending : NSOrderedSame);
    }];
}
- (void)removeReceiver:(id<MRPointerReceiver>)receiver {
    if (!receiver) return;
    for (MRInputRegistration *entry in [_registrations copy]) {
        if (entry.receiver!=receiver) continue;
        entry.removed=YES;
        [_registrations removeObjectIdenticalTo:entry];
        for (MRPointerCapture *capture in [_captures.allValues copy]) {
            if (![capture.receivers containsObject:entry]) continue;
            [capture.receivers removeObjectIdenticalTo:entry];
            if ([receiver respondsToSelector:@selector(pointerCancelled:)]) [receiver pointerCancelled:capture.event];
        }
    }
}
- (void)setEnabled:(BOOL)enabled {
    if (_enabled==enabled) return;
    _enabled=enabled;
    if (!enabled) [self cancelAllPointers];
}
- (void)beginPointer:(MRPointerEvent *)event {
    NSParameterAssert(event);
    if (!_enabled) return;
    NSNumber *key=@(event.identifier);
    // Reused platform IDs must not leave an old capture alive.
    if (_captures[key]) [self cancelPointer:_captures[key].event];
    if (!_enabled) return;
    MRPointerCapture *capture=[MRPointerCapture new];
    capture.event=event; capture.receivers=[NSMutableArray array]; _captures[key]=capture;
    for (MRInputRegistration *entry in [_registrations copy]) {
        if (!_enabled || _captures[key]!=capture) break;
        id<MRPointerReceiver> receiver=entry.receiver;
        if (!receiver || entry.removed) continue;
        BOOL claimed=[receiver pointerBegan:event];
        // A begin callback may remove itself, cancel the pointer or disable input.
        if (claimed && (entry.removed || !_enabled || _captures[key]!=capture)) {
            if ([receiver respondsToSelector:@selector(pointerCancelled:)]) [receiver pointerCancelled:event];
            continue;
        }
        if (claimed) { [capture.receivers addObject:entry]; if (entry.swallows) break; }
    }
    [_registrations filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MRInputRegistration *entry,NSDictionary *bindings) {
        return entry.receiver!=nil && !entry.removed;
    }]];
}
- (void)movePointer:(MRPointerEvent *)event {
    MRPointerCapture *capture=_captures[@(event.identifier)];
    if (!_enabled || !capture) return;
    capture.event=event;
    for (MRInputRegistration *entry in [capture.receivers copy]) {
        if (!_enabled || _captures[@(event.identifier)]!=capture) break;
        id<MRPointerReceiver> receiver=entry.receiver;
        if (!entry.removed && [capture.receivers containsObject:entry] && [receiver respondsToSelector:@selector(pointerMoved:)])
            [receiver pointerMoved:event];
    }
}
- (void)finishPointer:(MRPointerEvent *)event cancelled:(BOOL)cancelled {
    NSNumber *key=@(event.identifier);
    MRPointerCapture *capture=_captures[key];
    if (!capture) return;
    [_captures removeObjectForKey:key]; capture.event=event;
    // Remove the capture before callbacks so reentrant cancellation cannot deliver
    // a second terminal event, and a new begin with this ID survives.
    for (MRInputRegistration *entry in [capture.receivers copy]) {
        id<MRPointerReceiver> receiver=entry.receiver;
        if (entry.removed || ![capture.receivers containsObject:entry]) continue;
        if (cancelled) {
            if ([receiver respondsToSelector:@selector(pointerCancelled:)]) [receiver pointerCancelled:event];
        } else if ([receiver respondsToSelector:@selector(pointerEnded:)]) [receiver pointerEnded:event];
    }
}
- (void)endPointer:(MRPointerEvent *)event { [self finishPointer:event cancelled:NO]; }
- (void)cancelPointer:(MRPointerEvent *)event { [self finishPointer:event cancelled:YES]; }
- (void)cancelAllPointers {
    for (MRPointerCapture *capture in [_captures.allValues copy]) {
        // A callback may start a different capture with the same ID.
        if (_captures[@(capture.event.identifier)]==capture) [self cancelPointer:capture.event];
    }
}
@end
