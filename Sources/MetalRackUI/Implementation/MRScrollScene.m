#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  ScrollScene.m
//  Befuddled
//
//  Created by Michael Scandizzo on 7/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRScrollScene.h"
#import "MRSceneConfiguration.h"
#import "MRUtilities.h"
#import "MRSceneHost.h"
#import "MRDefinitionSprite.h"
#import "MRButton.h"
#import "MRLineLayer.h"
#import "2DMath.h"
#import "MRInputLayer.h"


@implementation MRScrollScene

- (void)back:(id)idSender
{
}

- (id) init
{
    self = [super init];
    if (self != nil)
	{
		layMain = [MRInputLayer node];
		[layMain setTouchBegan:@selector(singleTouchBegan:)
					 withMoved:@selector(singleTouchMoved:)
					 withEnded:@selector(singleTouchEnded:)];
		[self addChild:layMain z:MR_LAYER_UI];


		m_utilsMan = [MRUtilities sharedUtilityManager];
	}
	return self;
}

- (void)dealloc
{
	(void)0;
	m_utilsMan = nil;

	(void)0;
}

#pragma mark -
#pragma mark Local Helper Functions

// Protected helper functions.

- (void)addMapNode:(MRDefinitionSprite *)sprNode
{
	[m_aMapNodes addObject:sprNode];
}

- (id)createMapNodePointer:(MRDefinitionSprite *)sprNode atPoint:(CGPoint)pIntersect
{
	return [m_utilsMan createMapNodePointer:sprNode inLayer:layNodePointers atPoint:pIntersect];
}

- (void)updateMapNodePointers
{
	[layNodePointers removeAllChildrenWithCleanup:YES];

	CGPoint pOffset = layMain.position;
	CGRect rectScreen = CGRectMake(0, 0, MR_SCREEN_MINOR, MR_SCREEN_MAJOR);

	for (MRDefinitionSprite *sprNode in m_aMapNodes)
	{
		CGPoint pNode = add(sprNode.position, pOffset);
		if (CGRectContainsPoint(rectScreen, pNode) == NO)
		{
			CGPoint pCenter = MRPoint(MR_HALF_SCREEN_MINOR, MR_HALF_SCREEN_MAJOR);
			CGPoint vCenterToNode = subtract(pNode, pCenter);
			CGPoint pIntersect = [m_utilsMan findScreenEdgeforRay:vCenterToNode withPoint:pCenter];
			MRDefinitionSprite *sprNodePointer = [self createMapNodePointer:sprNode atPoint:pIntersect];
			sprNodePointer.visible = YES;
			sprNodePointer.opacity = 255;
			CGPoint vUp = MRPoint(0, 1.0f);
			float flAngle = angleBetweenVectors(vCenterToNode, vUp);
			[sprNodePointer setRotation:flAngle];
		}
	}
}

- (CGPoint)getEntryPosition:(NSDictionary *)dictData
{
#if MR_IPHONE
	NSString *strPosition = [dictData objectForKey:MR_ENTRY_PHONE_POSITION];
	if (strPosition == nil)
		strPosition = [dictData objectForKey:MR_ENTRY_POSITION];
#else
	NSString *strPosition = [dictData objectForKey:MR_ENTRY_POSITION];
#endif
	CGPoint pointSprite = CGPointFromString(strPosition);
	return pointSprite;
}

