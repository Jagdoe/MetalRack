//
//  C2DButton.h
//  Befuddled
//
//  Created by Michael Scandizzo on 5/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRDefinitionSprite.h"

#define TIME_BETWEEN_CLICKS	(0.25f)

@interface MRButton : MRDefinitionSprite <MRPointerReceiver>
{
	BOOL			m_fSelected;
	BOOL			m_fHighlightsOnTouch;
	SEL				m_selTouchBegin;
	__weak id				m_idTouchBegin;
	MRSpriteFrame	*m_frameNormal;
	MRSpriteFrame	*m_frameHighlight;

    // Test UIAccessibility stuff...
//    UIView          *m_viewAccessible;

	// Happy Properties
	BOOL			enabled;
	BOOL			m_fOnTouchBegin;
	BOOL			m_fShrinkOnTouch;
    BOOL            m_fTargeted;

	id				m_idTouchEvent;

	// Sounds
	NSString        *m_strTouchSound;

    // Drag properties
    BOOL            m_fDeselectOnDrag;
    CGPoint         m_locTouchBegin;
}

@property (readwrite, copy)							NSString	*m_strTouchSound;
@property (nonatomic)								BOOL		enabled;
@property (nonatomic, readonly, getter=isSelected)	BOOL		m_fSelected;

+ (NSTimeInterval)timeSinceButtonFunction;
+ (void)setRunFunctionToNow;

+ (id)buttonWithC2DSprite:(MRDefinitionSprite *)sprImage;

- (id)initWithFrameName:(NSString *)strFrame;
- (id)initWithC2DSprite:(MRDefinitionSprite *)sprImage;
- (void)setTargeted:(BOOL)fTargeted;
- (void)setHighlightFrame:(BOOL)fOn;
- (void)setHighlight:(BOOL)fOn;
- (void)setHighlightsOnTouch:(BOOL)fHighlights;
- (void)addTouchTarget:(SEL)selTouch forObject:(id)idObject;
- (BOOL)hasTouchTarget:(SEL)selTouch;
- (float)getWorldRotation;
- (void)setClickOnTouchBegin:(BOOL)fTrue;
- (void)setShrinkOnTouch:(BOOL)fTrue;
- (void)setDeselectOnDrag:(BOOL)fTrue;

- (void)setDefaultScale:(float)s;

- (void)animateShrink;
- (void)animateGrow;
- (void)unselect;

@end
