/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2008-2011 Ricardo Quesada
 * Copyright (c) 2011 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */
#import "MRAnimation.h"
NSNotificationName const MRAnimationFrameDisplayedNotification=@"MRAnimationFrameDisplayedNotification";
@implementation MRAnimationFrame
- (instancetype)initWithSpriteFrame:(MRSpriteFrame *)frame delayUnits:(MRTime)units userInfo:(NSDictionary *)userInfo {
    NSParameterAssert(frame && isfinite(units) && units>=0);
    if ((self=[super init])) { _spriteFrame=frame; _delayUnits=units; _userInfo=[userInfo copy]; }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithSpriteFrame:_spriteFrame delayUnits:_delayUnits userInfo:_userInfo];
}
@end
@implementation MRAnimation
- (instancetype)initWithFrames:(NSArray<MRSpriteFrame *> *)frames delay:(MRTime)delay {
    NSMutableArray *timed=[NSMutableArray arrayWithCapacity:frames.count];
    for (MRSpriteFrame *frame in frames) [timed addObject:[[MRAnimationFrame alloc] initWithSpriteFrame:frame delayUnits:1 userInfo:nil]];
    return [self initWithFrames:timed delayPerUnit:delay];
}
- (instancetype)initWithFrames:(NSArray<MRAnimationFrame *> *)frames delayPerUnit:(MRTime)delay {
    NSParameterAssert(frames.count && isfinite(delay) && delay>=0);
    if ((self=[super init])) {
        _frames=[frames copy]; _delayPerUnit=delay;
        for (MRAnimationFrame *frame in _frames) _totalDelayUnits+=frame.delayUnits;
        NSParameterAssert(isfinite(_totalDelayUnits) && _totalDelayUnits>0);
        _duration=_totalDelayUnits*delay;
        NSParameterAssert(isfinite(_duration));
    }
    return self;
}
+ (instancetype)animationWithFrames:(NSArray<MRSpriteFrame *> *)frames delay:(MRTime)delay {
    return [[self alloc] initWithFrames:frames delay:delay];
}
+ (instancetype)animationWithFrames:(NSArray<MRAnimationFrame *> *)frames delayPerUnit:(MRTime)delay {
    return [[self alloc] initWithFrames:frames delayPerUnit:delay];
}
@end
@implementation MRAnimate {
    NSArray<NSNumber *> *_splitTimes;
    NSUInteger _nextFrame;
    MRSpriteFrame *_originalFrame;
    BOOL _restoreOriginalFrame;
}
- (instancetype)initWithAnimation:(MRAnimation *)animation {
    return [self initWithAnimation:animation restoreOriginalFrame:animation.restoreOriginalFrame];
}
- (instancetype)initWithAnimation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore {
    return [self initWithDuration:animation.duration animation:animation restoreOriginalFrame:restore];
}
- (instancetype)initWithDuration:(MRTime)duration animation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore {
    NSParameterAssert(animation && isfinite(duration) && duration>=0);
    if ((self=[super initWithDuration:duration])) {
        _animation=animation; _restoreOriginalFrame=restore;
        NSMutableArray *times=[NSMutableArray arrayWithCapacity:animation.frames.count];
        MRTime accumulated=0, unitTime=duration_/animation.totalDelayUnits;
        for (MRAnimationFrame *frame in animation.frames) {
            [times addObject:@((accumulated*unitTime)/duration_)]; accumulated+=frame.delayUnits;
        }
        _splitTimes=[times copy];
    }
    return self;
}
+ (instancetype)actionWithAnimation:(MRAnimation *)animation { return [[self alloc] initWithAnimation:animation]; }
+ (instancetype)actionWithAnimation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore {
    return [[self alloc] initWithAnimation:animation restoreOriginalFrame:restore];
}
+ (instancetype)actionWithDuration:(MRTime)duration animation:(MRAnimation *)animation restoreOriginalFrame:(BOOL)restore {
    return [[self alloc] initWithDuration:duration animation:animation restoreOriginalFrame:restore];
}
- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithDuration:duration_ animation:_animation restoreOriginalFrame:_restoreOriginalFrame];
}
- (void)startWithTarget:(id)target {
    NSParameterAssert([target isKindOfClass:[MRSprite class]]);
    [super startWithTarget:target];
    _originalFrame=_restoreOriginalFrame ? [(MRSprite *)target frame] : nil;
    _nextFrame=0;
}
- (void)stop {
    if (_restoreOriginalFrame) [(MRSprite *)target_ setFrame:_originalFrame];
    [super stop];
}
- (void)update:(MRTime)time {
    for (NSUInteger i=_nextFrame;i<_animation.frames.count;i++) {
        if (_splitTimes[i].floatValue<=time) {
            MRAnimationFrame *frame=_animation.frames[i];
            [(MRSprite *)target_ setFrame:frame.spriteFrame];
            if (frame.userInfo) [[NSNotificationCenter defaultCenter] postNotificationName:MRAnimationFrameDisplayedNotification object:target_ userInfo:frame.userInfo];
            _nextFrame=i+1;
            // Retain the established effect cadence: one newly reached frame
            // per update, even after a long frame, rather than skipping images.
            break;
        }
    }
}
- (MRActionInterval *)reverse {
    NSMutableArray *frames=[NSMutableArray arrayWithCapacity:_animation.frames.count];
    for (MRAnimationFrame *frame in [_animation.frames reverseObjectEnumerator]) [frames addObject:[frame copy]];
    MRAnimation *reversed=[[MRAnimation alloc] initWithFrames:frames delayPerUnit:_animation.delayPerUnit];
    return [[[self class] alloc] initWithDuration:duration_ animation:reversed restoreOriginalFrame:_restoreOriginalFrame];
}
@end
