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








//
// IntervalAction
//
#pragma mark -
#pragma mark IntervalAction
@implementation MRActionInterval

@synthesize elapsed = elapsed_;

-(id) init
{
	NSAssert(NO, @"IntervalActionInit: Init not supported. Use InitWithDuration");

	return nil;
}

+(id) actionWithDuration: (MRTime) d
{
	return ([[self alloc] initWithDuration:d ]);
}

-(id) initWithDuration: (MRTime) d
{
	if( (self=[super init]) ) {
		duration_ = d;

		// prevent division by 0
		// This comparison could be in step:, but it might decrease the performance
		// by 3% in heavy based action games.
		if( duration_ == 0 )
			duration_ = FLT_EPSILON;
		elapsed_ = 0;
		firstTick_ = YES;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration: [self duration] ];
	return copy;
}

- (BOOL) isDone
{
	return (elapsed_ >= duration_);
}

-(void) step: (MRTime) dt
{
	if( firstTick_ ) {
		firstTick_ = NO;
		elapsed_ = 0;
	} else
		elapsed_ += dt;

	[self update: MIN(1, elapsed_/MAX(duration_,FLT_EPSILON))];
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	elapsed_ = 0.0f;
	firstTick_ = YES;
}

- (MRActionInterval*) reverse
{
	NSAssert(NO, @"MRIntervalAction: reverse not implemented.");
	return nil;
}
@end

//
// Sequence
//
#pragma mark -
#pragma mark Sequence
@implementation MRSequence
+(id) actions: (MRFiniteTimeAction*) action1, ...
{
	va_list params;
	va_start(params,action1);

	MRFiniteTimeAction *now;
	MRFiniteTimeAction *prev = action1;

	while( action1 ) {
		now = va_arg(params,MRFiniteTimeAction*);
		if ( now )
			prev = [self actionOne: prev two: now];
		else
			break;
	}
	va_end(params);
	return prev;
}

+(id) actionsWithArray: (NSArray*) actions
{
	MRFiniteTimeAction *prev = [actions objectAtIndex:0];

	for (NSUInteger i = 1; i < [actions count]; i++)
		prev = [self actionOne:prev two:[actions objectAtIndex:i]];

	return prev;
}

+(id) actionOne: (MRFiniteTimeAction*) one two: (MRFiniteTimeAction*) two
{
	return ([[self alloc] initOne:one two:two ]);
}

-(id) initOne: (MRFiniteTimeAction*) one two: (MRFiniteTimeAction*) two
{
	NSAssert( one!=nil && two!=nil, @"Sequence: arguments must be non-nil");
	NSAssert( one!=actions_[0] && one!=actions_[1], @"Sequence: re-init using the same parameters is not supported");
	NSAssert( two!=actions_[1] && two!=actions_[0], @"Sequence: re-init using the same parameters is not supported");

	MRTime d = [one duration] + [two duration];

	if( (self=[super initWithDuration: d]) ) {

		// XXX: Supports re-init without leaking. Fails if one==one_ || two==two_
		(void)(actions_[0]);
		(void)(actions_[1]);

		actions_[0] = (one);
		actions_[1] = (two);
	}

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone:zone] initOne:([actions_[0] copy]) two:([actions_[1] copy]) ];
	return copy;
}

-(void) dealloc
{
	(void)(actions_[0]);
	(void)(actions_[1]);

}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	split_ = [actions_[0] duration] / MAX(duration_, FLT_EPSILON);
	last_ = -1;
}

-(void) stop
{
	[actions_[0] stop];
	[actions_[1] stop];
	[super stop];
}

-(void) update: (MRTime) t
{
	int found = 0;
	MRTime new_t = 0.0f;

	if( t >= split_ ) {
		found = 1;
		if ( split_ == 1 )
			new_t = 1;
		else
			new_t = (t-split_) / (1 - split_ );
	} else {
		found = 0;
		if( split_ != 0 )
			new_t = t / split_;
		else
			new_t = 1;
	}

	if (last_ == -1 && found==1)	{
		[actions_[0] startWithTarget:target_];
		[actions_[0] update:1.0f];
		[actions_[0] stop];
	}

	if (last_ != found ) {
		if( last_ != -1 ) {
			[actions_[last_] update: 1.0f];
			[actions_[last_] stop];
		}
		[actions_[found] startWithTarget:target_];
	}
	[actions_[found] update: new_t];
	last_ = found;
}

