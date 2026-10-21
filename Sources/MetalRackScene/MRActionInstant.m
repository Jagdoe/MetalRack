#import "MRActionTypes.h"
#import "MRAction.h"
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
// InstantAction
//
#pragma mark MRActionInstant

@implementation MRActionInstant

-(id) init
{
	if( (self=[super init]) )
		duration_ = 0;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] init];
	return copy;
}

- (BOOL) isDone
{
	return YES;
}

-(void) step: (MRTime) dt
{
	[self update: 1];
}

-(void) update: (MRTime) t
{
	// ignore
}

-(MRFiniteTimeAction*) reverse
{
	return ([self copy]);
}
@end

//
// Show
//
#pragma mark MRShow

@implementation MRShow
-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	((MRNode *)target_).visible = YES;
}

-(MRFiniteTimeAction*) reverse
{
	return [MRHide action];
}
@end

//
// Hide
//
#pragma mark MRHide

@implementation MRHide
-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	((MRNode *)target_).visible = NO;
}

-(MRFiniteTimeAction*) reverse
{
	return [MRShow action];
}
@end

//
// ToggleVisibility
//
#pragma mark MRToggleVisibility

@implementation MRToggleVisibility
-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	((MRNode *)target_).visible = !((MRNode *)target_).visible;
}
@end

//
// FlipX
//
#pragma mark MRFlipX

@implementation MRFlipX
+(id) actionWithFlipX:(BOOL)x
{
	return ([[self alloc] initWithFlipX:x]);
}

-(id) initWithFlipX:(BOOL)x
{
	if(( self=[super init]))
		flipX = x;

	return self;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[(MRSprite*)aTarget setFlipX:flipX];
}

-(MRFiniteTimeAction*) reverse
{
	return [MRFlipX actionWithFlipX:!flipX];
}

-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithFlipX:flipX];
	return copy;
}
@end

//
// FlipY
//
#pragma mark MRFlipY

@implementation MRFlipY
+(id) actionWithFlipY:(BOOL)y
{
	return ([[self alloc] initWithFlipY:y]);
}

-(id) initWithFlipY:(BOOL)y
{
	if(( self=[super init]))
		flipY = y;

	return self;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[(MRSprite*)aTarget setFlipY:flipY];
}

-(MRFiniteTimeAction*) reverse
{
	return [MRFlipY actionWithFlipY:!flipY];
}

-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithFlipY:flipY];
	return copy;
}
@end


//
// Place
//
#pragma mark MRPlace

@implementation MRPlace
+(id) actionWithPosition: (CGPoint) pos
{
	return [[self alloc] initWithPosition:pos];
}

-(id) initWithPosition: (CGPoint) pos
{
	if( (self=[super init]) )
		position = pos;

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithPosition: position];
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	((MRNode *)target_).position = position;
}

@end

//
// CallFunc
//
#pragma mark MRCallFunc

@implementation MRCallFunc

@synthesize targetCallback = targetCallback_;

+(id) actionWithTarget: (id) t selector:(SEL) s
{
	return ([[self alloc] initWithTarget: t selector: s]);
}

-(id) initWithTarget: (id) t selector:(SEL) s
{
	if( (self=[super init]) ) {
		self.targetCallback = t;
		selector_ = s;
	}
	return self;
}

-(NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = %p | Tag = %ld | target = %@ | selector = %@>",
			[self class],
			(__bridge void *)self,
			(long)tag_,
			[targetCallback_ class],
			NSStringFromSelector(selector_)
			];
}



-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithTarget:targetCallback_ selector:selector_];
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[self execute];
}

-(void) execute
{
	if (targetCallback_) ((void (*)(id,SEL))[targetCallback_ methodForSelector:selector_])(targetCallback_,selector_);
}
@end

//
// CallFuncN
//
#pragma mark MRCallFuncN

@implementation MRCallFuncN

-(void) execute
{
	if (targetCallback_) ((void (*)(id,SEL,id))[targetCallback_ methodForSelector:selector_])(targetCallback_,selector_,target_);
}
@end

//
// CallFuncND
//
#pragma mark MRCallFuncND

@implementation MRCallFuncND

@synthesize callbackMethod = callbackMethod_;

+(id) actionWithTarget:(id)t selector:(SEL)s data:(void*)d
{
	return ([[self alloc] initWithTarget:t selector:s data:d]);
}

-(id) initWithTarget:(id)t selector:(SEL)s data:(void*)d
{
	if( (self=[super initWithTarget:t selector:s]) ) {
		data_ = d;

#if COCOS2D_DEBUG
		NSMethodSignature * sig = [t methodSignatureForSelector:s]; // added
		NSAssert(sig !=0 , @"Signature not found for selector - does it have the following form? -(void)name:(id)sender data:(void*)data");
#endif
		callbackMethod_ = (MR_CALLBACK_ND) [t methodForSelector:s];
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithTarget:targetCallback_ selector:selector_ data:data_];
	return copy;
}

-(void) dealloc
{
	// nothing to dealloc really. Everything is dealloc on super (MRCallFuncN)

}

-(void) execute
{
	callbackMethod_(targetCallback_,selector_,target_, data_);
}
@end

@implementation MRCallFuncO
@synthesize  object = object_;

+(id) actionWithTarget: (id) t selector:(SEL) s object:(id)object
{
	return ([[self alloc] initWithTarget:t selector:s object:object]);
}

-(id) initWithTarget:(id) t selector:(SEL) s object:(id)object
{
	if( (self=[super initWithTarget:t selector:s] ) )
		self.object = object;

	return self;
}



-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithTarget:targetCallback_ selector:selector_ object:object_];
	return copy;
}


-(void) execute
{
	if (targetCallback_) ((void (*)(id,SEL,id))[targetCallback_ methodForSelector:selector_])(targetCallback_,selector_,object_);
}

@end


#pragma mark -
#pragma mark Blocks

#if NS_BLOCKS_AVAILABLE

#pragma mark MRCallBlock

@implementation MRCallBlock

+(id) actionWithBlock:(void(^)())block
{
	return ([[self alloc] initWithBlock:block]);
}

-(id) initWithBlock:(void(^)())block
{
	if ((self = [super init]))
		block_ = [block copy];

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithBlock:block_];
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[self execute];
}

-(void) execute
{
	block_();
}



@end

#pragma mark MRCallBlockN

@implementation MRCallBlockN

+(id) actionWithBlock:(void(^)(MRNode *node))block
{
	return ([[self alloc] initWithBlock:block]);
}

-(id) initWithBlock:(void(^)(MRNode *node))block
{
	if ((self = [super init]))
		block_ = [block copy];

	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRActionInstant *copy = [[[self class] allocWithZone: zone] initWithBlock:block_];
	return copy;
}

-(void) startWithTarget:(id)aTarget
{
	[super startWithTarget:aTarget];
	[self execute];
}

-(void) execute
{
	block_(target_);
}



@end


#endif // NS_BLOCKS_AVAILABLE
