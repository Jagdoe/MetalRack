#import "MRActionEase.h"
#import "MRActionTypes.h"
#import "MRAction.h"
#import "MRActionInterval.h"
#import "MRActionInstant.h"
#import "MRSprite.h"
/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2008-2009 Jason Booth
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


/*
 * Elastic, Back and Bounce actions based on code from:
 * http://github.com/NikhilK/silverlightfx/
 *
 * by http://github.com/NikhilK
 */


#ifndef M_PI_X_2
#define M_PI_X_2 (float)M_PI * 2.0f
#endif

#pragma mark EaseAction

//
// EaseAction
//
@implementation MRActionEase

+(id) actionWithAction: (MRActionInterval*) action
{
	return ([[self alloc] initWithAction: action]);
}

-(id) initWithAction: (MRActionInterval*) action
{
	NSAssert( action!=nil, @"Ease: arguments must be non-nil");

	if( (self=[super initWithDuration: action.duration]) )
		other = action;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone:zone] initWithAction:([other copy])];
	return copy;
}



-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[other startWithTarget:target_];
}

-(void) stop
{
	[other stop];
	[super stop];
}

-(void) update: (MRTime) t
{
	[other update: t];
}

-(MRActionInterval*) reverse
{
	return [[self class] actionWithAction: [other reverse]];
}
@end


#pragma mark -
#pragma mark EaseRate

//
// EaseRateAction
//
@implementation MREaseRateAction
@synthesize rate;
+(id) actionWithAction: (MRActionInterval*) action rate:(float)aRate
{
	return ([[self alloc] initWithAction: action rate:aRate]);
}

-(id) initWithAction: (MRActionInterval*) action rate:(float)aRate
{
	if( (self=[super initWithAction:action ]) )
		self.rate = aRate;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone:zone] initWithAction:([other copy]) rate:rate];
	return copy;
}



-(MRActionInterval*) reverse
{
	return [[self class] actionWithAction: [other reverse] rate:1/rate];
}
@end

//
// EeseIn
//
@implementation MREaseIn
-(void) update: (MRTime) t
{
	[other update: powf(t,rate)];
}
@end

//
// EaseOut
//
@implementation MREaseOut
-(void) update: (MRTime) t
{
	[other update: powf(t,1/rate)];
}
@end

//
// EaseInOut
//
@implementation MREaseInOut
-(void) update: (MRTime) t
{
	int sign =1;
	int r = (int) rate;
	if (r % 2 == 0)
		sign = -1;
	t *= 2;
	if (t < 1)
		[other update: 0.5f * powf (t, rate)];
	else
		[other update: sign*0.5f * (powf (t-2, rate) + sign*2)];
}

// InOut and OutIn are symmetrical
-(MRActionInterval*) reverse
{
	return [[self class] actionWithAction: [other reverse] rate:rate];
}

@end

#pragma mark -
#pragma mark EaseExponential

//
// EaseExponentialIn
//
@implementation MREaseExponentialIn
-(void) update: (MRTime) t
{
	[other update: (t==0) ? 0 : powf(2, 10 * (t/1 - 1)) - 1 * 0.001f];
}

- (MRActionInterval*) reverse
{
	return [MREaseExponentialOut actionWithAction: [other reverse]];
}
@end

//
// EaseExponentialOut
//
@implementation MREaseExponentialOut
-(void) update: (MRTime) t
{
	[other update: (t==1) ? 1 : (-powf(2, -10 * t/1) + 1)];
}

- (MRActionInterval*) reverse
{
	return [MREaseExponentialIn actionWithAction: [other reverse]];
}
@end

//
// EaseExponentialInOut
//
@implementation MREaseExponentialInOut
-(void) update: (MRTime) t
{
	t /= 0.5f;
	if (t < 1)
		t = 0.5f * powf(2, 10 * (t - 1));
	else
		t = 0.5f * (-powf(2, -10 * (t -1) ) + 2);

	[other update:t];
}
@end


#pragma mark -
#pragma mark EaseSin actions

//
// EaseSineIn
//
@implementation MREaseSineIn
-(void) update: (MRTime) t
{
	[other update:-1*cosf(t * (float)M_PI_2) +1];
}

- (MRActionInterval*) reverse
{
	return [MREaseSineOut actionWithAction: [other reverse]];
}
@end

//
// EaseSineOut
//
@implementation MREaseSineOut
-(void) update: (MRTime) t
{
	[other update:sinf(t * (float)M_PI_2)];
}

- (MRActionInterval*) reverse
{
	return [MREaseSineIn actionWithAction: [other reverse]];
}
@end

//
// EaseSineInOut
//
@implementation MREaseSineInOut
-(void) update: (MRTime) t
{
	[other update:-0.5f*(cosf( (float)M_PI*t) - 1)];
}
@end

#pragma mark -
#pragma mark EaseElastic actions

//
// EaseElastic
//
@implementation MREaseElastic

@synthesize period = period_;

+(id) actionWithAction: (MRActionInterval*) action
{
	return ([[self alloc] initWithAction:action period:0.3f]);
}

+(id) actionWithAction: (MRActionInterval*) action period:(float)period
{
	return ([[self alloc] initWithAction:action period:period]);
}