- (MRActionInterval *) reverse
{
	return [[self class] actionOne: [actions_[1] reverse] two: [actions_[0] reverse ] ];
}
@end

//
// Repeat
//
#pragma mark -
#pragma mark MRRepeat
@implementation MRRepeat
@synthesize innerAction=innerAction_;

+(id) actionWithAction:(MRFiniteTimeAction*)action times:(NSUInteger)times
{
	return ([[self alloc] initWithAction:action times:times]);
}

-(id) initWithAction:(MRFiniteTimeAction*)action times:(NSUInteger)times
{
	MRTime d = [action duration] * times;

	if( (self=[super initWithDuration: d ]) ) {
		times_ = times;
		self.innerAction = action;
		isActionInstant_ = ([action isKindOfClass:[MRActionInstant class]]) ? YES : NO;

		//a instant action needs to be executed one time less in the update method since it uses startWithTarget to execute the action
		if (isActionInstant_) times_ -=1;
		total_ = 0;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone:zone] initWithAction:([innerAction_ copy]) times:times_];
	return copy;
}



-(void) startWithTarget:(id)aTarget
{
	total_ = 0;
	nextDt_ = [innerAction_ duration]/duration_;
	[super startWithTarget:aTarget];
	[innerAction_ startWithTarget:aTarget];
}

-(void) stop
{
    [innerAction_ stop];
	[super stop];
}


// issue #80. Instead of hooking step:, hook update: since it can be called by any
// container action like Repeat, Sequence, AccelDeccel, etc..
-(void) update:(MRTime) dt
{
	if (dt >= nextDt_)
	{
		while (dt > nextDt_ && total_ < times_)
		{

			[innerAction_ update:1.0f];
			total_++;

			[innerAction_ stop];
			[innerAction_ startWithTarget:target_];
			nextDt_ += [innerAction_ duration]/duration_;
		}

		//fix for issue #1288, incorrect end value of repeat
		if(dt == 1.0 && total_ < times_)
        {
            total_++;
        }

		//don't set a instantaction back or update it, it has no use because it has no duration
		if (!isActionInstant_)
		{
			if (total_ == times_)
			{
				[innerAction_ update:1];
				[innerAction_ stop];
			}//issue #390 prevent jerk, use right update
			else
			{
				[innerAction_ update:dt - (nextDt_ - innerAction_.duration/duration_)];
			}
		}
	}
	else
	{
		[innerAction_ update:fmodf(dt * times_,1.0f)];
	}
}

-(BOOL) isDone
{
	return ( total_ == times_ );
}

- (MRActionInterval *) reverse
{
	return [[self class] actionWithAction:[innerAction_ reverse] times:times_];
}
@end

//
// Spawn
//
#pragma mark -
#pragma mark Spawn

@implementation MRSpawn
+(id) actions: (MRFiniteTimeAction*) action1, ...
{
	va_list params;
	va_start(params,action1);

	MRFiniteTimeAction *now;
	MRFiniteTimeAction *prev = action1;

	while( action1 ) {
		now = va_arg(params,MRFiniteTimeAction*);
		if ( now )
			prev = [self actionOne: prev two: now];
		else
			break;
	}
	va_end(params);
	return prev;
}

+(id) actionsWithArray: (NSArray*) actions
{
	MRFiniteTimeAction *prev = [actions objectAtIndex:0];

	for (NSUInteger i = 1; i < [actions count]; i++)
		prev = [self actionOne:prev two:[actions objectAtIndex:i]];

	return prev;
}

+(id) actionOne: (MRFiniteTimeAction*) one two: (MRFiniteTimeAction*) two
{
	return ([[self alloc] initOne:one two:two ]);
}

