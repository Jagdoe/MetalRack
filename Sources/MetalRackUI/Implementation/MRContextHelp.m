#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  ContextHelp.m
//  Befuddled2
//
//  Created by Michael Scandizzo on 11/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MRContextHelp.h"
#import "MRUIKit.h"
#import "MRPanel.h"
#import "MRButton.h"
#import "MRTextLabel.h"
#import "MRUtilities.h"
#import "MRGestureLayer.h"
//#import "MRSceneHost.h"
#import "MRUtilities.h"
#import "MRAudio.h"
#import "2DMath.h"

#import "MRPlacementScene.h"

@implementation MRContextHelp

static MRContextHelp	*sgHelpOb = nil;

+ (id)sharedContextHelp
{
	if (sgHelpOb == nil)
	{
		sgHelpOb = [[MRContextHelp alloc] init];
	}
	return sgHelpOb;
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		NSString *path = [MRBundleResources pathForResource:@"context_help.plist"];
		m_dictHelp = [[NSDictionary alloc] initWithContentsOfFile:path];
		m_aHelpStack = [[NSMutableArray alloc] initWithCapacity:5];
		m_strCurrentContext = nil;
	}
	return self;
}

- (id)createHelpLayer
{
//	PlacementScene *scene = (PlacementScene *)[[CCDirector sharedDirector] runningScene];
//	CCNode *oldLayer = [scene getChildByTag:TAG_CONTEXT_HELP_LAYER];
//	if (oldLayer != nil)
//	{
//		return oldLayer;
//	}

	MRGestureLayer *layer = ([[MRGestureLayer alloc] init]);
//	[scene addChild:layer z:99999];
	layer.tag = TAG_CONTEXT_HELP_LAYER;
	[layer setTouchTarget:self];
	layer.isTouchEnabled = YES;
	return layer;
}

- (void)removeHelpLayer
{
	MRPlacementScene *scene = (MRPlacementScene *)[[MRSceneRuntime sharedRuntime] runningScene];
//	[scene removeChildByTag:TAG_CONTEXT_HELP_LAYER cleanup:YES];
	MRNode *layer = [scene getChildByTag:TAG_CONTEXT_HELP_LAYER];
	[layer removeAllChildrenWithCleanup:YES];
	[scene delayedRemoveChildModalLayerWithCleanup:YES];
}

- (id)displayHelpPanelforContext:(NSString *)strContext
{
	// Only allow placement scenes to call this
	MRPlacementScene *scene = (MRPlacementScene *)[[MRSceneRuntime sharedRuntime] runningScene];
	if ([scene isKindOfClass:[MRPlacementScene class]] == NO)
		return nil;

	CGSize sizeScene = scene.contentSize;
	float flSceneWidth = sizeScene.width;
	float flSceneHeight = sizeScene.height;

	// Clean up first, if needed.
	[self removeHelpLayer];

	MRGestureLayer *layer = [self createHelpLayer];

	// Call this on delay so we don't modify our touch list while in a touch callback.
	[scene performSelector:@selector(addChildModalLayer:) withObject:layer afterDelay:0.0f];

    float flDeviceAdjust = [MRUtilities getDeviceScaleAdjustment];
	float flRatioX = flSceneWidth / (320.0f * flDeviceAdjust);
	NSDictionary *dictEntry = [m_dictHelp objectForKey:strContext];
	float flHeight          = [[dictEntry objectForKey:@"height"] floatValue] * flDeviceAdjust;
	NSString *strTitle      = [dictEntry objectForKey:@"title"];
    NSString *strTitleColor = [dictEntry objectForKey:@"title color"];
	NSString *strText       = [dictEntry objectForKey:@"text"];
    BOOL fBuiltInFont		= [[dictEntry objectForKey:@"built-in font"] boolValue];
	CGPoint position	= CGPointFromString([dictEntry objectForKey:@"position"]);

//	C2DSprite *sprPanel = [scene createPanelWithScale:1.1f * flRatioX withHeight:flHeight];
	MRPanel *sprPanel = [MRPanel panelFromDefaults];
	[sprPanel setHeight:flHeight withScale:1.1f * flRatioX];
	[sprPanel setPosition:MRPoint(flSceneWidth * position.x, flSceneHeight * position.y)];
	[layer addChild:sprPanel];

	float flFontSize = 12.0f * flDeviceAdjust;
    float flFontTitle = 16.0f * flDeviceAdjust;
	CGSize sizePanel = [sprPanel contentSize];
	CGSize sizePage = CGSizeMake(sizePanel.width * 0.85f, sizePanel.height);

	MRTextLabel *textTitle = [[MRTextLabel alloc] initWithWord:strTitle fontName:@"cooper" fontSize:flFontTitle];
	CGSize sizeText = [textTitle contentSize];
	sizeText.width *= textTitle.scaleX;
	sizeText.height *= textTitle.scaleY;
    if (strTitleColor != nil)
        [textTitle setColor:[MRUtilities getColor:strTitleColor]];
	[sprPanel addChild:textTitle];


    MRNode *text;
	if (fBuiltInFont == YES)
    {
        text = [MRUtilities createTextRegion:strText size:sizePage fontSize:flFontSize];
    }
    else
    {
        NSString *strFont = [[MRUtilities sharedUtilityManager] getDefaultFont];
        text = [MRTextLabel textWithParagraph:strText fontName:strFont fontSize:flFontSize maxWidth:sizePage.width];
        float flCalcHeight = text.contentSize.height + sizeText.height * 2.0f;
        [sprPanel setHeight:flCalcHeight withScale:1.1f * flRatioX];
        sizePanel = sprPanel.contentSize;
    }
    float flY = sizePanel.height - sizeText.height * 2.5f;
	[textTitle setPosition:MRPoint(sizePanel.width * 0.5f, sizePanel.height - sizeText.height * 1.5f)];

	[text setAnchorPoint:MRPoint(0.5f, 1.0f)];
	[text setPosition:MRPoint(sizePanel.width * 0.5f, flY)];
	[sprPanel addChild:text];

	[sprPanel animateBubbleIn];

	return sprPanel;
}