-(id) initWithAction: (MRActionInterval*) action
{
	return [self initWithAction:action period:0.3f];
}

-(id) initWithAction: (MRActionInterval*) action period:(float)period
{
	if( (self=[super initWithAction:action]) )
		period_ = period;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone:zone] initWithAction:([other copy]) period:period_];
	return copy;
}

-(MRActionInterval*) reverse
{
	NSAssert(NO,@"Override me");
	return nil;
}

@end

//
// EaseElasticIn
//

@implementation MREaseElasticIn
-(void) update: (MRTime) t
{
	MRTime newT = 0;
	if (t == 0 || t == 1)
		newT = t;

	else {
		float s = period_ / 4;
		t = t - 1;
		newT = -powf(2, 10 * t) * sinf( (t-s) *M_PI_X_2 / period_);
	}
	[other update:newT];
}

- (MRActionInterval*) reverse
{
	return [MREaseElasticOut actionWithAction: [other reverse] period:period_];
}

@end

//
// EaseElasticOut
//
@implementation MREaseElasticOut

-(void) update: (MRTime) t
{
	MRTime newT = 0;
	if (t == 0 || t == 1) {
		newT = t;

	} else {
		float s = period_ / 4;
		newT = powf(2, -10 * t) * sinf( (t-s) *M_PI_X_2 / period_) + 1;
	}
	[other update:newT];
}

- (MRActionInterval*) reverse
{
	return [MREaseElasticIn actionWithAction: [other reverse] period:period_];
}

@end

//
// EaseElasticInOut
//
@implementation MREaseElasticInOut
-(void) update: (MRTime) t
{
	MRTime newT = 0;

	if( t == 0 || t == 1 )
		newT = t;
	else {
		t = t * 2;
		if(! period_ )
			period_ = 0.3f * 1.5f;
		MRTime s = period_ / 4;

		t = t -1;
		if( t < 0 )
			newT = -0.5f * powf(2, 10 * t) * sinf((t - s) * M_PI_X_2 / period_);
		else
			newT = powf(2, -10 * t) * sinf((t - s) * M_PI_X_2 / period_) * 0.5f + 1;
	}
	[other update:newT];
}

- (MRActionInterval*) reverse
{
	return [MREaseElasticInOut actionWithAction: [other reverse] period:period_];
}

@end

#pragma mark -
#pragma mark EaseBounce actions

//
// EaseBounce
//
@implementation MREaseBounce
-(MRTime) bounceTime:(MRTime) t
{
	if (t < 1 / 2.75) {
		return 7.5625f * t * t;
	}
	else if (t < 2 / 2.75) {
		t -= 1.5f / 2.75f;
		return 7.5625f * t * t + 0.75f;
	}
	else if (t < 2.5 / 2.75) {
		t -= 2.25f / 2.75f;
		return 7.5625f * t * t + 0.9375f;
	}

	t -= 2.625f / 2.75f;
	return 7.5625f * t * t + 0.984375f;
}
@end

//
// EaseBounceIn
//

@implementation MREaseBounceIn

-(void) update: (MRTime) t
{
	MRTime newT = 1 - [self bounceTime:1-t];
	[other update:newT];
}

- (MRActionInterval*) reverse
{
	return [MREaseBounceOut actionWithAction: [other reverse]];
}

@end

@implementation MREaseBounceOut

-(void) update: (MRTime) t
{
	MRTime newT = [self bounceTime:t];
	[other update:newT];
}

- (MRActionInterval*) reverse
{
	return [MREaseBounceIn actionWithAction: [other reverse]];
}

@end

@implementation MREaseBounceInOut

-(void) update: (MRTime) t
{
	MRTime newT = 0;
	if (t < 0.5) {
		t = t * 2;
		newT = (1 - [self bounceTime:1-t] ) * 0.5f;
	} else
		newT = [self bounceTime:t * 2 - 1] * 0.5f + 0.5f;

	[other update:newT];
}
@end

#pragma mark -
#pragma mark Ease Back actions

//
// EaseBackIn
//
@implementation MREaseBackIn

-(void) update: (MRTime) t
{
	MRTime overshoot = 1.70158f;
	[other update: t * t * ((overshoot + 1) * t - overshoot)];
}

- (MRActionInterval*) reverse
{
	return [MREaseBackOut actionWithAction: [other reverse]];
}
@end

//
// EaseBackOut
//
@implementation MREaseBackOut
-(void) update: (MRTime) t
{
	MRTime overshoot = 1.70158f;

	t = t - 1;
	[other update: t * t * ((overshoot + 1) * t + overshoot) + 1];
}

- (MRActionInterval*) reverse
{
	return [MREaseBackIn actionWithAction: [other reverse]];
}
@end

//
// EaseBackInOut
//
@implementation MREaseBackInOut

-(void) update: (MRTime) t
{
	MRTime overshoot = 1.70158f * 1.525f;

	t = t * 2;
	if (t < 1)
		[other update: (t * t * ((overshoot + 1) * t - overshoot)) / 2];
	else {
		t = t - 2;
		[other update: (t * t * ((overshoot + 1) * t + overshoot)) / 2 + 1];
	}
}
@end
