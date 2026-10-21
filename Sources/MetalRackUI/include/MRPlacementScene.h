//
//  PlacementScene.h
//  Zombie
//
//  Created by Tom the Mediocre on 8/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRSceneConfiguration.h"
#import "MRDefinitionSprite.h"
#import "MRButton.h"

typedef enum
{
	ELT_NORMAL = 0,		// Just the text, ma'am
	ELT_SHADOW,			// Drop shadow down-right
	ELT_OUTLINE,		// Black outline (kinda)

	// Keep this last.
	NUM_ELT_TYPES
} ELabelType;

typedef struct
{
	NSMutableArray *arrSummary;
	NSMutableArray *arrSpecialPanels;
	NSMutableArray *arrAllVisuals;

	MRColor3B		colorText;

	CGRect			rectText;
} TPlacementBundle;

typedef struct
{
	NSString	*strSprite;
	CGPoint		pointPosition;
    //	ccColor3B	*color;
	NSString	*strColor;
	NSString	*strSelector;		// For buttons only.
	NSString	*strCategory;		// For buttons only.
	NSString	*strDisplay;		// For buttons only.

} TSpriteData;

typedef struct
{
	unichar uLetter;
	float PosX;
	float PosY;
    BOOL fActive;
} TTITLETILES;

#pragma mark -
#pragma mark ModalData - helper class

// This object stores an instance of a modal state.
// An array of these is stored in PlacementScene to
// allow recursive modal states.
@interface ModalData : NSObject

@property (strong, nonatomic) NSArray	*aDisabledLayers;
@property (strong, nonatomic) id		layerModal;

@end

#pragma mark -
#pragma mark MRPlacementScene

#define MAX_BUNDLES			(8)
#define BUNDLE_NOTIFICATION	(MAX_BUNDLES - 1)
#define BUNDLE_PURCHASE		(MAX_BUNDLES - 2)
#define BUNDLE_OVERLAY		(MAX_BUNDLES - 3)

#define TAG_MODAL_WAIT_LAYER	0x234523

@interface MRPlacementScene : MRScene
{
    // Objects we don't know everything about at compile time:
    Class               m_classGameScene;   // Whatever scene is considered our "active" game.
    id                  m_idContextHelp;
	TPlacementBundle	m_tBundles[MAX_BUNDLES];
	MRLayer				*m_layNotify;
	BOOL				m_fShouldUnpause;

	MRLayer				*m_layTransmission;

	MRLayer				*m_layPurchase;

	NSString			*m_strBackgroundImage;
	NSString			*m_strStartupHint;

	float				m_flTimeSinceDismissed;

	NSMutableArray		*m_aModalDataStack;
}

@property (readonly) MRLayer *layNotify;

- (void)setBackground:(NSString*)strBackground intoNode:(MRNode*)node;
- (id)createAndPlaceSprite:(NSString *)strName position:(CGPoint)Position inNode:(MRNode*)node;
- (id)createAndPlaceButton:(NSString *)strName position:(CGPoint)Position inNode:(MRNode*)node selector:(SEL)selTouch;
- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle position:(CGPoint)Position inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle position:(CGPoint)Position withFont:(NSString*)strFont withFontSize:(float)flFontSize inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle withDimensions:(CGSize)dimensions withPosition:(CGPoint)Position inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createText:(NSString *)strText withStyle:(ELabelType)eStyle withDimensions:(CGSize)dimensions position:(CGPoint)Position withFont:(NSString*)strFont withFontSize:(float)flFontSize inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createRegionText:(NSString *)strText atVertical:(float)flYPos withFont:(NSString*)strFont withFontSize:(int)nFontSize inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createRegionText:(NSString *)strText atLine:(float)flLine withFont:(NSString*)strFont withFontSize:(int)nFontSize inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createRegionText:(NSString *)strText atLine:(float)flLine inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createRegionText:(NSString *)strText belowText:(MRSystemText *)labelAbove withFont:(NSString*)strFont withFontSize:(int)nFontSize inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRSystemText *)createRegionText:(NSString *)strText belowText:(MRSystemText *)labelAbove inNode:(MRNode*)node withBundle:(int)nBundle;
- (void)setTextRegion:(CGRect)rectText withBundle:(int)nBundle;
- (MRSystemText *)createItemCountEntry:(NSString *)strItem withCount:(int)nCount ofTotal:(int)nTotal inSlot:(int)nSlot inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRDefinitionSprite*)createNamedImage:(NSString*)strImage withLabel:(NSString*)strLabel withTag:(NSString*)strTag inSlot:(int)nSlot inNode:(MRNode*)node withBundle:(int)nBundle;
- (MRDefinitionSprite*)createNamedImage:(NSString*)strImage withLabel:(NSString*)strLabel withColor:(NSString*)strColor withTag:(NSString*)strTag inSlot:(int)nSlot inNode:(MRNode*)node withBundle:(int)nBundle;