-(id) initOne: (MRFiniteTimeAction*) one two: (MRFiniteTimeAction*) two
{
	NSAssert( one!=nil && two!=nil, @"Spawn: arguments must be non-nil");
	NSAssert( one!=one_ && one!=two_, @"Spawn: reinit using same parameters is not supported");
	NSAssert( two!=two_ && two!=one_, @"Spawn: reinit using same parameters is not supported");

	MRTime d1 = [one duration];
	MRTime d2 = [two duration];

	if( (self=[super initWithDuration: MAX(d1,d2)] ) ) {

		// XXX: Supports re-init without leaking. Fails if one==one_ || two==two_



		one_ = one;
		two_ = two;

		if( d1 > d2 )
			two_ = [MRSequence actionOne:two two:[MRDelayTime actionWithDuration: (d1-d2)] ];
		else if( d1 < d2)
			one_ = [MRSequence actionOne:one two: [MRDelayTime actionWithDuration: (d2-d1)] ];



	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initOne: ([one_ copy]) two: ([two_ copy]) ];
	return copy;
}



-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[one_ startWithTarget:target_];
	[two_ startWithTarget:target_];
}

-(void) stop
{
	[one_ stop];
	[two_ stop];
	[super stop];
}

-(void) update: (MRTime) t
{
	[one_ update:t];
	[two_ update:t];
}

- (MRActionInterval *) reverse
{
	return [[self class] actionOne: [one_ reverse] two: [two_ reverse ] ];
}
@end

//
// RotateTo
//
#pragma mark -
#pragma mark RotateTo

@implementation MRRotateTo
+(id) actionWithDuration: (MRTime) t angle:(float) a
{
	return ([[self alloc] initWithDuration:t angle:a ]);
}

-(id) initWithDuration: (MRTime) t angle:(float) a
{
	if( (self=[super initWithDuration: t]) )
		dstAngle_ = a;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration:[self duration] angle:dstAngle_];
	return copy;
}

-(void) startWithTarget:(MRNode *)aTarget
{
    MRNode *targetNode = (MRNode *)target_;
	[super startWithTarget:aTarget];

	startAngle_ = [targetNode rotation];
	if (startAngle_ > 0)
		startAngle_ = fmodf(startAngle_, 360.0f);
	else
		startAngle_ = fmodf(startAngle_, -360.0f);

	diffAngle_ =dstAngle_ - startAngle_;
	if (diffAngle_ > 180)
		diffAngle_ -= 360;
	if (diffAngle_ < -180)
		diffAngle_ += 360;
}
-(void) update: (MRTime) t
{
    MRNode *targetNode = (MRNode *)target_;
	[targetNode setRotation: startAngle_ + diffAngle_ * t];
}
@end


//
// RotateBy
//
#pragma mark -
#pragma mark RotateBy

@implementation MRRotateBy
+(id) actionWithDuration: (MRTime) t angle:(float) a
{
	return ([[self alloc] initWithDuration:t angle:a ]);
}

-(id) initWithDuration: (MRTime) t angle:(float) a
{
	if( (self=[super initWithDuration: t]) )
		angle_ = a;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration: [self duration] angle: angle_];
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
    MRNode *targetNode = (MRNode *)target_;
	startAngle_ = [targetNode rotation];
}

-(void) update: (MRTime) t
{
	// XXX: shall I add % 360
    MRNode *targetNode = (MRNode *)target_;
	[targetNode setRotation: (startAngle_ +angle_ * t )];
}

-(MRActionInterval*) reverse
{
	return [[self class] actionWithDuration:duration_ angle:-angle_];
}

@end

//
// MoveTo
//
#pragma mark -
#pragma mark MoveTo

@implementation MRMoveTo
+(id) actionWithDuration: (MRTime) t position: (CGPoint) p
{
	return ([[self alloc] initWithDuration:t position:p ]);
}

-(id) initWithDuration: (MRTime) t position: (CGPoint) p
{
	if( (self=[super initWithDuration: t]) )
		endPosition_ = p;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration: [self duration] position: endPosition_];
	return copy;
}

-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];
	startPosition_ = [(MRNode*)target_ position];
	delta_ = MRPointSub( endPosition_, startPosition_ );
}

-(void) update: (MRTime) t
{
	[target_ setPosition: CGPointMake( (startPosition_.x + delta_.x * t ), (startPosition_.y + delta_.y * t ) )];
}
@end

//
// MoveBy
//
#pragma mark -
#pragma mark MoveBy

