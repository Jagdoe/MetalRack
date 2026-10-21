#pragma once
#import "MRNode.h"

NS_ASSUME_NONNULL_BEGIN
/// Immutable platform-neutral pointer sample in scene points (y-up).
@interface MRPointerEvent : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property(nonatomic, readonly) NSUInteger identifier;
@property(nonatomic, readonly) CGPoint position;
@property(nonatomic, readonly) CGPoint previousPosition;
@property(nonatomic, readonly) NSTimeInterval timestamp;
- (instancetype)initWithIdentifier:(NSUInteger)identifier position:(CGPoint)position
                 previousPosition:(CGPoint)previous timestamp:(NSTimeInterval)timestamp;
- (CGPoint)locationInNode:(MRNode *)node;
- (CGPoint)previousLocationInNode:(MRNode *)node;
@end

@protocol MRPointerReceiver <NSObject>
/// Returning YES captures this pointer until end/cancel/removal. A swallowing
/// registration stops later receivers only when it captures the begin event.
- (BOOL)pointerBegan:(MRPointerEvent *)event;
@optional
- (void)pointerMoved:(MRPointerEvent *)event;
- (void)pointerEnded:(MRPointerEvent *)event;
- (void)pointerCancelled:(MRPointerEvent *)event;
@end

/// Native pointer capture, independent of UIKit/Cocos. Lower priorities receive
/// begin events first; ties retain registration order. Receivers are weak, so scene
/// ownership is explicit. Callback registration/removal takes effect safely.
@interface MRInput : NSObject
@property(nonatomic, getter=isEnabled) BOOL enabled;
- (void)addReceiver:(id<MRPointerReceiver>)receiver priority:(NSInteger)priority swallows:(BOOL)swallows NS_SWIFT_NAME(add(receiver:priority:swallows:));
/// Cancels this receiver's active captures before removal.
- (void)removeReceiver:(id<MRPointerReceiver>)receiver NS_SWIFT_NAME(remove(receiver:));
- (void)beginPointer:(MRPointerEvent *)event NS_SWIFT_NAME(begin(_:));
- (void)movePointer:(MRPointerEvent *)event NS_SWIFT_NAME(move(_:));
- (void)endPointer:(MRPointerEvent *)event NS_SWIFT_NAME(end(_:));
- (void)cancelPointer:(MRPointerEvent *)event NS_SWIFT_NAME(cancel(_:));
/// Host calls this on focus loss/scene replacement. Disabling also cancels.
- (void)cancelAllPointers;
@end
NS_ASSUME_NONNULL_END
