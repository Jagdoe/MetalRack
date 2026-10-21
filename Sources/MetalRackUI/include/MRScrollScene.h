//
//  ScrollScene.h
//  Befuddled
//
//  Created by Michael Scandizzo on 7/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRPlacementScene.h"

@class MRInputLayer;
@class MRDefinitionSprite;
@class MRUtilities;

// PLIST Entries.
#define ENTRY_BACKGROUND		@"background"			// Name of background image.
#define ENTRY_TEXT_COLOR		@"text color"			// RGBA color for text.
#define ENTRY_MISSIONS			@"missions"				// Array of mission entries.
#define ENTRY_LINE_TO_MISSION	@"line to mission"		// Draw a line from previous to this mission?
#define ENTRY_LINE_WIGGLE		@"line wiggle"			// Bool -- should the mission line wiggle and curve?
#define ENTRY_BOUNDS			@"bounds"				// Set of bounds beyond screen borders
#define ENTRY_BOUNDS_LEFT		@"left"					// How far left of screen does sceen extend?
#define ENTRY_BOUNDS_RIGHT		@"right"				// How far right of screen does sceen extend?
#define ENTRY_BOUNDS_TOP		@"top"					// How far above screen does sceen extend?
#define ENTRY_BOUNDS_BOTTOM		@"bottom"				// How far below screen does sceen extend?
#define ENTRY_MUSIC				@"music"				// Song to associate with this chapter
#define ENTRY_NO_STARS			@"no stars"				// Turn off stars in background of chapter screen

@interface MRScrollScene : MRPlacementScene
{
	MRLayer		*layBack;
	MRLayer		*laySky;
	MRLayer		*layNodePointers;
	MRInputLayer	*layMain;
	MRLayer		*layText;
	int			m_nSetCount;
	int			m_nMissionSelected;
	// Moving the scene display
	float		m_flXMin;
	float		m_flXMax;
	float		m_flYMin;
	float		m_flYMax;
	CGPoint		m_pointTouchStart;
	CGPoint		m_pointLayerStart;

	NSMutableArray	*m_aMapNodes;

	// Quick refs.
	MRUtilities *m_utilsMan;

}

// Override this
- (void)back:(id)idSender;

- (CGPoint)getEntryPosition:(NSDictionary *)dictData;

- (BOOL)constructMap:(NSDictionary *)dictSet;

- (void)addMapNode:(MRDefinitionSprite *)sprNode;
- (void)updateMapNodePointers;

// Screen-scrolling stuff.
- (void)singleTouchBegan:(MRPointerEvent*)touch;
- (void)singleTouchMoved:(MRPointerEvent*)touch;
- (void)singleTouchEnded:(MRPointerEvent*)touch;
-(void) pointersMoved:(NSSet *)touches;

@end