@implementation MRMoveBy
+(id) actionWithDuration: (MRTime) t position: (CGPoint) p
{
	return ([[self alloc] initWithDuration:t position:p ]);
}

-(id) initWithDuration: (MRTime) t position: (CGPoint) p
{
	if( (self=[super initWithDuration: t]) )
		delta_ = p;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration: [self duration] position: delta_];
	return copy;
}

-(void) startWithTarget:(MRNode *)aTarget
{
	CGPoint dTmp = delta_;
	[super startWithTarget:aTarget];
	delta_ = dTmp;
}

-(MRActionInterval*) reverse
{
	return [[self class] actionWithDuration:duration_ position:CGPointMake( -delta_.x, -delta_.y)];
}
@end


//
// SkewTo
//
#pragma mark -
#pragma mark SkewTo

@implementation MRSkewTo
+(id) actionWithDuration:(MRTime)t skewX:(float)sx skewY:(float)sy
{
	return ([[self alloc] initWithDuration: t skewX:sx skewY:sy]);
}

-(id) initWithDuration:(MRTime)t skewX:(float)sx skewY:(float)sy
{
	if( (self=[super initWithDuration:t]) ) {
		endSkewX_ = sx;
		endSkewY_ = sy;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration:[self duration] skewX:endSkewX_ skewY:endSkewY_];
	return copy;
}

-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];

	startSkewX_ = [target_ skewX];

	if (startSkewX_ > 0)
		startSkewX_ = fmodf(startSkewX_, 180.0f);
	else
		startSkewX_ = fmodf(startSkewX_, -180.0f);

	deltaX_ = endSkewX_ - startSkewX_;

	if ( deltaX_ > 180 ) {
		deltaX_ -= 360;
	}
	if ( deltaX_ < -180 ) {
		deltaX_ += 360;
	}

	startSkewY_ = [target_ skewY];

	if (startSkewY_ > 0)
		startSkewY_ = fmodf(startSkewY_, 360.0f);
	else
		startSkewY_ = fmodf(startSkewY_, -360.0f);

	deltaY_ = endSkewY_ - startSkewY_;

	if ( deltaY_ > 180 ) {
		deltaY_ -= 360;
	}
	if ( deltaY_ < -180 ) {
		deltaY_ += 360;
	}
}

-(void) update: (MRTime) t
{
	[target_ setSkewX: (startSkewX_ + deltaX_ * t ) ];
	[target_ setSkewY: (startSkewY_ + deltaY_ * t ) ];
}

@end

//
// MRSkewBy
//
@implementation MRSkewBy

-(id) initWithDuration:(MRTime)t skewX:(float)deltaSkewX skewY:(float)deltaSkewY
{
	if( (self=[super initWithDuration:t skewX:deltaSkewX skewY:deltaSkewY]) ) {
		skewX_ = deltaSkewX;
		skewY_ = deltaSkewY;
	}
	return self;
}

-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];
	deltaX_ = skewX_;
	deltaY_ = skewY_;
	endSkewX_ = startSkewX_ + deltaX_;
	endSkewY_ = startSkewY_ + deltaY_;
}

-(MRActionInterval*) reverse
{
	return [[self class] actionWithDuration:duration_ skewX:-skewX_ skewY:-skewY_];
}
@end


//
// JumpBy
//
#pragma mark -
#pragma mark JumpBy

@implementation MRJumpBy
+(id) actionWithDuration: (MRTime) t position: (CGPoint) pos height: (MRTime) h jumps:(NSUInteger)j
{
	return ([[self alloc] initWithDuration: t position: pos height: h jumps:j]);
}

-(id) initWithDuration: (MRTime) t position: (CGPoint) pos height: (MRTime) h jumps:(NSUInteger)j
{
	if( (self=[super initWithDuration:t]) ) {
		delta_ = pos;
		height_ = h;
		jumps_ = j;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration:[self duration] position:delta_ height:height_ jumps:jumps_];
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	startPosition_ = [(MRNode*)target_ position];
}

