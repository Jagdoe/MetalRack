#pragma once
#import "MRActionTypes.h"
#import "MRAction.h"
#import "MRActionInterval.h"
#import "MRActionInstant.h"
#import "MRSprite.h"
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





/** An interval action is an action that takes place within a certain period of time.
It has an start time, and a finish time. The finish time is the parameter
duration plus the start time.

These MRActionInterval actions have some interesting properties, like:
 - They can run normally (default)
 - They can run reversed with the reverse method
 - They can run with the time altered with the Accelerate, AccelDeccel and Speed actions.

For example, you can simulate a Ping Pong effect running the action normally and
then running it again in Reverse mode.

Example:

	MRAction * pingPongAction = [MRSequence actions: action, [action reverse], nil];
*/
@interface MRActionInterval: MRFiniteTimeAction <NSCopying>
{
	MRTime	elapsed_;
	BOOL	firstTick_;
}

/** how many seconds had elapsed since the actions started to run. */
@property (nonatomic,readonly) MRTime elapsed;

/** creates the action */
+(id) actionWithDuration: (MRTime) d;
/** initializes the action */
-(id) initWithDuration: (MRTime) d;
/** returns YES if the action has finished */
-(BOOL) isDone;
/** returns a reversed action */
- (MRActionInterval*) reverse;
@end

/** Runs actions sequentially, one after another
 */
@interface MRSequence : MRActionInterval <NSCopying>
{
	MRFiniteTimeAction *actions_[2];
	MRTime split_;
	int last_;
}
/** helper contructor to create an array of sequenceable actions */
+(id) actions: (MRFiniteTimeAction*) action1, ... NS_REQUIRES_NIL_TERMINATION;
/** helper contructor to create an array of sequenceable actions given an array */
+(id) actionsWithArray: (NSArray*) actions;
/** creates the action */
+(id) actionOne:(MRFiniteTimeAction*)actionOne two:(MRFiniteTimeAction*)actionTwo;
/** initializes the action */
-(id) initOne:(MRFiniteTimeAction*)actionOne two:(MRFiniteTimeAction*)actionTwo;
@end


/** Repeats an action a number of times.
 * To repeat an action forever use the MRRepeatForever action.
 */
@interface MRRepeat : MRActionInterval <NSCopying>
{
	NSUInteger times_;
	NSUInteger total_;
	MRTime nextDt_;
	BOOL isActionInstant_;
	MRFiniteTimeAction *innerAction_;
}

/** Inner action */
@property (nonatomic,readwrite,retain) MRFiniteTimeAction *innerAction;

/** creates a MRRepeat action. Times is an unsigned integer between 1 and MAX_UINT */
+(id) actionWithAction:(MRFiniteTimeAction*)action times: (NSUInteger)times;
/** initializes a MRRepeat action. Times is an unsigned integer between 1 and MAX_UINT */
-(id) initWithAction:(MRFiniteTimeAction*)action times: (NSUInteger)times;
@end

/** Spawn a new action immediately
 */
@interface MRSpawn : MRActionInterval <NSCopying>
{
	MRFiniteTimeAction *one_;
	MRFiniteTimeAction *two_;
}
/** helper constructor to create an array of spawned actions */
+(id) actions: (MRFiniteTimeAction*) action1, ... NS_REQUIRES_NIL_TERMINATION;
/** helper contructor to create an array of spawned actions given an array */
+(id) actionsWithArray: (NSArray*) actions;
/** creates the Spawn action */
+(id) actionOne: (MRFiniteTimeAction*) one two:(MRFiniteTimeAction*) two;
/** initializes the Spawn action with the 2 actions to spawn */
-(id) initOne: (MRFiniteTimeAction*) one two:(MRFiniteTimeAction*) two;
@end

/**  Rotates a MRNode object to a certain angle by modifying it's
 rotation attribute.
 The direction will be decided by the shortest angle.
*/
@interface MRRotateTo : MRActionInterval <NSCopying>
{
	float dstAngle_;
	float startAngle_;
	float diffAngle_;
}
/** creates the action */
+(id) actionWithDuration:(MRTime)duration angle:(float)angle;
/** initializes the action */
-(id) initWithDuration:(MRTime)duration angle:(float)angle;
@end

/** Rotates a MRNode object clockwise a number of degrees by modiying it's rotation attribute.
*/
@interface MRRotateBy : MRActionInterval <NSCopying>
{
	float angle_;
	float startAngle_;
}
/** creates the action */
+(id) actionWithDuration:(MRTime)duration angle:(float)deltaAngle;
/** initializes the action */
-(id) initWithDuration:(MRTime)duration angle:(float)deltaAngle;
@end