- (id)createOverlayForDef:(NSDictionary *)dictEntry onLayer:(MRGestureLayer *)layer
{
	MRPlacementScene *scene = (MRPlacementScene *)[[MRSceneRuntime sharedRuntime] runningScene];
	NSString *strImage	= [dictEntry objectForKey:@"image"];
	CGPoint position	= CGPointFromString([dictEntry objectForKey:@"position"]);
	float flRotation	= [[dictEntry objectForKey:@"rotation"] floatValue];
	NSString *strText	= [dictEntry objectForKey:@"text"];
	float flTextWidth	= [[dictEntry objectForKey:@"text width"] floatValue];
	NSString *strEntry	= [dictEntry objectForKey:@"entry"];
	NSString *strColor	= [dictEntry objectForKey:@"color"];

	NSString *strPointAt	= [dictEntry objectForKey:@"point at"];
	CGPoint pointAt			= CGPointFromString(strPointAt);
	BOOL fPointInward		= [[dictEntry objectForKey:@"point inward"] boolValue];
	BOOL fBuiltInFont		= [[dictEntry objectForKey:@"built-in font"] boolValue];

	CGSize sizeScene = scene.contentSize;
	float flSceneWidth = sizeScene.width;
	float flSceneHeight = sizeScene.height;

	MRButton *button = ([[MRButton alloc] initWithFrameName:strImage]);
	CGSize sizeButton = [button contentSize];
	if (strPointAt != nil)
	{
		CGPoint posTarget = MRPoint(flSceneWidth * pointAt.x, flSceneHeight * pointAt.y);
		CGPoint posCenter = MRPoint(flSceneWidth * 0.5f, flSceneHeight * 0.5f);
		if (CGPointEqualToPoint(posCenter, posTarget))
			posCenter = MRPoint(flSceneWidth * 0.5f, flSceneHeight * 0.25f);
		CGPoint vToward = normalize(subtract(posTarget, posCenter));
		CGPoint vUp = MRPoint(0.0f, 1.0f);
		float flRadius = sizeButton.height * 0.5f;
		CGPoint vOffset;
		if (fPointInward == YES)
			vOffset = scale(vToward, flRadius);
		else
			vOffset = scale(vToward, -flRadius);

		// Keep the bubbles on screen
		CGPoint posPlace = add(posTarget, vOffset);
		if (posPlace.x - flRadius < 0)
			posPlace.x = flRadius;
		if (posPlace.x + flRadius >= flSceneWidth)
			posPlace.x = flSceneWidth - flRadius;
		if (posPlace.y - flRadius < 0)
			posPlace.y = flRadius;
		if (posPlace.y + flRadius >= flSceneHeight)
			posPlace.y = flSceneHeight - flRadius;
		vOffset = subtract(posPlace, posTarget);

		CGPoint vFaceToward = scale(vOffset, -1);
		float flAngle = angleBetweenVectors(vFaceToward, vUp);
		[button setPosition:posPlace];
		[button setRotation:flAngle];
		position = MRPoint(posPlace.x / flSceneWidth, posPlace.y / flSceneHeight);
	}
	else
	{
		[button	setPosition:MRPoint(flSceneWidth * position.x, flSceneHeight * position.y)];
		[button setRotation:flRotation];
	}
	if (strColor != nil)
	{
		MRColor3B color = [MRUtilities getColor:strColor];
		[button setDefaultColor:color];
	}
	[layer addChild:button];

	if (strText != nil)
	{
        float flFontSize = 12.0f * [MRUtilities getDeviceScaleAdjustment];
		MRSprite *textTitle;
		if (fBuiltInFont == YES)
		{
			CGSize size = CGSizeMake(sizeButton.width * flTextWidth, sizeButton.height);
			NSString *strFont = @"Helvetica-Bold";
			UIFont *font = [UIFont fontWithName:strFont size:flFontSize];
			size = [strText sizeWithFont:font constrainedToSize:size lineBreakMode:UILineBreakModeWordWrap];

			textTitle = [MRSystemText labelWithString:strText dimensions:size alignment:UITextAlignmentCenter
															 fontName:strFont fontSize:flFontSize];
			[textTitle setColor:MRRGB(0, 0, 0)];
			[textTitle setAnchorPoint:MRPoint(0.5f, 0.5f)];

			MRSystemText *highlightText = [MRSystemText labelWithString:strText dimensions:size alignment:UITextAlignmentCenter
													   fontName:strFont fontSize:flFontSize];
			[highlightText setAnchorPoint:MRPoint(0.0f, 0.0f)];
			[highlightText setPosition:MRPoint(-1, 1)];
			[textTitle addChild:highlightText];
			CGSize sizeText = [textTitle contentSize];
			NSLog(@"Text size: %f, %f", sizeText.width, sizeText.height);
		}
		else
		{
			textTitle = [[MRTextLabel alloc] initWithParagraph:strText fontName:@"cooper" fontSize:flFontSize maxWidth:sizeButton.width * flTextWidth];
		}
		[textTitle setPosition:MRPoint(flSceneWidth * position.x, flSceneHeight * position.y)];
		[layer addChild:textTitle];
		[textTitle setScale:0.1f];
		id actionGrow = [MRScaleTo actionWithDuration:0.2f scale:1.2f];
		id actionShrink = [MRScaleTo actionWithDuration:0.1f scale:1.0f];
		[textTitle runAction:[MRSequence actions:actionGrow, actionShrink, nil]];
	}
	if (strEntry != nil)
		[button addTouchTarget:@selector(touchHelp:) forObject:scene];
	else
		button.enabled = NO;
	button.tagString = strEntry;

	[button animateBubbleIn];

	return button;
}