- (BOOL)constructMap:(NSDictionary *)dictSet
{
	// Create our array for storing map nodes
	m_aMapNodes = [[NSMutableArray alloc] initWithCapacity:5];
	layNodePointers = [MRLayer node];
	[self addChild:layNodePointers z:MR_LAYER_UI];


	// Do we have a different text color?
	NSArray *arrColor = [dictSet objectForKey:ENTRY_TEXT_COLOR];
	if (arrColor != nil && [arrColor count] >= 3)
	{
		m_tBundles[0].colorText.r = [[arrColor objectAtIndex:0] integerValue];
		m_tBundles[0].colorText.g = [[arrColor objectAtIndex:1] integerValue];
		m_tBundles[0].colorText.b = [[arrColor objectAtIndex:2] integerValue];
	}

	// Do we have nonstandard screen bounds?
	NSDictionary *dictBounds = [dictSet objectForKey:ENTRY_BOUNDS];
	if (dictBounds != nil && [dictBounds count] > 0)
	{
		m_flXMin = [[dictBounds objectForKey:ENTRY_BOUNDS_LEFT] floatValue];
		m_flXMax = [[dictBounds objectForKey:ENTRY_BOUNDS_RIGHT] floatValue];
		m_flYMin = [[dictBounds objectForKey:ENTRY_BOUNDS_BOTTOM] floatValue];
		m_flYMax = [[dictBounds objectForKey:ENTRY_BOUNDS_TOP] floatValue];
	}

	// Set our background.
	NSString *strBackground = [dictSet objectForKey:ENTRY_BACKGROUND];
	[self setBackground:strBackground intoNode:layBack];

	BOOL fNoStars = [[dictSet objectForKey:ENTRY_NO_STARS] boolValue];
	if (fNoStars == NO)
	{
		// Some sparkly stars.  Need to check for this in level soon.
		for (int i = 0; i < 100; i++)
		{
			MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:@"star.png"];
			MRDefinitionSprite *sprNew = [MRDefinitionSprite spriteWithFrame:frame];
			[sprNew setPosition:MRPoint((random() % 1500 - 768), (random() % 2000) - 1000)];
			[sprNew setScale:MRRandomUnit()];
			[sprNew setColor:MRRGB((random() % 100) + 155, (random() % 100) + 155, (random() % 100) + 155)];
			// Test -- make them "twinkle" in and out...
			id actionTwinkleFade = [MRFadeIn actionWithDuration:(1.0f + MRRandomUnit())];
			[sprNew runAction:[MRRepeatForever actionWithAction:[MRSequence actions:actionTwinkleFade, [actionTwinkleFade reverse], nil]]];
			[laySky addChild:sprNew z:MR_LAYER_FOREGROUND];
		}
	}

	// Create any decorative sprites.
	NSArray *arrSprites = [dictSet objectForKey:MR_ENTRY_SPRITES];
	int nSprites = [arrSprites count];
	for (int i = 0; i < nSprites; ++i)
	{
		NSDictionary *dictSprite = [arrSprites objectAtIndex:i];
		id obSet = [dictSprite objectForKey:MR_ENTRY_SPRITE_SET];
		if (obSet != nil)
		{
			int nSetRequired = [obSet integerValue];
			if (nSetRequired > 0)//  && [MRSceneHost isSetUnlocked:nSetRequired] == NO)
				continue;
		}

//		NSString *strPosition = [dictSprite objectForKey:MR_ENTRY_POSITION];
//		CGPoint pointSprite = CGPointFromString(strPosition);
		CGPoint pointSprite = [self getEntryPosition:dictSprite];
		NSString *strSprite = [dictSprite objectForKey:MR_ENTRY_SPRITE_IMAGE];
		MRDefinitionSprite *sprSprite = [self createAndPlaceSprite:strSprite position:pointSprite inNode:layMain];
		id obScale = [dictSprite objectForKey:MR_ENTRY_SPRITE_SCALE];
		if (obScale != nil)
		{
			float flScale = [obScale floatValue];
			[sprSprite setScale:flScale];
		}
		NSString *strColor = [dictSprite objectForKey:MR_ENTRY_SPRITE_COLOR];
		if (strColor != nil)
		{
			MRColor3B color = [MRUtilities getColor:strColor];
			[sprSprite setColor:color];
		}
		BOOL fRotate = [[dictSprite objectForKey:MR_ENTRY_SPRITE_ROTATE] boolValue];
		if (fRotate)
		{
			// Stop any old actions.
			[self stopActionByTag:MR_TAG_ACTION_SPIN];

			float flSpeed = 2.0f + ((random() % 200) / 10.0f);
			int nReverse = 1;
			if (random() % 2 == 0)
				nReverse = -1;
			id actionRotate		= [MRRotateBy actionWithDuration:flSpeed angle:(nReverse * 360.0f)];
			[actionRotate setTag:MR_TAG_ACTION_SPIN];
			[sprSprite runAction:[MRRepeatForever actionWithAction:actionRotate]];
		}
	}

	// Back button.
	[MRMenuItemText setFontSize:MR_FONT_SIZE_MENU];
	[MRMenuItemText setFontName:@"Futura-CondensedExtraBold"];
	MRMenuItemText *mItem = [MRMenuItemText itemFromString:@"BACK" target:self selector:@selector(back:)];
	[mItem setColor:m_tBundles[0].colorText];
	MRMenu * menu = [MRMenu menuWithItems: mItem, nil]; // you have to terminate the list with nil
	menu.position = MRPoint ( MR_HALF_SCREEN_MINOR, MR_SCREEN_MAJOR * 0.04166f);
	[menu alignItemsHorizontallyWithPadding:10.0f];
	[layText addChild: menu z:MR_LAYER_FOREGROUND];

	return YES;
}

#pragma mark -
#pragma mark Touch - Screen Scrolling

// Screen-scrolling stuff.

- (void)singleTouchBegan:(MRPointerEvent*)touch
{
	// Sound test.
	//[BefuddledAppDelegate soundsPlay:@"astronaut"];

	CGPoint touchLocation = touch.position;
	m_pointTouchStart = touchLocation;
	m_pointLayerStart = layMain.position;
	//NSLog(@"Mission touch began at (%.0f, %.0f).", m_pointTouchStart.x, m_pointTouchStart.y);
}

- (void)singleTouchMoved:(MRPointerEvent*)touch
{
	// Get our adjusted position.
	CGPoint touchLocation = touch.position;
	CGPoint pointNew = touchLocation;
	CGPoint pointDelta = subtract(pointNew, m_pointTouchStart);
	//	NSLog(@"Mission touch moved to (%.0f, %.0f), delta is (%.0f, %.0f).",
	//		  pointNew.x, pointNew.y, pointDelta.x, pointDelta.y);
	CGPoint pointLayer = add(pointDelta, m_pointLayerStart);

	// Make sure we stay within our bounds.
	pointLayer.x = MAX(m_flXMin, pointLayer.x);
	pointLayer.x = MIN(m_flXMax, pointLayer.x);
	pointLayer.y = MAX(m_flYMin, pointLayer.y);
	pointLayer.y = MIN(m_flYMax, pointLayer.y);
	layMain.position = pointLayer;

	laySky.position = MRPoint(pointLayer.x / 2.0, pointLayer.y / 2.0);

	[self updateMapNodePointers];
}

- (void)singleTouchEnded:(MRPointerEvent*)touch
{
	//NSLog(@"Mission touch ended.");
}

-(void) pointersMoved:(NSSet *)touches
{
	MRPointerEvent *touch = [touches anyObject];

	CGPoint touchLocation = touch.position;

	touchLocation = touchLocation;

	NSLog(@"Mission Scene - touch at (%.0f, %.0f)", touchLocation.x, touchLocation.y);

}


@end

#endif