-(void) update: (MRTime) t
{
	// Sin jump. Less realistic
//	MRTime y = height * fabsf( sinf(t * (CGFloat)M_PI * jumps ) );
//	y += delta.y * t;
//	MRTime x = delta.x * t;
//	[target setPosition: CGPointMake( startPosition.x + x, startPosition.y + y )];

	// parabolic jump (since v0.8.2)
	MRTime frac = fmodf( t * jumps_, 1.0f );
	MRTime y = height_ * 4 * frac * (1 - frac);
	y += delta_.y * t;
	MRTime x = delta_.x * t;
	[target_ setPosition: CGPointMake( startPosition_.x + x, startPosition_.y + y )];

}

-(MRActionInterval*) reverse
{
	return [[self class] actionWithDuration:duration_ position: CGPointMake(-delta_.x,-delta_.y) height:height_ jumps:jumps_];
}
@end

//
// JumpTo
//
#pragma mark -
#pragma mark JumpTo

@implementation MRJumpTo
-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];
	delta_ = CGPointMake( delta_.x - startPosition_.x, delta_.y - startPosition_.y );
}
@end


#pragma mark -
#pragma mark BezierBy

// Bezier cubic formula:
//	((1 - t) + t)3 = 1
// Expands to…
//   (1 - t)3 + 3t(1-t)2 + 3t2(1 - t) + t3 = 1
static inline float bezierat( float a, float b, float c, float d, MRTime t )
{
	return (powf(1-t,3) * a +
			3*t*(powf(1-t,2))*b +
			3*powf(t,2)*(1-t)*c +
			powf(t,3)*d );
}

//
// BezierBy
//
@implementation MRBezierBy
+(id) actionWithDuration: (MRTime) t bezier:(MRBezierConfig) c
{
	return ([[self alloc] initWithDuration:t bezier:c ]);
}

-(id) initWithDuration: (MRTime) t bezier:(MRBezierConfig) c
{
	if( (self=[super initWithDuration: t]) ) {
		config_ = c;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration:[self duration] bezier:config_];
    return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	startPosition_ = [(MRNode*)target_ position];
}

-(void) update: (MRTime) t
{
	float xa = 0;
	float xb = config_.controlPoint_1.x;
	float xc = config_.controlPoint_2.x;
	float xd = config_.endPosition.x;

	float ya = 0;
	float yb = config_.controlPoint_1.y;
	float yc = config_.controlPoint_2.y;
	float yd = config_.endPosition.y;

	float x = bezierat(xa, xb, xc, xd, t);
	float y = bezierat(ya, yb, yc, yd, t);
	[target_ setPosition:  MRPointAdd( startPosition_, CGPointMake(x,y))];
}

- (MRActionInterval*) reverse
{
	MRBezierConfig r;

	r.endPosition	 = MRPointNeg(config_.endPosition);
	r.controlPoint_1 = MRPointAdd(config_.controlPoint_2, MRPointNeg(config_.endPosition));
	r.controlPoint_2 = MRPointAdd(config_.controlPoint_1, MRPointNeg(config_.endPosition));

	MRBezierBy *action = [[self class] actionWithDuration:[self duration] bezier:r];
	return action;
}
@end

//
// BezierTo
//
#pragma mark -
#pragma mark BezierTo
@implementation MRBezierTo
-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	config_.controlPoint_1 = MRPointSub(config_.controlPoint_1, startPosition_);
	config_.controlPoint_2 = MRPointSub(config_.controlPoint_2, startPosition_);
	config_.endPosition = MRPointSub(config_.endPosition, startPosition_);
}
@end


//
// ScaleTo
//
#pragma mark -
#pragma mark ScaleTo
@implementation MRScaleTo
+(id) actionWithDuration: (MRTime) t scale:(float) s
{
	return ([[self alloc] initWithDuration: t scale:s]);
}

-(id) initWithDuration: (MRTime) t scale:(float) s
{
	if( (self=[super initWithDuration: t]) ) {
		endScaleX_ = s;
		endScaleY_ = s;
	}
	return self;
}

+(id) actionWithDuration: (MRTime) t scaleX:(float)sx scaleY:(float)sy
{
	return ([[self alloc] initWithDuration: t scaleX:sx scaleY:sy]);
}

