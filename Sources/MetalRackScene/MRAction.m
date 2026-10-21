#import "MRActionTypes.h"
#import "MRActionInterval.h"
#import "MRActionInstant.h"
#import "MRSprite.h"
/*
 * cocos2d for iPhone: http://www.cocos2d-iphone.org
 *
 * Copyright (c) 2008-2010 Ricardo Quesada
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
// Action Base Class
//
#pragma mark -
#pragma mark Action
@implementation MRAction

@synthesize tag = tag_, target = target_, originalTarget = originalTarget_;

+(id) action
{
	return ([[self alloc] init]);
}

-(id) init
{
	if( (self=[super init]) ) {
		originalTarget_ = target_ = nil;
		tag_ = kMRActionTagInvalid;
	}
	return self;
}

-(void) dealloc
{
	MR_ACTION_LOG(@"cocos2d: deallocing %@", self);

}

-(NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = %p | Tag = %ld>", [self class], (__bridge void *)self, (long)tag_];
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] init];
	copy.tag = tag_;
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	originalTarget_ = target_ = aTarget;
}

-(void) stop
{
	target_ = nil;
}

-(BOOL) isDone
{
	return YES;
}

-(void) step: (MRTime) dt
{
	NSLog(@"[Action step]. override me");
}

-(void) update: (MRTime) time
{
	NSLog(@"[Action update]. override me");
}
@end

//
// FiniteTimeAction
//
#pragma mark -
#pragma mark FiniteTimeAction
@implementation MRFiniteTimeAction
@synthesize duration = duration_;

- (MRFiniteTimeAction*) reverse
{
	MR_ACTION_LOG(@"cocos2d: FiniteTimeAction#reverse: Implement me");
	return nil;
}
@end


//
// RepeatForever
//
#pragma mark -
#pragma mark RepeatForever
@implementation MRRepeatForever
@synthesize innerAction=innerAction_;
+(id) actionWithAction: (MRActionInterval*) action
{
	return ([[self alloc] initWithAction: action]);
}

-(id) initWithAction: (MRActionInterval*) action
{
	if( (self=[super init]) )
		self.innerAction = action;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithAction:([innerAction_ copy]) ];
    return copy;
}



-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[innerAction_ startWithTarget:target_];
}

-(void) step:(MRTime) dt
{
	[innerAction_ step: dt];
	if( [innerAction_ isDone] ) {
		MRTime diff = innerAction_.elapsed - innerAction_.duration;
		[innerAction_ startWithTarget:target_];

		// to prevent jerk. issue #390, 1247
		[innerAction_ step: 0.0f];
		[innerAction_ step: diff];
	}
}


-(BOOL) isDone
{
	return NO;
}

- (MRActionInterval *) reverse
{
	return [MRRepeatForever actionWithAction:[innerAction_ reverse]];
}
@end

//
// Speed
//
#pragma mark -
#pragma mark Speed
@implementation MRSpeed
@synthesize speed=speed_;
@synthesize innerAction=innerAction_;

+(id) actionWithAction: (MRActionInterval*) action speed:(float)r
{
	return ([[self alloc] initWithAction: action speed:r]);
}

-(id) initWithAction: (MRActionInterval*) action speed:(float)r
{
	if( (self=[super init]) ) {
		self.innerAction = action;
		speed_ = r;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithAction:([innerAction_ copy]) speed:speed_];
    return copy;
}



-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[innerAction_ startWithTarget:target_];
}

-(void) stop
{
	[innerAction_ stop];
	[super stop];
}

-(void) step:(MRTime) dt
{
	[innerAction_ step: dt * speed_];
}

-(BOOL) isDone
{
	return [innerAction_ isDone];
}

- (MRActionInterval *) reverse
{
	return [MRSpeed actionWithAction:[innerAction_ reverse] speed:speed_];
}
@end

//
// Follow
//
#pragma mark -
#pragma mark Follow