- (id)displayHelpOverlayForContext:(NSString *)strContext
{
	// Only allow placement scenes to call this
	MRPlacementScene *scene = (MRPlacementScene *)[[MRSceneRuntime sharedRuntime] runningScene];
	if ([scene isKindOfClass:[MRPlacementScene class]] == NO)
		return nil;

	// Clean up first, if needed.
	[self removeHelpLayer];

	MRGestureLayer *layer = [self createHelpLayer];

	// Call this on delay so we don't modify our touch list while in a touch callback.
	[scene performSelector:@selector(addChildModalLayer:) withObject:layer afterDelay:0.0f];

	NSDictionary *dictEntry = [m_dictHelp objectForKey:strContext];
	NSObject *obOverlay = [dictEntry objectForKey:@"overlay"];
	if ([obOverlay isKindOfClass:[NSArray class]] == YES)
	{
		NSArray *aOverlays = (NSArray *)obOverlay;
		for (NSDictionary *dictOverlay in aOverlays)
		{
			[self createOverlayForDef:dictOverlay onLayer:layer];
		}
	}
	else if ([obOverlay isKindOfClass:[NSDictionary class]] == YES)
	{
		NSDictionary *dictOverlay = (NSDictionary *)obOverlay;
		[self createOverlayForDef:dictOverlay onLayer:layer];
	}

	return layer;
}

- (id)displayHelpForContext:(NSString *)strContext
{
	id obDisplay = nil;
	NSDictionary *dictEntry = [m_dictHelp objectForKey:strContext];
	NSString *strType = [dictEntry objectForKey:@"type"];
	if ([strType isEqualToString:@"overlay"] == YES)
	{
		obDisplay = [self displayHelpOverlayForContext:strContext];
	}
	else if ([strType isEqualToString:@"panel"] == YES)
	{
		obDisplay = [self displayHelpPanelforContext:strContext];
	}

	// Don't add us to the stack if we were just popped.
	if ([strContext isEqualToString:[m_aHelpStack lastObject]] == NO)
		[m_aHelpStack addObject:strContext];

	m_strCurrentContext = strContext;

	return obDisplay;
}

- (BOOL)singleTouchBegan:(MRPointerEvent*)touch
{
//	[self performSelector:@selector(removeHelpLayer) withObject:nil afterDelay:0.0f];
	// Abort if any button is currently selected.
	MRPlacementScene *scene = (MRPlacementScene *)[[MRSceneRuntime sharedRuntime] runningScene];
	MRNode *oldLayer = [scene getChildByTag:TAG_CONTEXT_HELP_LAYER];
	NSArray *aChildren = oldLayer.children;

	for (MRNode *node in aChildren)
	{
		if ([node isKindOfClass:[MRButton class]] == YES)
		{
			MRButton *button = (MRButton *)node;
			if ([button hitTest:touch] == YES)
			{
				return NO;
			}
		}
	}

	[[MRAudio sharedAudioManager] soundsPlay:@"pop"];
	// Call this on delay so we don't modify our touch list while in a touch callback.
	[scene delayedRemoveChildModalLayerWithCleanup:YES];

	// Pop our stack
	[m_aHelpStack removeLastObject];
	if ([m_aHelpStack count] > 0)
	{
		NSString *strPrevContext = [m_aHelpStack lastObject];
		[self displayHelpForContext:strPrevContext];
	}

	return YES;
}

- (BOOL)singleTouchMoved:(MRPointerEvent *)touch
{
	return YES;
}

- (BOOL)singleTouchEnded:(MRPointerEvent *)touch
{
	return YES;
}


@end

#endif