/** Moves a MRNode object to the position x,y. x and y are absolute coordinates by modifying it's position attribute.
*/
@interface MRMoveTo : MRActionInterval <NSCopying>
{
	CGPoint endPosition_;
	CGPoint startPosition_;
	CGPoint delta_;
}
/** creates the action */
+(id) actionWithDuration:(MRTime)duration position:(CGPoint)position;
/** initializes the action */
-(id) initWithDuration:(MRTime)duration position:(CGPoint)position;
@end

/**  Moves a MRNode object x,y pixels by modifying it's position attribute.
 x and y are relative to the position of the object.
 Duration is is seconds.
*/
@interface MRMoveBy : MRMoveTo <NSCopying>
{
}
/** creates the action */
+(id) actionWithDuration: (MRTime)duration position:(CGPoint)deltaPosition;
/** initializes the action */
-(id) initWithDuration: (MRTime)duration position:(CGPoint)deltaPosition;
@end

/** Skews a MRNode object to given angles by modifying it's skewX and skewY attributes
 @since v1.0
 */
@interface MRSkewTo : MRActionInterval <NSCopying>
{
	float skewX_;
	float skewY_;
	float startSkewX_;
	float startSkewY_;
	float endSkewX_;
	float endSkewY_;
	float deltaX_;
	float deltaY_;
}
/** creates the action */
+(id) actionWithDuration:(MRTime)t skewX:(float)sx skewY:(float)sy;
/** initializes the action */
-(id) initWithDuration:(MRTime)t skewX:(float)sx skewY:(float)sy;
@end

/** Skews a MRNode object by skewX and skewY degrees
 @since v1.0
 */
@interface MRSkewBy : MRSkewTo <NSCopying>
{
}
@end

/** Moves a MRNode object simulating a parabolic jump movement by modifying it's position attribute.
*/
 @interface MRJumpBy : MRActionInterval <NSCopying>
{
	CGPoint startPosition_;
	CGPoint delta_;
	MRTime height_;
	NSUInteger jumps_;
}
/** creates the action */
+(id) actionWithDuration: (MRTime)duration position:(CGPoint)position height:(MRTime)height jumps:(NSUInteger)jumps;
/** initializes the action */
-(id) initWithDuration: (MRTime)duration position:(CGPoint)position height:(MRTime)height jumps:(NSUInteger)jumps;
@end

/** Moves a MRNode object to a parabolic position simulating a jump movement by modifying it's position attribute.
*/
 @interface MRJumpTo : MRJumpBy <NSCopying>
{
}
@end

/** bezier configuration structure
 */
typedef struct _MRBezierConfig {
	//! end position of the bezier
	CGPoint endPosition;
	//! Bezier control point 1
	CGPoint controlPoint_1;
	//! Bezier control point 2
	CGPoint controlPoint_2;
} MRBezierConfig;

/** An action that moves the target with a cubic Bezier curve by a certain distance.
 */
@interface MRBezierBy : MRActionInterval <NSCopying>
{
	MRBezierConfig config_;
	CGPoint startPosition_;
}

/** creates the action with a duration and a bezier configuration */
+(id) actionWithDuration: (MRTime) t bezier:(MRBezierConfig) c;

/** initializes the action with a duration and a bezier configuration */
-(id) initWithDuration: (MRTime) t bezier:(MRBezierConfig) c;
@end

/** An action that moves the target with a cubic Bezier curve to a destination point.
 @since v0.8.2
 */
@interface MRBezierTo : MRBezierBy
{
}
@end

/** Scales a MRNode object to a zoom factor by modifying it's scale attribute.
 @warning This action doesn't support "reverse"
 */
@interface MRScaleTo : MRActionInterval <NSCopying>
{
	float scaleX_;
	float scaleY_;
	float startScaleX_;
	float startScaleY_;
	float endScaleX_;
	float endScaleY_;
	float deltaX_;
	float deltaY_;
}
/** creates the action with the same scale factor for X and Y */
+(id) actionWithDuration: (MRTime)duration scale:(float) s;
/** initializes the action with the same scale factor for X and Y */
-(id) initWithDuration: (MRTime)duration scale:(float) s;
/** creates the action with and X factor and a Y factor */
+(id) actionWithDuration: (MRTime)duration scaleX:(float) sx scaleY:(float)sy;
/** initializes the action with and X factor and a Y factor */
-(id) initWithDuration: (MRTime)duration scaleX:(float) sx scaleY:(float)sy;
@end