-(id) initWithDuration: (MRTime) t scaleX:(float)sx scaleY:(float)sy
{
	if( (self=[super initWithDuration: t]) ) {
		endScaleX_ = sx;
		endScaleY_ = sy;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration:[self duration] scaleX:endScaleX_ scaleY:endScaleY_];
	return copy;
}

-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];
	startScaleX_ = [target_ scaleX];
	startScaleY_ = [target_ scaleY];
	deltaX_ = endScaleX_ - startScaleX_;
	deltaY_ = endScaleY_ - startScaleY_;
}

-(void) update: (MRTime) t
{
	[target_ setScaleX: (startScaleX_ + deltaX_ * t ) ];
	[target_ setScaleY: (startScaleY_ + deltaY_ * t ) ];
}
@end

//
// ScaleBy
//
#pragma mark -
#pragma mark ScaleBy
@implementation MRScaleBy
-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];
	deltaX_ = startScaleX_ * endScaleX_ - startScaleX_;
	deltaY_ = startScaleY_ * endScaleY_ - startScaleY_;
}

-(MRActionInterval*) reverse
{
	return [[self class] actionWithDuration:duration_ scaleX:1/endScaleX_ scaleY:1/endScaleY_];
}
@end

//
// Blink
//
#pragma mark -
#pragma mark Blink
@implementation MRBlink
+(id) actionWithDuration: (MRTime) t blinks: (NSUInteger) b
{
	return ([[ self alloc] initWithDuration: t blinks: b]);
}

-(id) initWithDuration: (MRTime) t blinks: (NSUInteger) b
{
	if( (self=[super initWithDuration: t] ) )
		times_ = b;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration: [self duration] blinks: times_];
	return copy;
}

-(void) update: (MRTime) t
{
	if( ! [self isDone] ) {
		MRTime slice = 1.0f / times_;
		MRTime m = fmodf(t, slice);
		[target_ setVisible: (m > slice/2) ? YES : NO];
	}
}

-(MRActionInterval*) reverse
{
	// return 'self'
	return [[self class] actionWithDuration:duration_ blinks: times_];
}
@end

//
// FadeIn
//
#pragma mark -
#pragma mark FadeIn
@implementation MRFadeIn
-(void) update: (MRTime) t
{
	[(id<MRRGBAProtocol>) target_ setOpacity: 255 *t];
}

-(MRActionInterval*) reverse
{
	return [MRFadeOut actionWithDuration:duration_];
}
@end

//
// FadeOut
//
#pragma mark -
#pragma mark FadeOut
@implementation MRFadeOut
-(void) update: (MRTime) t
{
	[(id<MRRGBAProtocol>) target_ setOpacity: 255 *(1-t)];
}

-(MRActionInterval*) reverse
{
	return [MRFadeIn actionWithDuration:duration_];
}
@end

//
// FadeTo
//
#pragma mark -
#pragma mark FadeTo
@implementation MRFadeTo
+(id) actionWithDuration: (MRTime) t opacity: (uint8_t) o
{
	return ([[ self alloc] initWithDuration: t opacity: o]);
}

-(id) initWithDuration: (MRTime) t opacity: (uint8_t) o
{
	if( (self=[super initWithDuration: t] ) )
		toOpacity_ = o;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration:[self duration] opacity:toOpacity_];
	return copy;
}

-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];
	fromOpacity_ = [(id<MRRGBAProtocol>)target_ opacity];
}

-(void) update: (MRTime) t
{
	[(id<MRRGBAProtocol>)target_ setOpacity:fromOpacity_ + ( toOpacity_ - fromOpacity_ ) * t];
}
@end

//
// TintTo
//
#pragma mark -
#pragma mark TintTo
@implementation MRTintTo
+(id) actionWithDuration:(MRTime)t red:(uint8_t)r green:(uint8_t)g blue:(uint8_t)b
{
	return ([(MRTintTo*)[ self alloc] initWithDuration:t red:r green:g blue:b]);
}

-(id) initWithDuration: (MRTime) t red:(uint8_t)r green:(uint8_t)g blue:(uint8_t)b
{
	if( (self=[super initWithDuration:t] ) )
		to_ = MRColor3BMake(r,g,b);

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [(MRTintTo*)[[self class] allocWithZone: zone] initWithDuration:[self duration] red:to_.r green:to_.g blue:to_.b];
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];

	id<MRRGBAProtocol> tn = (id<MRRGBAProtocol>) target_;
	from_ = [tn color];
}

