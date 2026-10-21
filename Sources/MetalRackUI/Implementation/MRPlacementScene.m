#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  PlacementScene.h
//  Zombie
//
//  Created by Tom the Mediocre on 8/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRSceneHost.h"
#import "MRUtilities.h"
#import "MRAudio.h"
#import "MRNotifications.h"
#import "MRPlacementScene.h"
#import "MRContextHelp.h"
#import "MRDefinitions.h"
#import "MRTextLabel.h"
#if (COCOS2D_VERSION == 0x00020000)
#else
//#import "TJCOffersWebView.h"
#endif
#import "2DMath.h"

// Macros.

// Statics.


#pragma mark -
#pragma mark ModalData - helper class

// This object stores an instance of a modal state.
// An array of these is stored in PlacementScene to
// allow recursive modal states.
@implementation ModalData

@synthesize aDisabledLayers = m_aDisabledLayers;
@synthesize layerModal = m_layerModal;

@end

#pragma mark -
#pragma mark MRPlacementScene

@implementation MRPlacementScene

@synthesize layNotify = m_layNotify;

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		// Clear all our bundle stuff.
		for (int i = 0; i < MAX_BUNDLES; ++i)
		{
			m_tBundles[i].rectText  = CGRectMake(0.0f, 0.0f, 100.0f, 100.0f);
			m_tBundles[i].colorText = MRRGB(255, 255, 255);
			m_tBundles[i].arrAllVisuals = nil;
			m_tBundles[i].arrSpecialPanels = nil;
			m_tBundles[i].arrSummary = nil;
		}

        m_classGameScene = nil;

		// Set a slow update for notifications.
		m_layNotify = [MRLayer node];
		m_layNotify.isTouchEnabled = YES;
		[self addChild:m_layNotify z:MR_LAYER_NOTIFY];
		m_fShouldUnpause = YES;
		m_flTimeSinceDismissed = 999.0f;

		[self schedule: @selector(notificationsUpdate:) interval:0.25f];

		// Set a layer for transmissions.
		m_layTransmission = [MRLayer node];
		m_layTransmission.isTouchEnabled = YES;
		[self addChild:m_layTransmission z:MR_LAYER_NOTIFY];

		// Set a layer for the purchase screen
		m_layPurchase = [MRLayer node];
		m_layPurchase.isTouchEnabled = YES;
		[self addChild:m_layPurchase z:MR_LAYER_NOTIFY];

		[[MRSceneRuntime sharedRuntime] loadAtlasNamed:@"ui_0.plist"];

		m_strStartupHint = nil;

		// We have no background yet.
		m_strBackgroundImage = nil;

//		m_aModalDisabledLayers = nil;
		m_aModalDataStack = ([NSMutableArray arrayWithCapacity:2]);
	}

	return (self);
}

- (void)dealloc
{
	for (int i = 0; i < MAX_BUNDLES; ++i)
	{
		TPlacementBundle *pBundle = &(m_tBundles[i]);
		[pBundle->arrSummary removeAllObjects];
		(void)0;
		pBundle->arrSummary = nil;

		[pBundle->arrSpecialPanels removeAllObjects];
		(void)0;
		pBundle->arrSpecialPanels = nil;

		[pBundle->arrAllVisuals removeAllObjects];
		(void)0;
		pBundle->arrAllVisuals = nil;
	}

	// Get rid of our update.
	[self unschedule:@selector(notificationsUpdate:)];

	// Get rid of our background.
	if (m_strBackgroundImage != nil)
	{
		[[MRSceneRuntime sharedRuntime] removeImageNamed:m_strBackgroundImage];
		m_strBackgroundImage = nil;
	}

	// Lastly, do parent stuff.
	(void)0;
}

//#pragma mark -
//#pragma mark Private Routines

#pragma mark -
#pragma mark Standard Interface

- (void)setBackground:(NSString*)strBackground intoNode:(MRNode*)node
{
	// If we're setting a different background to what we already have, clear the old and re-do.
	if ([strBackground isEqualToString:m_strBackgroundImage] == NO)
	{
		// Get rid of our old background.
		if (m_strBackgroundImage != nil)
		{
			[[MRSceneRuntime sharedRuntime] removeImageNamed:m_strBackgroundImage];
			(void)0;
			m_strBackgroundImage = nil;
		}

		m_strBackgroundImage = ([NSString stringWithString:strBackground]);
	}

	// Now set the new background.
	MRTexture *texture = [[MRSceneRuntime sharedRuntime] textureNamed:m_strBackgroundImage];
	MRDefinitionSprite * bg = [MRDefinitionSprite spriteWithTexture:texture];
//	if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) == YES)
//		[bg setPosition:ccp(MR_HALF_SCREEN_MAJOR, MR_HALF_SCREEN_MINOR)];
//	else
		[bg setPosition:MRPoint(MR_HALF_SCREEN_MINOR, MR_HALF_SCREEN_MAJOR)];
	CGSize sizeBackground = [bg contentSize];
	[bg setScaleX:MR_SCREEN_MINOR/sizeBackground.width];
	[bg setScaleY:MR_SCREEN_MAJOR/sizeBackground.height];
	[node addChild:bg z:MR_LAYER_BACK];
}

- (id)createAndPlaceSprite:(NSString *)strName position:(CGPoint)Position inNode:(MRNode*)node
{
	// Try to create from a full definition first, then just use the single image if needed.
	NSDictionary *dictMaster = [[MRDefinitions sharedDefsManager] getDefByName:strName];
	MRDefinitionSprite *sprNew = [MRDefinitionSprite createIconFromDefinition:dictMaster];
	if (sprNew == nil)
	{
		MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:strName];
		sprNew = [MRDefinitionSprite spriteWithFrame:frame];
	}
	[sprNew setPosition:Position];
	[node addChild:sprNew z:MR_LAYER_FOREGROUND];
	return sprNew;
}

- (id)createAndPlaceButton:(NSString *)strName position:(CGPoint)Position inNode:(MRNode*)node selector:(SEL)selTouch
{
	MRButton *button = ([[MRButton alloc] initWithFrameName:strName]);
	[button addTouchTarget:selTouch forObject:self];
	[button setPosition:Position];
	[node addChild:button z:MR_LAYER_FOREGROUND];
	return button;
}

- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle withDimensions:(CGSize)dimensions withPosition:(CGPoint)Position inNode:(MRNode*)node withBundle:(int)nBundle
{
	return [self createText:strText
				  withStyle:eStyle
			 withDimensions:dimensions
				   position:Position
				   withFont:[[MRUtilities sharedUtilityManager] getDefaultFontCachedFast]
			   withFontSize:MR_DEFAULT_FONT_SIZE
					 inNode:node
				 withBundle:nBundle];
}

- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle withDimensions:(CGSize)dimensions position:(CGPoint)Position withFont:(NSString*)strFont withFontSize:(float)flFontSize inNode:(MRNode*)node withBundle:(int)nBundle
{
	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);
	if (eStyle == ELT_SHADOW || eStyle == ELT_OUTLINE)
	{
		float flDistance = 1.0f;
		if (eStyle == ELT_OUTLINE)
			flDistance = 1.0f;

		// Down-right
		MRSystemText *labelShadow = [MRSystemText labelWithString:strText dimensions:dimensions alignment:UITextAlignmentCenter fontName:strFont fontSize:flFontSize];
		[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
		[labelShadow setPosition:MRPoint(Position.x + flDistance, Position.y - flDistance)];
		[labelShadow setColor:MRRGB(0, 0, 0)];
		[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
		[pBundle->arrSummary addObject:labelShadow];

		if (eStyle == ELT_OUTLINE)
		{
			// Up-Left
			labelShadow = [MRSystemText labelWithString:strText dimensions:dimensions alignment:UITextAlignmentCenter fontName:strFont fontSize:flFontSize];
			[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
			[labelShadow setPosition:MRPoint(Position.x - flDistance, Position.y + flDistance)];
			[labelShadow setColor:MRRGB(0, 0, 0)];
			[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
			[pBundle->arrSummary addObject:labelShadow];

			// Down-Left
			labelShadow = [MRSystemText labelWithString:strText dimensions:dimensions alignment:UITextAlignmentCenter fontName:strFont fontSize:flFontSize];
			[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
			[labelShadow setPosition:MRPoint(Position.x - flDistance, Position.y - flDistance)];
			[labelShadow setColor:MRRGB(0, 0, 0)];
			[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
			[pBundle->arrSummary addObject:labelShadow];

			// Up-Right
			labelShadow = [MRSystemText labelWithString:strText dimensions:dimensions alignment:UITextAlignmentCenter fontName:strFont fontSize:flFontSize];
			[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
			[labelShadow setPosition:MRPoint(Position.x + flDistance, Position.y + flDistance)];
			[labelShadow setColor:MRRGB(0, 0, 0)];
			[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
			[pBundle->arrSummary addObject:labelShadow];
		}
	}

	MRSystemText *labelText = [MRSystemText labelWithString:strText dimensions:dimensions alignment:UITextAlignmentCenter fontName:strFont fontSize:flFontSize];
	[labelText setAnchorPoint:MRPoint(0.5, 1.0f)];
	[labelText setPosition:Position];
	[labelText setColor:pBundle->colorText];
	[node addChild:labelText z:MR_LAYER_FOREGROUND];
	[pBundle->arrSummary addObject:labelText];

	return labelText;
}

- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle  position:(CGPoint)Position inNode:(MRNode*)node withBundle:(int)nBundle
{
	float flScaleAdjust = [MRUtilities getDeviceScaleAdjustment];
	return [self createText:strText
				  withStyle:eStyle
				   position:Position
				   withFont:[[MRUtilities sharedUtilityManager] getDefaultFontCachedFast]
			   withFontSize:MR_DEFAULT_FONT_SIZE * flScaleAdjust
					 inNode:node
				 withBundle:nBundle];
}

- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle position:(CGPoint)Position withFont:(NSString*)strFont withFontSize:(float)flFontSize inNode:(MRNode*)node withBundle:(int)nBundle
{
	// Doing this without dimensions is apparently much faster run-time (per cycle) than with, so we'll actually
	// duplicate the code.  Oh, joy.
	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);
	if (eStyle == ELT_SHADOW || eStyle == ELT_OUTLINE)
	{
		float flDistance = 1.0f;
		if (eStyle == ELT_OUTLINE)
			flDistance = 1.0f;

		// Down-right
		MRSystemText *labelShadow = [MRSystemText labelWithString:strText fontName:strFont fontSize:flFontSize];
		[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
		[labelShadow setPosition:MRPoint(Position.x + flDistance, Position.y - flDistance)];
		[labelShadow setColor:MRRGB(0, 0, 0)];
		[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
		[pBundle->arrSummary addObject:labelShadow];

		if (eStyle == ELT_OUTLINE)
		{
			// Up-Left
			labelShadow = [MRSystemText labelWithString:strText fontName:strFont fontSize:flFontSize];
			[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
			[labelShadow setPosition:MRPoint(Position.x - flDistance, Position.y + flDistance)];
			[labelShadow setColor:MRRGB(0, 0, 0)];
			[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
			[pBundle->arrSummary addObject:labelShadow];

			// Down-Left
			labelShadow = [MRSystemText labelWithString:strText fontName:strFont fontSize:flFontSize];
			[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
			[labelShadow setPosition:MRPoint(Position.x - flDistance, Position.y - flDistance)];
			[labelShadow setColor:MRRGB(0, 0, 0)];
			[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
			[pBundle->arrSummary addObject:labelShadow];

			// Up-Right
			labelShadow = [MRSystemText labelWithString:strText fontName:strFont fontSize:flFontSize];
			[labelShadow setAnchorPoint:MRPoint(0.5, 1.0f)];
			[labelShadow setPosition:MRPoint(Position.x + flDistance, Position.y + flDistance)];
			[labelShadow setColor:MRRGB(0, 0, 0)];
			[node addChild:labelShadow z:MR_LAYER_FOREGROUND];
			[pBundle->arrSummary addObject:labelShadow];
		}
	}

	MRSystemText *labelText = [MRSystemText labelWithString:strText fontName:strFont fontSize:flFontSize];
	[labelText setAnchorPoint:MRPoint(0.5, 1.0f)];
	[labelText setPosition:Position];
	[labelText setColor:pBundle->colorText];
	[node addChild:labelText z:(MR_LAYER_FOREGROUND)];
	[pBundle->arrSummary addObject:labelText];

	return labelText;
}

- (MRSystemText *)createRegionText:(NSString *)strText atVertical:(float)flYPos withFont:(NSString*)strFont withFontSize:(int)nFontSize inNode:(MRNode*)node withBundle:(int)nBundle
{
	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);
	CGSize size = pBundle->rectText.size;

	// Get the actual size we'll need.
	UIFont *font = [UIFont fontWithName:strFont size:nFontSize];
	size = [strText sizeWithFont:font constrainedToSize:size lineBreakMode:UILineBreakModeWordWrap];

	// Make the text...
	MRSystemText *labelText = [MRSystemText labelWithString:strText dimensions:size alignment:UITextAlignmentLeft
										 fontName:strFont fontSize:nFontSize];
	[node addChild:labelText z:MR_LAYER_FOREGROUND];
	[m_tBundles[nBundle].arrAllVisuals addObject:labelText];

	// Figure out where we are.
	float flY = flYPos;
	float flX = pBundle->rectText.origin.x;
	[labelText setAnchorPoint:MRPoint(0.0f, 1.0f)];
	[labelText setPosition:MRPoint(flX, flY)];

	[pBundle->arrSummary addObject:labelText];

	return labelText;
}

- (MRSystemText *)createRegionText:(NSString *)strText atLine:(float)flLine withFont:(NSString*)strFont withFontSize:(int)nFontSize inNode:(MRNode*)node withBundle:(int)nBundle
{
	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);

	// Figure out where we are.
	float flY = pBundle->rectText.origin.y - (MR_DEFAULT_FONT_SIZE * flLine); // Still using default line size for now.

	return [self createRegionText:strText
					   atVertical:flY
						 withFont:strFont
					 withFontSize:nFontSize
						   inNode:node
					   withBundle:nBundle];
}

- (MRSystemText *)createRegionText:(NSString *)strText atLine:(float)flLine inNode:(MRNode*)node withBundle:(int)nBundle
{
	return [self createRegionText:strText
						   atLine:flLine
						 withFont:[[MRUtilities sharedUtilityManager] getDefaultFontCachedFast]
					 withFontSize:MR_DEFAULT_FONT_SIZE
						   inNode:node
					   withBundle:nBundle];
}

- (MRSystemText *)createRegionText:(NSString *)strText belowText:(MRSystemText *)labelAbove withFont:(NSString*)strFont withFontSize:(int)nFontSize inNode:(MRNode*)node withBundle:(int)nBundle
{
	// If we don't specify a label, put us at line zero.
	if (labelAbove == nil)
		return [self createRegionText:strText
							   atLine:0.0f
							 withFont:strFont
						 withFontSize:nFontSize
							   inNode:node
						   withBundle:nBundle];

	// Put us right below where the previous label was.
	float flY = labelAbove.position.y - labelAbove.contentSize.height;

	return [self createRegionText:strText
					   atVertical:flY
						 withFont:strFont
					 withFontSize:nFontSize
						   inNode:node
					   withBundle:nBundle];
}

- (MRSystemText *)createRegionText:(NSString *)strText belowText:(MRSystemText *)labelAbove inNode:(MRNode*)node withBundle:(int)nBundle
{
	return [self createRegionText:strText
						belowText:labelAbove
						 withFont:[[MRUtilities sharedUtilityManager] getDefaultFontCachedFast]
					 withFontSize:MR_DEFAULT_FONT_SIZE
						   inNode:node
					   withBundle:nBundle];
}

- (MRSystemText *)createItemCountEntry:(NSString *)strItem withCount:(int)nCount ofTotal:(int)nTotal inSlot:(int)nSlot inNode:(MRNode*)node withBundle:(int)nBundle
{
	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);
	if (nSlot >= [pBundle->arrSpecialPanels count])
		return nil;

	// Put the image in the node.
	NSDictionary *defItem = [[MRDefinitions sharedDefsManager] getDefByName:strItem];
	MRDefinitionSprite *spriteItem = [MRDefinitionSprite createIconFromDefinition:defItem];
	MRNode *nodeItem = [pBundle->arrSpecialPanels objectAtIndex:nSlot];
	[nodeItem addChild:spriteItem];
	[pBundle->arrSummary addObject:spriteItem];
	CGRect rectSprite = [spriteItem boundingBox];
	CGSize sizeNode = nodeItem.contentSize;
	CGSize sizeSprite = rectSprite.size;
	[spriteItem setAnchorPoint:MRPoint(0.5f, 0.0f)];
	spriteItem.position = MRPoint(sizeNode.width / 2.0f, 5 - (rectSprite.origin.y/ 2.0f) );

	// Let's make sure the sprite isn't bigger than, say, 90% of the container.
	float flScale = 1.0f;
	float flMaxWidth = nodeItem.contentSize.width * 0.80f;
	if (sizeSprite.width > flMaxWidth)
		flScale = flMaxWidth / (sizeSprite.width);
	float flMaxHeight = nodeItem.contentSize.height * 0.80f;
	if (sizeSprite.height > flMaxHeight)
		flScale = MIN(flScale, flMaxHeight / (sizeSprite.height));
	[spriteItem setScale:flScale];

	// Put the text number next to the node.
	NSString *strValue = [MRUtilities getFormattedNumber:(float)nCount];
	MRSystemText *labelItem = [MRSystemText labelWithString:strValue fontName:[[MRUtilities sharedUtilityManager] getDefaultFontCachedFast] fontSize:MR_DEFAULT_FONT_SIZE];
	[labelItem setAnchorPoint:MRPoint(0.0f, 0.5f)];
	float flStartY = sizeNode.height / 2.0f;
	// -1 will mean don't show total.
	if (nTotal >= 0)
	{
		NSString *strTotal = [NSString stringWithFormat:@"(of %@)", [MRUtilities getFormattedNumber:(float)nTotal]];
		MRSystemText *labelTotal = [MRSystemText labelWithString:strTotal fontName:[[MRUtilities sharedUtilityManager] getDefaultFontCachedFast] fontSize:MR_DEFAULT_FONT_SIZE];
		[labelTotal setAnchorPoint:MRPoint(0.0f, 0.5f)];
		flStartY += (MR_DEFAULT_FONT_SIZE / 2.0f);
		[labelTotal setPosition:MRPoint(nodeItem.position.x + sizeNode.width + 8, nodeItem.position.y - flStartY)];
		flStartY -= MR_DEFAULT_FONT_SIZE;
		[node addChild:labelTotal z:(MR_LAYER_FOREGROUND+1)];
		[pBundle->arrSummary addObject:labelTotal];
	}
	[labelItem setPosition:MRPoint(nodeItem.position.x + sizeNode.width + 8, nodeItem.position.y - flStartY)];
	[node addChild:labelItem z:(MR_LAYER_FOREGROUND+1)];
	[pBundle->arrSummary addObject:labelItem];

	// Set our text tag.
	if ([nodeItem isKindOfClass:[MRButton class]])
	{
		MRButton* buttonNode = (MRButton*)nodeItem;
		buttonNode.tagString = strItem;
	}

	return labelItem;
}

- (MRDefinitionSprite*)createNamedImage:(NSString*)strImage withLabel:(NSString*)strLabel withTag:(NSString*)strTag inSlot:(int)nSlot inNode:(MRNode*)node withBundle:(int)nBundle
{
	// Just use white for the color.
	return [self createNamedImage:strImage withLabel:strLabel withColor:@"whitePure" withTag:strTag inSlot:nSlot inNode:node withBundle:nBundle];
}

- (MRDefinitionSprite*)createNamedImage:(NSString*)strImage withLabel:(NSString*)strLabel withColor:(NSString*)strColor withTag:(NSString*)strTag inSlot:(int)nSlot inNode:(MRNode*)node withBundle:(int)nBundle
{
	// This one places the image and text directly on the button.  Used for quests, etc.

	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);
	if (nSlot >= [pBundle->arrSpecialPanels count] || nSlot < 0)
		return nil;

	// Put the image in the node.
	MRNode *nodeItem = [pBundle->arrSpecialPanels objectAtIndex:nSlot];
	CGSize sizeNode = nodeItem.contentSize;
	MRDefinitionSprite *spriteItem = nil;

	// For our image -- start by trying to create a composite image from the definition.
	// If that fails, just use the specified PNG.
	NSDictionary *dictMaster = [[MRDefinitions sharedDefsManager] getDefByName:strImage];
	if (dictMaster != nil)
		spriteItem = [MRDefinitionSprite createIconFromDefinition:dictMaster];

	if (spriteItem == nil)
	{
		if (strImage == nil)
		{
			NSLog(@"Placement Warning -- no master item found for [%@]", strImage);
			strImage = @"asteroid.png";
		}
		MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:strImage];
		spriteItem = [MRDefinitionSprite spriteWithFrame:frame];
	}

	if (spriteItem != nil)
	{
		[nodeItem addChild:spriteItem];

		CGRect rectSprite = [spriteItem boundingBox];
//		CGSize sizeNode = nodeItem.contentSize;
		CGSize sizeSprite = rectSprite.size;
		[spriteItem setAnchorPoint:MRPoint(0.5f, 0.0f)];
		spriteItem.position = MRPoint(sizeNode.width / 2.0f, 10 - (rectSprite.origin.y / 2.0f) );

		// Let's make sure the sprite isn't bigger than, say, 90% of the container.
		float flScale = 1.0f;
		float flMaxWidth = nodeItem.contentSize.width * 0.80f;
		if (sizeSprite.width > flMaxWidth)
			flScale = flMaxWidth / (sizeSprite.width);
		float flMaxHeight = nodeItem.contentSize.height * 0.80f;
		if (sizeSprite.height > flMaxHeight)
			flScale = MIN(flScale, flMaxHeight / (sizeSprite.height));
		[spriteItem setScale:flScale];

		[pBundle->arrSummary addObject:spriteItem];
	}

	// Put the text inside of the node.
	MRSystemText *label = [self createText:strLabel
			withStyle:ELT_OUTLINE
	   withDimensions:sizeNode
		 withPosition:MRPoint(sizeNode.width / 2.0f, sizeNode.height * 3.0 / 4.0f)
			   inNode:nodeItem
		   withBundle:nBundle];
	[label setColor:[MRUtilities getColor:strColor]];

//	[labelItem setAnchorPoint:ccp(0.5f, 0.5f)];
//	[labelItem setPosition:ccp(sizeNode.width / 2.0f, (sizeNode.height / 2.0f))];

	// Set our text tag.
	if ([nodeItem isKindOfClass:[MRButton class]])
	{
		MRButton* buttonNode = (MRButton*)nodeItem;
		buttonNode.tagString = strTag;
	}

	return spriteItem;
}

- (void)setTextRegion:(CGRect)rectText withBundle:(int)nBundle
{
	m_tBundles[nBundle].rectText = rectText;
}

- (MRSystemText *)localLabelSummaryItem:(NSString*)strItem withItem:(int)nItem withBundle:(int)nBundle
{
	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);

	MRColor3B colLabel = [MRUtilities getColor:@"blackPure"];
	MRNode *nodeItem = [pBundle->arrSpecialPanels objectAtIndex:nItem];
	CGSize sizeNode = nodeItem.contentSize;
	MRSystemText *labelItem = [self createText:strItem withStyle:ELT_NORMAL position:MRPoint(8, 40) inNode:nodeItem withBundle:nBundle];
	[labelItem setAnchorPoint:MRPoint(1.0f, 1.0f)];
	CGPoint pointText = MRPoint(sizeNode.width - 8, sizeNode.height - 8);
	[labelItem setPosition:pointText];
	[labelItem setColor:colLabel];

	return labelItem;
}

- (void)buildSummaryWithItems:(TSpriteData*)spriteList  withSpriteCount:(int)nSpriteCount
			 withSpecialItems:(TSpriteData*)specialList withSpecialCount:(int)nSpecialCount
			 withBackPosition:(CGPoint)pointBack withBackScale:(CGPoint)scale
					  inNode:(MRNode*)node
				   withBundle:(int)nBundle
{
	[self clearAllPlacement:nBundle];

	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);

	// First put a bunch of non-interactive sprites down...
	pBundle->arrAllVisuals = [[NSMutableArray alloc] initWithCapacity:(nSpriteCount + nSpecialCount)];
	for (int i = 0; i < nSpriteCount; ++i)
	{
		MRButton *sprItem = nil;
		if (spriteList[i].strSelector == nil)
		{
			sprItem = [self createAndPlaceSprite:spriteList[i].strSprite
										position:spriteList[i].pointPosition
										 inNode:node];
			if (spriteList[i].strColor != nil)
			{
				MRColor3B colItem = [MRUtilities getColor:spriteList[i].strColor];
				[sprItem setColor:colItem];
			}
		}
		else
		{
			SEL selButton = NSSelectorFromString(spriteList[i].strSelector);
			sprItem = [self createAndPlaceButton:spriteList[i].strSprite
										position:spriteList[i].pointPosition
										 inNode:node
										selector:selButton];
			[sprItem setShrinkOnTouch:NO];
			sprItem.tag = i;
			if (spriteList[i].strColor != nil)
			{
				MRColor3B colItem = [MRUtilities getColor:spriteList[i].strColor];
				[sprItem setDefaultColor:colItem];
			}
		}
		// We can do text whether or not we are a button.
		if (spriteList[i].strDisplay != nil)
		{
			[sprItem setText:spriteList[i].strDisplay];
		}
		[sprItem setAnchorPoint:MRPoint(0.0f, 1.0f)];
		[pBundle->arrAllVisuals addObject:sprItem];
	}

	// Do the same thing for the special sprites, but keep a reference around.
	pBundle->arrSpecialPanels = [[NSMutableArray alloc] initWithCapacity:8];
	for (int i = 0; i < nSpecialCount; ++i)
	{
		MRButton *sprItem = nil;
		if (specialList[i].strSelector == nil)
		{
			sprItem = [self createAndPlaceSprite:specialList[i].strSprite
												   position:specialList[i].pointPosition
													 inNode:node];
			if (specialList[i].strColor != nil)
			{
				MRColor3B colItem = [MRUtilities getColor:specialList[i].strColor];
				[sprItem setColor:colItem];
			}
		}
		else
		{
			SEL selButton = NSSelectorFromString(specialList[i].strSelector);
			sprItem = [self createAndPlaceButton:specialList[i].strSprite
										position:specialList[i].pointPosition
										  inNode:node
										selector:selButton];
			[sprItem setShrinkOnTouch:NO];
			sprItem.tag = i;
			if (specialList[i].strColor != nil)
			{
				MRColor3B colItem = [MRUtilities getColor:specialList[i].strColor];
				[sprItem setDefaultColor:colItem];
			}
		}
		// We can do text whether or not we are a button.
		if (specialList[i].strDisplay != nil)
			[sprItem setText:specialList[i].strDisplay];

		[pBundle->arrSpecialPanels addObject:sprItem];
		[pBundle->arrAllVisuals addObject:sprItem];
		[sprItem setAnchorPoint:MRPoint(0.0f, 1.0f)];
	}

	// Put a black background behind this area.
//	C2DSprite *sprItem = [self createAndPlaceSprite:@"tech_background.png"
//										   position:ccp(pointBack.x, pointBack.y) inNode:node];
//	[pBundle->arrAllVisuals addObject:sprItem];
//	[node removeChild:sprItem cleanup:NO];
//	[node addChild:sprItem z:(ZPLANE_FRONT - 1)];
//	[sprItem setAnchorPoint:ccp(0.0f, 1.0f)];
//	[sprItem setOpacity:204];
//	[sprItem setScaleX:scale.x];
//	[sprItem setScaleY:scale.y];

	// Our items will have references stored in here.
	pBundle->arrSummary    = [[NSMutableArray alloc] initWithCapacity:32];
}

- (void)clearSummary:(int)nBundle
{
	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);

	// Remove existing items...
	while ([pBundle->arrSummary count] > 0)
	{
		MRNode *nodeItem = [pBundle->arrSummary lastObject];
		[pBundle->arrSummary removeLastObject];
		// If we were doubly-placed ino the arrAllVisuals list, remove from there also!
		if ([pBundle->arrAllVisuals containsObject:nodeItem])
		{
			// Remove him but don't clean him ... we only want to do that once!
			[pBundle->arrAllVisuals removeObject:nodeItem];
		}
		[nodeItem.parent removeChild:nodeItem cleanup:YES];
	}
}

- (void)clearAllPlacement:(int)nBundle
{
	//NSLog(@"Beginning Clearing Placement, Bundle #%d", nBundle);

	[self clearSummary:nBundle];

	TPlacementBundle *pBundle = &(m_tBundles[nBundle]);

	while ([pBundle->arrAllVisuals count] > 0)
	{
		MRNode *nodeItem = [pBundle->arrAllVisuals lastObject];
		[pBundle->arrAllVisuals removeLastObject];
		[nodeItem.parent removeChild:nodeItem cleanup:YES];
		nodeItem = nil;
	}
	(void)0;
	pBundle->arrAllVisuals = nil;

	[pBundle->arrSpecialPanels removeAllObjects];
	(void)0;
	pBundle->arrSpecialPanels = nil;

	//NSLog(@"Completed Clearing Placement, Bundle #%d", nBundle);
}

- (void)setHint:(NSString*)strHint
{
	m_strStartupHint = strHint;
}

- (float)addTextLine:(NSString *)strFirst endingWith:(NSString *)strLast posY:(float)flY inLayer:(MRLayer*)layer
{
    MRColor3B colGrey = [MRUtilities getColor:@"grey90"];
    return [self addTextLine:strFirst endingWith:strLast posY:flY inLayer:layer withColor:colGrey];
}

- (float)addTextLine:(NSString *)strFirst endingWith:(NSString *)strLast posY:(float)flY inLayer:(MRLayer*)layer withColor:(MRColor3B)colText
{
    float flWidth = MR_SCREEN_MINOR * 0.875f;
    return [self addTextLine:strFirst endingWith:strLast posY:flY inLayer:layer withColor:colText withWidth:flWidth];
}

- (float)addTextLine:(NSString *)strFirst endingWith:(NSString *)strLast posY:(float)flY inLayer:(MRLayer*)layer withColor:(MRColor3B)colText withWidth:(float)flWidth
{
    float flScaleAdjustment = [MRUtilities getDeviceScaleAdjustment];

    //    float flMaxWidth = MR_SCREEN_MINOR - (120.0f * flScaleAdjustment);
    float flMaxWidth = flWidth;// * flScaleAdjustment;
    int nFontSize = 16.0f * flScaleAdjustment;
    NSString *strFont = @"TimesNewRomanPSMT";

    UIFont *font = [UIFont fontWithName:strFont size:nFontSize];
    NSString *strDot = @" .";
    NSString *strRest = [NSString stringWithFormat:@"%@%@", strDot, strLast];
    CGSize sizeText1 = [strFirst sizeWithFont:font];
    CGSize sizeText2 = [strRest sizeWithFont:font];
    while (sizeText1.width + sizeText2.width < flMaxWidth)
    {
        strDot = [NSString stringWithFormat:@"%@ .", strDot];
        strRest = [NSString stringWithFormat:@"%@%@", strDot, strLast];
        sizeText2 = [strRest sizeWithFont:font];
    }

    MRSystemText *labelText = [MRSystemText labelWithString:strFirst fontName:strFont fontSize:nFontSize];
    [labelText setColor:colText];
    [labelText setAnchorPoint:MRPoint(0, 0)];
    [labelText setPosition:MRPoint((MR_SCREEN_MINOR - flMaxWidth) / 2, flY)];
    [layer addChild:labelText];

    labelText = [MRSystemText labelWithString:strRest fontName:strFont fontSize:nFontSize];
    [labelText setColor:colText];
    [labelText setAnchorPoint:MRPoint(1.0, 0)];
    [labelText setPosition:MRPoint(flMaxWidth + (MR_SCREEN_MINOR - flMaxWidth) / 2, flY)];
    [layer addChild:labelText];
    return [labelText contentSize].height;
}

- (MRDefinitionSprite*)createBubbleNumber:(int)nValue
{
    MRDefinitionSprite *sprCircle = nil;

    if (nValue < 10)
    {
        sprCircle = [MRDefinitionSprite spriteWithFrameName:@"tabbar_circle.png"];
    }
    else
    {
        sprCircle = [MRDefinitionSprite spriteWithFrameName:@"tabbar_circle_big.png"];
    }

    //    [sprCircle setScale:1.25f];

    int nDisplay = nValue; // Number of uses left
    if (nDisplay > 999)
        nDisplay = 999;
    CGSize sizeCircle = [sprCircle contentSize];
    NSString *strNumber = [NSString stringWithFormat:@"%d", nDisplay];
    float flScaleAdjust = [MRUtilities getDeviceScaleAdjustment];
    NSString *strFont = [[MRUtilities sharedUtilityManager] getDefaultFont];
    MRTextLabel *text = [[MRTextLabel alloc] initWithWord:strNumber fontName:strFont fontSize:10 * flScaleAdjust];
    [text setPosition:MRPoint(sizeCircle.width * 0.5f, sizeCircle.height * 0.5f)];
    [sprCircle addChild:text];

    return sprCircle;
}

#pragma mark -
#pragma mark Notifications

- (void)localPauseForNotification
{
	// Pause everything, if not already paused.
	MRSceneRuntime *director = [MRSceneRuntime sharedRuntime];
	if ([director isPaused] == YES)
		m_fShouldUnpause = NO;
	else
		m_fShouldUnpause = YES;
    if (m_classGameScene != nil && [director.runningScene isKindOfClass:m_classGameScene])
    {
		[director pause];
    }
}

- (void)localDoNothing:(id)idSender
{
	// Just a placeholder -- don't do anything at all.
}

- (BOOL)notificationAddWithTitle:(NSString*)strTitle withButtonTitle:(NSString*)strButtonTitle withButtonSelector:(SEL)selOkay withText:(NSString*)strText withIcon:(NSString*)strIcon withSecondSelector:(SEL)selector withSecondSelectorTitle:(NSString*)strSelectorTitle withColor:(NSString*)strColor
{
	// For the moment, just pass this on through for a common choke point.
    MRNotifications *note = [MRNotifications sharedNotificationManager];
	return [note notificationAddWithTitle:strTitle withButtonTitle:strButtonTitle withButtonSelector:selOkay withText:strText withIcon:strIcon withSelector:selector withSelectorTitle:strSelectorTitle withColor:strColor];
}

// Are notifications active or pending, or various other "modal" stuff?
- (BOOL)notificationsAreActive
{
	return NO;
}

- (BOOL)showOneTimeNotifyMessage:(NSString*)strMessage withTitle:(NSString*)strTitle forKey:(NSString*)strKey
{

	if (strKey == nil || [strKey length] < 1)
		return NO;
	if (strMessage == nil || [strMessage length] < 1)
		return NO;

	// If we haven't done this action before, show some information.
	if ([MRUtilities getContentStatusForKey:strKey] == NO)
	{
		[MRUtilities setContentStatusForKey:strKey asActive:YES];
		[self notificationAddWithTitle:strTitle
					   withButtonTitle:nil
					withButtonSelector:nil
							  withText:strMessage
							  withIcon:nil
						  withSecondSelector:nil
					 withSecondSelectorTitle:nil
							 withColor:nil];
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Friend Bonus Notifications (non-modal)

- (void)doBubbleMessage:(NSString*)strMessage withColor:(NSString *)strColor
{
    if ([strMessage length] < 1)
        return;

    NSLog(@"Bubble -- [%@]", strMessage);

    float flScaleAdjust = [MRUtilities getDeviceScaleAdjustment];
    float flAdjustDown = 0.05f;

    if (strColor == nil)
        strColor = @"bluePale0";
    MRColor3B colorBlue = [MRUtilities getColor:strColor];

    MRDefinitionSprite *nodeParent = [MRDefinitionSprite node];
    [m_layNotify addChild:nodeParent];

    // Start these offscreen
    float flXPos = MR_SCREEN_MINOR;
    float flYPos = MR_SCREEN_MAJOR * (0.916667f - flAdjustDown);

    MRDefinitionSprite *sprPanel = [MRDefinitionSprite spriteWithFrameName:@"text_bubble_top.png"];
    [sprPanel setAnchorPoint:MRPoint(0.0f, 1.0f)];
    [sprPanel setPosition:MRPoint(flXPos, flYPos)];
    [sprPanel setColor:colorBlue];
    [sprPanel setOpacity:192];
    [nodeParent addChild:sprPanel];


    flYPos -= [sprPanel contentSize].height - 0.5f;
    sprPanel = [MRDefinitionSprite spriteWithFrameName:@"text_bubble_bottom.png"];
    [sprPanel setAnchorPoint:MRPoint(0.0f, 1.0f)];
    [sprPanel setPosition:MRPoint(flXPos, flYPos)];
    [sprPanel setColor:colorBlue];
    [sprPanel setOpacity:192];
    [nodeParent addChild:sprPanel];

    flXPos = MR_SCREEN_MINOR + (20 * flScaleAdjust);
//    flYPos = MR_SCREEN_MAJOR * (0.83f - flAdjustDown);

    float flSlideOutWidth = sprPanel.contentSize.width * 0.80f;
    float flMaxWidth = flSlideOutWidth * 0.85;
    MRTextLabel *text = ([[MRTextLabel alloc] initWithParagraph:strMessage fontName:@"cooper" fontSize:(14 * flScaleAdjust) maxWidth:flMaxWidth]);
    [text setAnchorPoint:MRPoint(0.0f, 0.5f)];
    [text setPosition:MRPoint(flXPos, flYPos)];
    [nodeParent addChild:text];

    float flDuration = 0.5f;
    CGPoint posMove = CGPointMake(-flSlideOutWidth, 0);
    id actionSlideLeft  = [MREaseOut actionWithAction:[MRMoveBy actionWithDuration:flDuration position:posMove] rate:3.0f];
    id actionDelay      = [MRDelayTime actionWithDuration:2.0f];
    id actionSlideRight = [actionSlideLeft reverse];
    id actionDie        = [MRCallFunc actionWithTarget:nodeParent selector:@selector(suicide)];

    [nodeParent runAction:[MRSequence actions:actionSlideLeft, actionDelay, actionSlideRight, actionDie, nil]];
    [[MRAudio sharedAudioManager] soundsPlay:@"hiss"];
}

- (void)createInfoPanel:(NSString *)strTitle message:(NSString *)strMessage callback:(SEL)selector withObject:(id)obTarget
{
    [self createInfoPanel:strTitle message:strMessage callback:selector withObject:obTarget buttonTitle:@"OK"];
}

- (void)createInfoPanel:(NSString *)strTitle message:(NSString *)strMessage callback:(SEL)selector withObject:(id)obTarget buttonTitle:(NSString *)strButton
{
    float flScaleAdjust = [MRUtilities getDeviceScaleAdjustment];

    // Panel
    MRColor3B colorBlue = [MRUtilities getColor:@"panelBlue"];

    MRDefinitionSprite *sprPanel = [MRDefinitionSprite spriteWithFrameName:@"text_bubble_top.png"];
    [sprPanel setAnchorPoint:MRPoint(0.5f, 0.0f)];
    [sprPanel setPosition:MRPoint(MR_HALF_SCREEN_MINOR, MR_SCREEN_MAJOR * 0.6875f)]; // + 90
    [sprPanel setColor:colorBlue];
    [m_layNotify addChild:sprPanel];

    sprPanel = [MRDefinitionSprite spriteWithFrameName:@"text_bubble_middle.png"];
    [sprPanel setAnchorPoint:MRPoint(0.5f, 0.0f)];
    [sprPanel setPosition:MRPoint(MR_HALF_SCREEN_MINOR, MR_SCREEN_MAJOR * 0.374f)]; // + 91
    [sprPanel allowAliasing:YES];
    [sprPanel setColor:colorBlue];
    float flRatio = MR_SCREEN_MAJOR / (480.0f * flScaleAdjust);
    [sprPanel setScaleY:154 * flRatio];
    [m_layNotify addChild:sprPanel];

    sprPanel = [MRDefinitionSprite spriteWithFrameName:@"text_bubble_bottom.png"];
    [sprPanel setAnchorPoint:MRPoint(0.5f, 1.0f)];
    [sprPanel setPosition:MRPoint(MR_HALF_SCREEN_MINOR, MR_SCREEN_MAJOR * 0.375f)]; // - 60
    [sprPanel setColor:colorBlue];
    [m_layNotify addChild:sprPanel];

    MRTextLabel *textTitle = ([[MRTextLabel alloc] initWithWord:strTitle fontName:@"cooper" fontSize:(16 * flScaleAdjust)]);
    [textTitle setAnchorPoint:MRPoint(0.5f, 0.5f)];
    [textTitle setPosition:MRPoint(MR_HALF_SCREEN_MINOR, MR_SCREEN_MAJOR * 0.70833f)]; // + 100
    [m_layNotify addChild:textTitle];

    CGSize sizePage = CGSizeMake(MR_SCREEN_MINOR * 0.65f, 140 * flScaleAdjust);
	MRSystemText *labelText = [MRUtilities createTextRegion:strMessage size:sizePage fontSize:(14 * flScaleAdjust)];
    [labelText setAnchorPoint:MRPoint(0.5f, 0.5f)];
	[labelText setPosition:MRPoint(MR_HALF_SCREEN_MINOR, MR_SCREEN_MAJOR *0.541666f)]; // + 20
	[m_layNotify addChild:labelText];

	MRButton *buttonTabbar = ([[MRButton alloc] initWithFrameName:@"panel_button_short.png"]);
	[buttonTabbar setPosition:MRPoint(MR_HALF_SCREEN_MINOR, MR_SCREEN_MAJOR * 0.375f)]; // - 60
	[buttonTabbar addTouchTarget:selector forObject:obTarget];
    [buttonTabbar setTextColor:MRRGB(255, 255, 255)];
	[buttonTabbar setText:strButton];//    atPosition:ccp(0.0f, -5.0f * flScaleAdjust) withAlignment:UITextAlignmentCenter];
	[m_layNotify addChild:buttonTabbar];

    // Let's show the OpenFeint GameFeed while paused.
    //    [[GCMan sharedGCMan] setGameFeed:YES];
}

#pragma mark -
#pragma mark Transmissions

- (void)callBounce:(id)target
{
	id actionOn			= [MRScaleTo actionWithDuration:0.5f scale:1.0f];
	id actionOff		= [MRScaleTo actionWithDuration:0.5f scale:0.95f];
	id actionBlink		= [MRSequence actions:actionOn, actionOff, nil];
	id actionRepeat		= [MRRepeatForever actionWithAction:actionBlink];

	[target runAction:actionRepeat];
}

- (BOOL)transmissionShowWithText:(NSString*)strText withIcon:(NSString*)strIcon withSelector:(SEL)selector withColor:(NSString*)strColor
{
	// Clear any items that were already in our layer.
	[m_layTransmission removeAllChildrenWithCleanup:YES];

	// In cheapskate version, don't show these.
#ifdef FREE_VERSION
	return NO;
#endif

	MRButton *sprItem = nil;
	MRColor3B colItem = [MRUtilities getColor:strColor];
	sprItem = [self createAndPlaceButton:@"transmission_window.png"
								position:MRPoint(0,0)
								  inNode:m_layTransmission
								selector:selector];
	CGSize size = sprItem.contentSize;
	[sprItem setAnchorPoint:MRPoint(0.5f, 0.5f)];
	[sprItem setDefaultColor:colItem];
	[sprItem setShrinkOnTouch:NO];

	MRDefinitionSprite *sprIcon;
	sprIcon = [self createAndPlaceSprite:strIcon position:MRPoint(16, size.height / 2.0f) inNode:sprItem];
	[sprIcon setAnchorPoint:MRPoint(0.0f, 0.5f)];

	// Show our title.
	float flX = size.width / 2.0f; // + [sprIcon contentSize].width;
	float flY = (size.height - MR_DEFAULT_FONT_SIZE - 8.0f) / 2.0f;
	MRSystemText *labelTitle = [self createText:strText withStyle:ELT_OUTLINE position:MRPoint(flX, flY)
								   inNode:sprIcon withBundle:0];

	MRColor3B colTitle = [MRUtilities getColor:@"whitePure"];
	[labelTitle setColor:colTitle];

	// Can we slide in from the top?
	CGPoint pStart	= MRPoint(MR_SCREEN_MAJOR - size.width / 2.0f, MR_SCREEN_MINOR + size.height / 2.0f);
	CGPoint pEnd	= MRPoint(MR_SCREEN_MAJOR - size.width / 2.0f, MR_SCREEN_MINOR - size.height / 2.0f);
	[sprItem setPosition:pStart];
	id actionSlideDown	= [MRMoveTo actionWithDuration:1.0f position:pEnd];
	id actionBounce		= [MREaseBounceOut actionWithAction:actionSlideDown];
	id actionCallBounce	= [MRCallFuncN actionWithTarget:self selector:@selector(callBounce:)];

	[sprItem runAction:[MRSequence actions:actionBounce, actionCallBounce, nil]];
	return YES;
}

- (void)transmissionClear
{
	// Just make us vanish from view; we'll clean up later.
	float flDistance = 200.0f;
	id actionSlideUp = [MRMoveBy actionWithDuration:0.5f position:MRPoint(0.0f, flDistance)];

	NSArray *arrChildren = m_layTransmission.children;
	for (MRNode *nodeItem in arrChildren)
	{
		[nodeItem runAction:actionSlideUp];
	}
}

- (void)touchStatsForQuest:(id)idSender
{
	// Tom turning this off 12/29/11.
//	// Close any notification.
//	[self doCloseNotification:idSender];
//
//	StatsScene *newScene = [StatsScene createStatsScene];
//	id scene = [CCTransitionFade transitionWithDuration:0.5 scene:newScene withColor:ccc3(0, 0, 0)];
//	[newScene setHint:@"Quest"];
//
//	[[CCDirector sharedDirector] replaceScene:scene];
}

- (void)touchTransmissionQuest:(id)idSender
{
	// We have a new quest! Wanna see it?


	// Transmission, go away visualy, please!
	[self transmissionClear];
}

- (void)touchTransmissionQuestCompleted:(id)idSender
{
	// We completed a quest! Wanna see it?


	// Transmission, go away visualy, please!
	[self transmissionClear];
}

- (void)touchResearch:(id)idSender
{
	// Close any notification.
	[self doCloseNotification:idSender];

}

- (void)touchTransmissionTech:(id)idSender
{
    // Not generic -- Tom disabling 12/29/11.

//	// We have a new tech! Wanna see it?
//	NSString *strText = [NSString stringWithFormat:@"You have a new technology available!\n\nTap \"View\" to go see it."];
//	[self notificationAddWithTitle:@"NEW TECH"
//				   withButtonTitle:@"Not Now"
//				withButtonSelector:nil
//						  withText:strText
//						  withIcon:nil
//					  withSecondSelector:@selector(touchResearch:)
//				 withSecondSelectorTitle:@"View"
//						 withColor:nil];
//
//	// And clear the fact that we have new quests to notify about.
//	[UtilityManager setContentIntForKey:PREF_NEW_TECH_COUNT withInt:0];
//
//	// Transmission, go away visualy, please!
//	[self transmissionClear];
}

- (void)notificationsUpdate:(MRTime)seconds
{
}

- (void)doCloseNotification:(id)idSender
{
}

- (void)transmissionUpdateForActive
{
	// Clear any existing transmission.
	[self transmissionClear];

    // Not generic -- Tom disabling 12/29/11.
//	if ([UtilityManager getContentIntForKey:PREF_COMPLETED_QUEST_COUNT] > 0)
//	{
//		// Do we have a completed quest to notify about?
//		[self transmissionShowWithText:@"Quest Completed"
//							  withIcon:@"satellite.png"
//						  withSelector:@selector(touchTransmissionQuestCompleted:)
//							 withColor:@"bluePale1"];
//	}
//	else if ([UtilityManager getContentIntForKey:PREF_NEW_QUEST_COUNT] > 0)
//	{
//		// Do we have a new quest to notify about?
//		[self transmissionShowWithText:@"Quest Unlocked"
//							  withIcon:@"satellite.png"
//						  withSelector:@selector(touchTransmissionQuest:)
//							 withColor:@"bluePale1"];
//	}
//	else if ([UtilityManager getContentIntForKey:PREF_NEW_TECH_COUNT] > 0)
//	{
//		// Do we have a new tech to notify about?
//		[self transmissionShowWithText:@"Tech Unlocked"
//							  withIcon:@"satellite.png"
//						  withSelector:@selector(touchTransmissionTech:)
//							 withColor:@"bluePale1"];
//	}

}


#pragma mark -
#pragma mark Purchases

//- (void)preparePurchaseCrystals:(id)idSender
//{
//	NSLog(@"Player wants to purchase crystals.");
//
//	[self doCloseNotification:idSender];
//
//	[self performSelector:@selector(purchaseShow) withObject:self afterDelay:0.5f];
//}

- (MRDefinitionSprite *)createPanelWithScale:(float)flWidthScale withHeight:(float)flMiddleHeight
{
	MRColor3B color = MRRGB(255, 255, 255);
	return [self createPanel:color withScale:flWidthScale withHeight:flMiddleHeight];
}

- (MRDefinitionSprite *)createPanel:(MRColor3B)colorPanel withScale:(float)flWidthScale withHeight:(float)flMiddleHeight
{
    //    float flScaleFactor = [MRSceneHost getDeviceScaleAdjustment];


    float flIPadFactor = 1.0f;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        flIPadFactor = 2.0f;
    float flScaleX = MR_SCREEN_MINOR / (flIPadFactor * 320.0f);
//    float flScaleY = MR_SCREEN_MAJOR / (flIPadFactor * 480.0f);

    // Panel

    MRDefinitionSprite *sprPanel = ([[MRDefinitionSprite alloc] init]);
    [sprPanel setAnchorPoint:MRPoint(0.5f, 0.5f)];

    MRDefinitionSprite *sprTop = [MRDefinitionSprite spriteWithFrameName:@"panel_top.png"];
    [sprTop setAnchorPoint:MRPoint(0.5f, 1.0f)];
    [sprTop setColor:colorPanel];
    [sprTop setScale:flWidthScale * flScaleX];
    CGSize sizeTop = [sprTop boundingBox].size;

    MRDefinitionSprite *sprMiddle = [MRDefinitionSprite spriteWithFrameName:@"panel_middle.png"];
    float flBaseHeight = [sprMiddle contentSize].height;
    [sprMiddle setAnchorPoint:MRPoint(0.5f, 0.0f)];
    [sprMiddle allowAliasing:YES];
    [sprMiddle setColor:colorPanel];
	float flMiddleScaleY = flMiddleHeight - (flScaleX - 1) * sprTop.contentSize.height * 2.0f;
    [sprMiddle setScaleY:flMiddleScaleY / flBaseHeight];
    [sprMiddle setScaleX:flWidthScale * flScaleX];
    [sprPanel addChild:sprMiddle];
    CGSize sizeMiddle = [sprMiddle boundingBox].size;

    [sprPanel addChild:sprTop];

    float flYOffset = 0;
//    sizeMiddle.height -= 2.0f * sprMiddle.scaleY * flIPadFactor; // Fudge height for overlap
//    flYOffset = 1.0f * sprMiddle.scaleY * flIPadFactor;
    sizeMiddle.height -= 2.0f * flIPadFactor; // Fudge height for overlap
    flYOffset = 1.0f * flIPadFactor;


    MRDefinitionSprite *sprBottom = [MRDefinitionSprite spriteWithFrameName:@"panel_bottom.png"];
    [sprBottom setAnchorPoint:MRPoint(0.5f, 0.0f)];
    [sprBottom setColor:colorPanel];
    [sprBottom setScale:flWidthScale * flScaleX];
    [sprPanel addChild:sprBottom];

    CGSize sizeBottom = [sprBottom boundingBox].size;

    float flWidth = sizeTop.width; // + sizeMiddle.width + sizeBottom.width;
    float flHeight = sizeTop.height + sizeBottom.height + sizeMiddle.height;
    CGSize sizePanel = CGSizeMake(flWidth, flHeight);

    [sprPanel setContentSize:sizePanel];

    [sprTop setPosition:MRPoint(sizePanel.width * 0.5f, sizePanel.height + flYOffset / 2)];
    [sprBottom setPosition:MRPoint(sizePanel.width * 0.5f, 0)];
    [sprMiddle setPosition:MRPoint(sizePanel.width * 0.5f, sizeBottom.height - flYOffset)];

    return sprPanel;
}

- (MRButton *)createAndPlaceBubbleButton:(float)flScale color:(MRColor3B)color position:(CGPoint)Position inNode:(MRNode *)node selector:(SEL)selTouch
{
    MRButton *button = ([[MRButton alloc] init]);
    [button setPosition:Position];
    [node addChild:button z:MR_LAYER_FOREGROUND];

    CGSize sizeButton = CGSizeMake(0, 0);

    MRDefinitionSprite *sprPanelTop = [MRDefinitionSprite spriteWithFrameName:@"panel_top.png"];
    [sprPanelTop setAnchorPoint:MRPoint(0.5f, 0.0f)];
    [sprPanelTop setDefaultColor:color];
    [button addChild:sprPanelTop];

    MRDefinitionSprite *sprPanelBottom = [MRDefinitionSprite spriteWithFrameName:@"panel_bottom.png"];
    [sprPanelBottom setAnchorPoint:MRPoint(0.5f, 1.0f)];
    [sprPanelBottom setDefaultColor:color];
    [button addChild:sprPanelBottom];

    CGSize sizeTop = [sprPanelTop contentSize];
    CGSize sizeBottom = [sprPanelBottom contentSize];
    sizeButton.width = sizeTop.width;
    sizeButton.height = sizeTop.height + sizeBottom.height;
    [button setContentSize:sizeButton];

    [sprPanelTop setPosition:MRPoint(sizeButton.width / 2.0f, sizeButton.height / 2.0f)];
    [sprPanelBottom setPosition:MRPoint(sizeButton.width / 2.0f, sizeButton.height / 2.0f + 1.0f)];

    [button setDefaultScale:flScale];

    [button addTouchTarget:selTouch forObject:self];
    return button;
}

- (MRDefinitionSprite *)createPopup:(NSString *)strMessage
{
	MRDefinitionSprite *sprPanel = [self createPanelWithScale:1.0 withHeight:30];
	CGSize sizePanel = [sprPanel contentSize];

	float flFontSize = 18.0f;

    NSString *strFont = [[MRUtilities sharedUtilityManager] getDefaultFont];
	MRTextLabel *text = ([[MRTextLabel alloc] initWithWord:strMessage fontName:strFont fontSize:flFontSize]);
	[text setPosition:MRPoint(sizePanel.width / 2.0f, sizePanel.height / 2.0f)];
	[sprPanel addChild:text];

	[sprPanel setScale:0.1f];
	[[MRAudio sharedAudioManager] soundsPlay:@"dismiss popup"];

	id actionGrow = [MRScaleTo actionWithDuration:0.2f scale:1.2f];
	id actionShrink = [MRScaleTo actionWithDuration:0.1f scale:1.0f];

	id actionDelay  = [MRDelayTime actionWithDuration:1.5f];

	id actionGrow2  = [MRScaleTo actionWithDuration:0.2f scale:1.5f];
	id actionFadeOut= [MRFadeOut actionWithDuration:0.2f];
	id actionPop    = [MRSpawn actions:actionGrow2, actionFadeOut, nil];
	id actionSound  = [MRCallFunc actionWithTarget:self selector:@selector(playPopSound)];
	id actionDie	= [MRCallFunc actionWithTarget:sprPanel selector:@selector(suicide)];

	[sprPanel runAction:[MRSequence actions:actionGrow, actionShrink, actionDelay, actionPop, actionSound, actionDie, nil]];
	return sprPanel;
}

- (MRButton *)createHelpCircle:(NSString *)strText forEntry:(NSString *)strEntry pointingAt:(CGPoint)pointAt onLayer:(MRLayer *)layer
{
	NSString *strImage	= @"help_circle.png";
	float flTextWidth	= 0.9f;
	NSString *strColor	= @"bluePale0";


	MRButton *button = ([[MRButton alloc] initWithFrameName:strImage]);
	CGSize sizeButton = [button contentSize];
	CGPoint posCenter = MRPoint(MR_SCREEN_MINOR * 0.5f, MR_SCREEN_MAJOR * 0.5f);
	if (CGPointEqualToPoint(posCenter, pointAt))
		posCenter = MRPoint(MR_SCREEN_MINOR * 0.5f, MR_SCREEN_MAJOR * 0.25f);
	CGPoint vToward = normalize(subtract(pointAt, posCenter));
	CGPoint vUp = MRPoint(0.0f, 1.0f);
	float flAngle = angleBetweenVectors(vUp, vToward);
	float flRadius = sizeButton.height * 0.5f;
	CGPoint vOffset = scale(vToward, -flRadius);
	CGPoint posPlace = add(pointAt, vOffset);
	[button setPosition:posPlace];
	[button setRotation:flAngle];
	CGPoint position = MRPoint(posPlace.x / MR_SCREEN_MINOR, posPlace.y / MR_SCREEN_MAJOR);

	if (strColor != nil)
	{
		MRColor3B color = [MRUtilities getColor:strColor];
		[button setDefaultColor:color];
	}
	[layer addChild:button];

    NSString *strFont = [[MRUtilities sharedUtilityManager] getDefaultFont];
	MRTextLabel *textTitle = [[MRTextLabel alloc] initWithParagraph:strText fontName:strFont fontSize:12.0f maxWidth:sizeButton.width * flTextWidth];
	[textTitle setPosition:MRPoint(MR_SCREEN_MINOR * position.x, MR_SCREEN_MAJOR * position.y)];
	[layer addChild:textTitle];
	if (strEntry != nil)
		[button addTouchTarget:@selector(touchHelp:) forObject:self];
	else
		button.enabled = NO;
	button.tagString = strEntry;

	[textTitle animateBubbleIn];
	[button animateBubbleIn];

	return button;
}

- (void)playPopSound
{
	[[MRAudio sharedAudioManager] soundsPlay:@"pop selected"];
}

- (void)touchHelp:(id)idButton
{
	m_idContextHelp = [MRContextHelp sharedContextHelp];
    if (m_idContextHelp != nil)
    {
        if ([m_idContextHelp respondsToSelector:@selector(displayHelpForContext:)])
        {
            MRButton *button = (MRButton *)idButton;
            NSString *strContext = [button.tagString copy];
            if (strContext != nil)
            {
                [m_idContextHelp performSelector:@selector(displayHelpForContext:) withObject:strContext];
            }
        }
    }
}

- (void)localDeepAddLayersToDisableList:(NSMutableArray *)aModalDisabledLayers fromNode:(MRNode *)parentNode
{
	NSArray *aChildren = parentNode.children;
	for (MRNode *node in aChildren)
	{
		if ([node isKindOfClass:[MRLayer class]] == YES)
		{
			MRLayer *layer = (MRLayer *)node;
			if (layer.isTouchEnabled == YES)
			{
				layer.isTouchEnabled = NO;
				[aModalDisabledLayers addObject:layer];
			}
		}
		if ([node.children count] > 0)
		{
			[self localDeepAddLayersToDisableList:aModalDisabledLayers fromNode:node];
		}
	}
}

- (void)addChildModalLayer:(MRLayer *)layerModal
{
	NSMutableArray *aModalDisabledLayers = [[NSMutableArray alloc] initWithCapacity:5];
	[self localDeepAddLayersToDisableList:aModalDisabledLayers fromNode:self];

	ModalData *newModalData = [[ModalData alloc] init];
	newModalData.aDisabledLayers = [NSArray arrayWithArray:aModalDisabledLayers];

	newModalData.layerModal = layerModal;
	[m_aModalDataStack addObject:newModalData];

	[self addChild:layerModal z:MR_LAYER_MAX];
}

- (MRLayer*)getActiveChildModalLayer
{
	ModalData *lastModalData = [m_aModalDataStack lastObject];
    return lastModalData.layerModal;
}

- (void)removeChildModalLayer:(MRLayer *)layerModal
{
	ModalData *modalData = nil;
	for (modalData in m_aModalDataStack)
	{
		if (modalData.layerModal == layerModal)
			break;
	}
	if (modalData == nil)
		return;

    // Only re-enable layers if we are leaving modal mode.
    if (modalData == [m_aModalDataStack lastObject])
    {
        for (MRLayer *layer in modalData.aDisabledLayers)
        {
            layer.isTouchEnabled = YES;
        }
    }
    else
    {
        // Give our disabled Layers to whoever came after us.
        int nIndex = [m_aModalDataStack indexOfObject:modalData];

        ModalData *nextModalData = [m_aModalDataStack objectAtIndex:nIndex + 1];
        if (nextModalData != nil)
        {
            NSMutableArray *aBothArrays = [NSMutableArray arrayWithArray:nextModalData.aDisabledLayers];
            [aBothArrays addObjectsFromArray:modalData.aDisabledLayers];
            nextModalData.aDisabledLayers = aBothArrays;
        }

    }

	[m_aModalDataStack removeObject:modalData];
	[self removeChild:modalData.layerModal cleanup:YES];

	(void)0;
}

- (void)removeLastChildModalLayer
{
	ModalData *lastModalData = [m_aModalDataStack lastObject];
	if (lastModalData == nil)
		return;
	[self removeChildModalLayer:lastModalData.layerModal];
}

- (void)delayedRemoveChildModalLayerWithCleanup:(BOOL)fCleanup
{
	ModalData *lastModalData = [m_aModalDataStack lastObject];
	if (lastModalData == nil)
		return;

	[self performSelector:@selector(removeChildModalLayer:) withObject:lastModalData.layerModal afterDelay:0.0f];
}

- (void)delayedRemoveChildModalLayersCount:(int)nCount
{
    int nMaxStack = [m_aModalDataStack count];

    if (nMaxStack == 0)
        return;
    for (int i = 0; i < nCount; i++)
    {
        int nIndex = nMaxStack - 1 - i;
        if (nIndex > nMaxStack - 1)
            continue;
        ModalData *indexedModalData = [m_aModalDataStack objectAtIndex:nIndex];
        if (indexedModalData == nil)
            return;

        [self performSelector:@selector(removeChildModalLayer:) withObject:indexedModalData.layerModal afterDelay:0.0f];
    }
}

- (void)delayedRemoveAllChildModalLayers
{
    int nMaxStack = [m_aModalDataStack count];

    if (nMaxStack == 0)
        return;
    for (int i = 0; i < nMaxStack; i++)
    {
        int nIndex = nMaxStack - 1 - i;
        if (nIndex > nMaxStack - 1)
            continue;
        ModalData *indexedModalData = [m_aModalDataStack objectAtIndex:nIndex];
        if (indexedModalData == nil)
            return;

        [self performSelector:@selector(removeChildModalLayer:) withObject:indexedModalData.layerModal afterDelay:0.0f];
    }
}



//- (void)startModalForLayer:(CCLayer *)layerException
//{
//	if (m_aModalDisabledLayers == nil)
//		m_aModalDisabledLayers = [[NSMutableArray alloc] initWithCapacity:5];
//	NSArray *aChildren = self.children;
//	for (CCNode *node in aChildren)
//	{
//		if ([node isKindOfClass:[CCLayer class]] == NO)
//			continue;
//		CCLayer *layer = (CCLayer *)node;
//		if (layer == layerException)
//			continue;
//		if (layer.isTouchEnabled == NO)
//			continue;
//		layer.isTouchEnabled = NO;
//		[m_aModalDisabledLayers addObject:layer];
//	}
//}
//
//- (void)endModal
//{
//	if (m_aModalDisabledLayers == nil)
//		return;
//	for (CCLayer *layer in m_aModalDisabledLayers)
//	{
//		layer.isTouchEnabled = YES;
//	}
//	[m_aModalDisabledLayers removeAllObjects];
//}

- (void)cancelWait
{
	if ([self respondsToSelector:@selector(back:)] == YES)
		[self performSelector:@selector(back:) withObject:nil afterDelay:0];
}

- (id)displayPleaseWait
{
	return [self displayPleaseWait:@"Please Wait"];
}

- (id)displayPleaseWait:(NSString *)strText
{
	MRColorLayer *layWait = [MRColorLayer layerWithColor:MRRGBA(0, 0, 0, 128)];
//	[self addChild:layWait z:MR_LAYER_NOTIFY];


	// Call this on delay so we don't modify our touch list while in a touch callback.
	[self performSelector:@selector(addChildModalLayer:) withObject:layWait afterDelay:0.0f];

	MRDefinitionSprite *sprPanel = [self createPanelWithScale:1.1f withHeight:50];
	[sprPanel setPosition:MRPoint(MR_SCREEN_MINOR * 0.5f, MR_SCREEN_MAJOR * 0.5f)];
	[layWait addChild:sprPanel];

	CGSize sizePanel = [sprPanel contentSize];

    NSString *strFont = [[MRUtilities sharedUtilityManager] getDefaultFont];
	MRTextLabel *textTitle = [[MRTextLabel alloc] initWithWord:strText fontName:strFont fontSize:16.0f];
	CGSize sizeText = [textTitle contentSize];
	sizeText.width *= textTitle.scaleX;
	sizeText.height *= textTitle.scaleY;
	[textTitle setPosition:MRPoint(sizePanel.width * 0.5f, sizePanel.height - sizeText.height * 1.5f)];
	[sprPanel addChild:textTitle];

	MRButton *button = ([[MRButton alloc] initWithFrameName:@"panel_small_button.png"]);
	CGSize sizeButton = [button contentSize];

	float flFontSize = 14.0f;
	NSString *strLabel = @"Cancel";
	MRTextLabel *text = ([[MRTextLabel alloc] initWithWord:strLabel fontName:strFont fontSize:flFontSize]);
	[text setPosition:MRPoint(sizeButton.width / 2.0f, sizeButton.height / 2.0f)];
	[button addChild:text];
	[button setPosition:MRPoint(sizePanel.width * 0.5f, sizeButton.height * 1.25f)];
	[button addTouchTarget:@selector(cancelWait) forObject:self];
	[sprPanel addChild:button];

	[sprPanel animateBubbleIn];

	return sprPanel;
}

- (void)endPleaseWait
{
	[self removeLastChildModalLayer];
}

- (void)lightningLink:(MRLayer *)layer onLayer:(MRLayer *)layerBackground
{
	NSArray *aChildren = layer.children;
//	NSMutableArray *aList = [NSMutableArray arrayWithCapacity:[aChildren count]];
//	for (CCNode *node in aChildren)
//	{
//		if ([node isKindOfClass:[Tile class]] == YES)
//			[aList addObject:node];
//	}

	int nCount = [aChildren count];
	int nIndex1 = random() % nCount;
	int nIndex2 = random() % nCount;
	if (nIndex2 == nIndex1)
		nIndex2 = (nIndex2 + 1) % nCount;
	MRNode *node1 = [aChildren objectAtIndex:nIndex1];
	MRNode *node2 = [aChildren objectAtIndex:nIndex2];
    int nTries = 0;
	while (node1.tag == SPRITE_TAG_LIGHTNING && nTries < 10)
    {
        nIndex1 = random() % nCount;
        node1 = [aChildren objectAtIndex:nIndex1];
        ++nTries;
    }
    if (nTries >= 10)
        return;
    nTries = 0;
    while ((node2.tag == SPRITE_TAG_LIGHTNING || node2 == node1) && nTries < 10)
    {
        nIndex2 = random() % nCount;
        node2 = [aChildren objectAtIndex:nIndex2];
        ++nTries;
    }
    if (nTries >= 10)
        return;
	CGPoint startPosition = node1.position;
	CGPoint endPosition = node2.position;
    // Hack test.
    if (startPosition.x < 5.0f || endPosition.x < 5.0f)
    {
        NSLog(@"Lefty!");
    }
    [[MRUtilities sharedUtilityManager] createBoltFromPointA:startPosition toPointB:endPosition intoLayer:layerBackground];
	[[MRAudio sharedAudioManager] soundsPlay:@"electric short"];

}

- (void)cleanup
{
	[super cleanup];
	if (m_aModalDataStack != nil)
	{
//		while ([m_aModalDataStack lastObject] != nil)
//		{
//			[[m_aModalDataStack lastObject] release];
//		}
		(void)0;
	}
}

@end

#endif