/** Scales a MRNode object a zoom factor by modifying it's scale attribute.
*/
@interface MRScaleBy : MRScaleTo <NSCopying>
{
}
@end

/** Blinks a MRNode object by modifying it's visible attribute
*/
@interface MRBlink : MRActionInterval <NSCopying>
{
	NSUInteger times_;
}
/** creates the action */
+(id) actionWithDuration: (MRTime)duration blinks:(NSUInteger)blinks;
/** initilizes the action */
-(id) initWithDuration: (MRTime)duration blinks:(NSUInteger)blinks;
@end

/** Fades In an object that implements the MRRGBAProtocol protocol. It modifies the opacity from 0 to 255.
 The "reverse" of this action is FadeOut
 */
@interface MRFadeIn : MRActionInterval <NSCopying>
{
}
@end

/** Fades Out an object that implements the MRRGBAProtocol protocol. It modifies the opacity from 255 to 0.
 The "reverse" of this action is FadeIn
*/
@interface MRFadeOut : MRActionInterval <NSCopying>
{
}
@end

/** Fades an object that implements the MRRGBAProtocol protocol. It modifies the opacity from the current value to a custom one.
 @warning This action doesn't support "reverse"
 */
@interface MRFadeTo : MRActionInterval <NSCopying>
{
	uint8_t toOpacity_;
	uint8_t fromOpacity_;
}
/** creates an action with duration and opactiy */
+(id) actionWithDuration:(MRTime)duration opacity:(uint8_t)opactiy;
/** initializes the action with duration and opacity */
-(id) initWithDuration:(MRTime)duration opacity:(uint8_t)opacity;
@end

/** Tints a MRNode that implements the MRNodeRGB protocol from current tint to a custom one.
 @warning This action doesn't support "reverse"
 @since v0.7.2
*/
@interface MRTintTo : MRActionInterval <NSCopying>
{
	MRColor3B to_;
	MRColor3B from_;
}
/** creates an action with duration and color */
+(id) actionWithDuration:(MRTime)duration red:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue;
/** initializes the action with duration and color */
-(id) initWithDuration:(MRTime)duration red:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue;
@end

/** Tints a MRNode that implements the MRNodeRGB protocol from current tint to a custom one.
 @since v0.7.2
 */
@interface MRTintBy : MRActionInterval <NSCopying>
{
	int16_t deltaR_, deltaG_, deltaB_;
	int16_t fromR_, fromG_, fromB_;
}
/** creates an action with duration and color */
+(id) actionWithDuration:(MRTime)duration red:(int16_t)deltaRed green:(int16_t)deltaGreen blue:(int16_t)deltaBlue;
/** initializes the action with duration and color */
-(id) initWithDuration:(MRTime)duration red:(int16_t)deltaRed green:(int16_t)deltaGreen blue:(int16_t)deltaBlue;
@end

/** Delays the action a certain amount of seconds
*/
@interface MRDelayTime : MRActionInterval <NSCopying>
{
}
@end

/** Executes an action in reverse order, from time=duration to time=0

 @warning Use this action carefully. This action is not
 sequenceable. Use it as the default "reversed" method
 of your own actions, but using it outside the "reversed"
 scope is not recommended.
*/
@interface MRReverseTime : MRActionInterval <NSCopying>
{
	MRFiniteTimeAction * other_;
}
/** creates the action */
+(id) actionWithAction: (MRFiniteTimeAction*) action;
/** initializes the action */
-(id) initWithAction: (MRFiniteTimeAction*) action;
@end


@class MRAnimation;
@class MRTexture2D;
/** Animates a sprite given the name of an Animation */


/** Overrides the target of an action so that it always runs on the target
 * specified at action creation rather than the one specified by runAction.
	@since 1.1
 */
@interface MRTargetedAction : MRActionInterval <NSCopying>
{
	id forcedTarget_;
	MRFiniteTimeAction* action_;
}
/** This is the target that the action will be forced to run with */
@property(readwrite,nonatomic,retain) id forcedTarget;

/** Create an action with the specified action and forced target */
+ (id) actionWithTarget:(id) target action:(MRFiniteTimeAction*) action;

/** Init an action with the specified action and forced target */
- (id) initWithTarget:(id) target action:(MRFiniteTimeAction*) action;

@end