-(void) update: (MRTime) t
{
	id<MRRGBAProtocol> tn = (id<MRRGBAProtocol>) target_;
	[tn setColor:MRColor3BMake(from_.r + (to_.r - from_.r) * t, from_.g + (to_.g - from_.g) * t, from_.b + (to_.b - from_.b) * t)];
}
@end

//
// TintBy
//
#pragma mark -
#pragma mark TintBy
@implementation MRTintBy
+(id) actionWithDuration:(MRTime)t red:(int16_t)r green:(int16_t)g blue:(int16_t)b
{
	return ([(MRTintBy*)[ self alloc] initWithDuration:t red:r green:g blue:b]);
}

-(id) initWithDuration:(MRTime)t red:(int16_t)r green:(int16_t)g blue:(int16_t)b
{
	if( (self=[super initWithDuration: t] ) ) {
		deltaR_ = r;
		deltaG_ = g;
		deltaB_ = b;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	return[(MRTintBy*)[[self class] allocWithZone: zone] initWithDuration: [self duration] red:deltaR_ green:deltaG_ blue:deltaB_];
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];

	id<MRRGBAProtocol> tn = (id<MRRGBAProtocol>) target_;
	MRColor3B color = [tn color];
	fromR_ = color.r;
	fromG_ = color.g;
	fromB_ = color.b;
}

-(void) update: (MRTime) t
{
	id<MRRGBAProtocol> tn = (id<MRRGBAProtocol>) target_;
	[tn setColor:MRColor3BMake( fromR_ + deltaR_ * t, fromG_ + deltaG_ * t, fromB_ + deltaB_ * t)];
}

- (MRActionInterval*) reverse
{
	return [MRTintBy actionWithDuration:duration_ red:-deltaR_ green:-deltaG_ blue:-deltaB_];
}
@end

//
// DelayTime
//
#pragma mark -
#pragma mark DelayTime
@implementation MRDelayTime
-(void) update: (MRTime) t
{
	return;
}

-(id)reverse
{
	return [[self class] actionWithDuration:duration_];
}
@end

//
// ReverseTime
//
#pragma mark -
#pragma mark ReverseTime
@implementation MRReverseTime
+(id) actionWithAction: (MRFiniteTimeAction*) action
{
	// casting to prevent warnings
	MRReverseTime *a = [super alloc];
	return ([a initWithAction:action]);
}

-(id) initWithAction: (MRFiniteTimeAction*) action
{
	NSAssert(action != nil, @"MRReverseTime: action should not be nil");
	NSAssert(action != other_, @"MRReverseTime: re-init doesn't support using the same arguments");

	if( (self=[super initWithDuration: [action duration]]) ) {
		// Don't leak if action is reused

		other_ = action;
	}

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	return [[[self class] allocWithZone: zone] initWithAction:([other_ copy]) ];
}



-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[other_ startWithTarget:target_];
}

-(void) stop
{
	[other_ stop];
	[super stop];
}

-(void) update:(MRTime)t
{
	[other_ update:1-t];
}

-(MRActionInterval*) reverse
{
	return ([other_ copy]);
}
@end

//
// Animate
//

#pragma mark - MRAnimate


@implementation MRTargetedAction

@synthesize forcedTarget = forcedTarget_;

+ (id) actionWithTarget:(id) target action:(MRFiniteTimeAction*) action
{
	return ([ (MRTargetedAction*)[self alloc] initWithTarget:target action:action]);
}

- (id) initWithTarget:(id) targetIn action:(MRFiniteTimeAction*) actionIn
{
	if((self = [super initWithDuration:actionIn.duration]))
	{
		forcedTarget_ = (targetIn);
		action_ = (actionIn);
	}
	return self;
}



- (void) startWithTarget:(id)aTarget
{
	[super startWithTarget:forcedTarget_];
	[action_ startWithTarget:forcedTarget_];
}

- (void) stop
{
	[action_ stop];
}

- (void) update:(MRTime) time
{
	[action_ update:time];
}

@end