- (void)buildSummaryWithItems:(TSpriteData*)spriteList  withSpriteCount:(int)nSpriteCount
			 withSpecialItems:(TSpriteData*)specialList withSpecialCount:(int)nSpecialCount
			 withBackPosition:(CGPoint)pointBack withBackScale:(CGPoint)scale
					  inNode:(MRNode*)node
				   withBundle:(int)nBundle;

- (MRSystemText *)localLabelSummaryItem:(NSString*)strItem withItem:(int)nItem withBundle:(int)nBundle;

- (void)clearSummary:(int)nBundle;
- (void)clearAllPlacement:(int)nBundle;

- (void)setHint:(NSString*)strHint;

- (float)addTextLine:(NSString *)strFirst endingWith:(NSString *)strLast posY:(float)flY inLayer:(MRLayer*)layer;
- (float)addTextLine:(NSString *)strFirst endingWith:(NSString *)strLast posY:(float)flY inLayer:(MRLayer*)layer withColor:(MRColor3B)colText;
- (float)addTextLine:(NSString *)strFirst endingWith:(NSString *)strLast posY:(float)flY inLayer:(MRLayer*)layer withColor:(MRColor3B)colText withWidth:(float)flWidth;

- (MRDefinitionSprite*)createBubbleNumber:(int)nValue;

#pragma mark -
#pragma mark Notifications
- (void)doBubbleMessage:(NSString*)strMessage withColor:(NSString *)strColor;
- (void)doCloseNotification:(id)idSender;
- (BOOL)notificationAddWithTitle:(NSString*)strTitle withButtonTitle:(NSString*)strButtonTitle withButtonSelector:(SEL)selOkay withText:(NSString*)strText withIcon:(NSString*)strIcon withSecondSelector:(SEL)selector withSecondSelectorTitle:(NSString*)strSelectorTitle withColor:(NSString*)strColor;
- (BOOL)notificationsAreActive;


#pragma mark -
#pragma mark Purchases
- (void)createInfoPanel:(NSString *)strTitle message:(NSString *)strMessage callback:(SEL)selector withObject:(id)obTarget;
- (void)createInfoPanel:(NSString *)strTitle message:(NSString *)strMessage callback:(SEL)selector withObject:(id)obTarget buttonTitle:(NSString *)strButton;
- (MRDefinitionSprite *)createPanelWithScale:(float)flWidthScale withHeight:(float)flMiddleHeight;
- (MRDefinitionSprite *)createPanel:(MRColor3B)colorPanel withScale:(float)flWidthScale withHeight:(float)flMiddleHeight;
- (MRButton *)createAndPlaceBubbleButton:(float)flScale color:(MRColor3B)color position:(CGPoint)Position inNode:(MRNode *)node selector:(SEL)selTouch;
- (MRDefinitionSprite *)createPopup:(NSString *)strMessage;

// Modal functions
- (void)addChildModalLayer:(MRLayer *)layerModal;
- (MRLayer*)getActiveChildModalLayer;
- (void)removeChildModalLayer:(MRLayer *)layerModal;
- (void)removeLastChildModalLayer;
- (void)delayedRemoveChildModalLayerWithCleanup:(BOOL)fCleanup;
- (void)delayedRemoveChildModalLayersCount:(int)nCount;
- (void)delayedRemoveAllChildModalLayers;

- (id)displayPleaseWait;
- (id)displayPleaseWait:(NSString *)strText;
- (void)endPleaseWait;
- (void)lightningLink:(MRLayer *)layer onLayer:(MRLayer *)layerBackground;

@end
