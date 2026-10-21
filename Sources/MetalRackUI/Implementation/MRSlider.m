#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DSlider.m
//  Zombie
//
//  Created by Michael Scandizzo on 11/15/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRSlider.h"


@implementation MRSlider

//+ (id)createFromDefinition:(NSDictionary *)dictDef
//{
//	NSString *strImage;
//	NSObject *obImage = [dictDef objectForKey:@"image"];
//	if ([obImage isKindOfClass:[NSArray class]] == YES)
//	{
//		NSArray *aImage = (NSArray *)obImage;
//		int numTypes = [aImage count];
//		int nRandIndex = random() % numTypes;
//		strImage = [aImage objectAtIndex:nRandIndex];
//	}
//	else
//	{
//		strImage = (NSString *)obImage;
//	}
//
//	C2DSlider *sliderNew = [[C2DSlider alloc] initWithFrameName:strImage];
//	[sliderNew initFromDefinition:dictDef];
//	return sliderNew;
//}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
	m_fIconOnly = YES;
	[super initFromDefinition:dictDef];
	NSString *strButtonImage = [dictDef objectForKey:@"button image"];

//    m_buttonControl = [C2DSprite createFromDefName:strButtonImage];
	m_buttonControl = [[MRButton alloc] initWithFrameName:strButtonImage];
    m_buttonControl.enabled = NO;
	[self addChild:m_buttonControl];

	CGSize sizeSlider = self.contentSize;
	CGSize sizeButton = m_buttonControl.contentSize;
	[m_buttonControl setPosition:MRPoint(sizeButton.width / 2.0f, sizeSlider.height / 2.0f)];
	[self setHitTestOverrideSize:CGSizeMake(sizeSlider.width, sizeButton.height)];
}


- (id)init
{
	self = [super init];
	if (self.inScene) [self.environment.input addReceiver:(id)self priority:0 swallows:NO];

	m_selTouchBegin	= nil;
	m_idTouchBegin	= nil;

	// Done.
	return self;
}

- (id)initWithFrameName:(NSString *)strFrame
{
	MRSpriteFrame *frameNormal		= [[MRSceneRuntime sharedRuntime].resources frameNamed:strFrame];
	self = [super initWithFrame:frameNormal];
	if (self == nil)
		return nil;

	return self;
}

- (float)getPercent
{
	CGPoint pointButton = m_buttonControl.position;
	float flPercent = pointButton.x / self.contentSize.width;
	return flPercent;
}

- (void)setPercent:(float)flPercent
{
	float flPosition = flPercent * self.contentSize.width;
	[m_buttonControl setPosition:MRPoint(flPosition, m_buttonControl.position.y)];
}

- (void)pointersBegan:(NSSet *)touches
{
//	if (enabled == NO)
//		return; //NO
	MRPointerEvent *touch = [touches anyObject];
	BOOL fHitTest = [self hitTest:touch];
	if (fHitTest == NO)
		return;

	CGPoint touchLocation = touch.position;
	touchLocation = touchLocation;

	CGPoint pointLeft	= [self convertToWorldSpace:MRPoint(0, 0)];
	CGPoint pointRight	= [self convertToWorldSpace:MRPoint(self.contentSize.width, 0)];

	if (touchLocation.x < pointLeft.x)
		touchLocation.x = pointLeft.x;
	if (touchLocation.x > pointRight.x)
		touchLocation.x = pointRight.x;

	CGPoint newPos;
	newPos.x = [self convertToNodeSpace:touchLocation].x;
	newPos.y = m_buttonControl.position.y;

	[m_buttonControl setPosition:newPos];

	return; //NO
}

- (void)pointersMoved:(NSSet *)touches
{
	MRPointerEvent *touch = [touches anyObject];
	BOOL fHitTest = [self hitTest:touch];
	if (fHitTest == NO)
		return;

	CGPoint touchLocation = touch.position;
	touchLocation = touchLocation;

	CGPoint pointLeft	= [self convertToWorldSpace:MRPoint(0, 0)];
	CGPoint pointRight	= [self convertToWorldSpace:MRPoint(self.contentSize.width, 0)];

	if (touchLocation.x < pointLeft.x)
		touchLocation.x = pointLeft.x;
	if (touchLocation.x > pointRight.x)
		touchLocation.x = pointRight.x;

	CGPoint newPos;
	newPos.x = [self convertToNodeSpace:touchLocation].x;
	newPos.y = m_buttonControl.position.y;

	[m_buttonControl setPosition:newPos];

	if (m_idTouchBegin != nil && m_selTouchBegin != nil)
	{
		[m_idTouchBegin performSelector:m_selTouchBegin withObject:self];
	}

	return; //NO
}

-(void) pointersEnded:(NSSet *)touches
{
	MRPointerEvent *touch = [touches anyObject];
	BOOL fHitTest = [self hitTest:touch];
	if (fHitTest == NO)
		return;

	if (m_idTouchBegin != nil && m_selTouchBegin != nil)
	{
		[m_idTouchBegin performSelector:m_selTouchBegin withObject:self];
	}
}

- (void)addTouchTarget:(SEL)selTouch forObject:(id)idObject
{
	m_idTouchBegin = idObject;
	m_selTouchBegin = selTouch;
}

- (void)cleanup
{
	[self.environment.input removeReceiver:(id)self];
}

- (void)didEnterScene {
    [super didEnterScene]; [self.environment.input addReceiver:(id)self priority:-1 swallows:YES];
}
- (void)dealloc
{
	(void)0;
}


@end

#endif
