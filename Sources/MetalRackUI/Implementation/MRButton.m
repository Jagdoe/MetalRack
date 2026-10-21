#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DButton.m
//  Befuddled
//
//  Created by Michael Scandizzo on 5/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRButton.h"
#import <QuartzCore/QuartzCore.h>
#import "2DMath.h"
#import "MRAudio.h"

@implementation MRButton

static NSDate   *sgdateRanButtonFunction = nil;

@synthesize enabled;
@synthesize m_strTouchSound;
@synthesize m_fSelected;

-(BOOL)isAccessibilityElement
{
    return YES;
}

+ (NSTimeInterval)timeSinceButtonFunction
{
	if (sgdateRanButtonFunction == nil)
	{
		sgdateRanButtonFunction = ([NSDate dateWithTimeIntervalSinceNow:0.0f]);
		return 999.0f;
	}

//    NSLog(@"Last click button was %@", sgdateRanButtonFunction);

	NSTimeInterval timeSinceClicked = fabs([sgdateRanButtonFunction timeIntervalSinceNow]);
	return timeSinceClicked;
}

+ (void)setRunFunctionToNow
{
	(void)0;
	sgdateRanButtonFunction = ([NSDate dateWithTimeIntervalSinceNow:0.0f]);
}

+ (id)buttonWithC2DSprite:(MRDefinitionSprite *)sprImage
{
	id ob = ([[self alloc] initWithC2DSprite:sprImage]);
	return ob;
}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
	m_fIconOnly = YES;
	[super initFromDefinition:dictDef];
}

- (id)init
{
	self = [super init];
//	if (self.inScene) [self.environment.input addReceiver:(id)self priority:0 swallows:NO];
	if (self.inScene) [self.environment.input addReceiver:(id)self priority:-1 swallows:YES];

	m_fTargeted = YES;
	m_fSelected = NO;
	m_selTouchBegin = nil;
	m_idTouchBegin = nil;
	m_label = nil;
	m_fHighlightsOnTouch = YES;
	m_fOnTouchBegin = NO;
	m_fShrinkOnTouch = YES;
	m_colorText = MRRGB(0.0f, 0.0f, 0.0f);
	m_strTouchSound = @"default button";
    m_locTouchBegin = MRPoint(0,0);

	// Outside properties.
	enabled = YES;

    // Accessibility stuff...
//    m_viewAccessible = [[[UIView alloc] init] autorelease];
//    [m_viewAccessible setIsAccessibilityElement:YES];

	// Done.
	return self;
}

- (id)initWithC2DSprite:(MRDefinitionSprite *)sprImage
{
	self = [self init];
	CGSize sizeImage = [sprImage contentSize];
    sizeImage = CGSizeMake(sizeImage.width * sprImage.scale, sizeImage.height * sprImage.scale);
	[self setContentSize:sizeImage];
	[self addChild:sprImage];
	[sprImage setPosition:MRPoint(sizeImage.width / 2.0f, sizeImage.height / 2.0f)];

    // Accessibility stuff...
//    CGRect rectAcc = CGRectMake(0.0f, 0.0f, sizeImage.width, sizeImage.height);
//    [m_viewAccessible setFrame:rectAcc];

	return self;
}


- (id)initWithFrameName:(NSString *)strFrame
{
	int nEnd = [strFrame length] - 4;
	NSString *strTrimmed = [strFrame substringToIndex:nEnd];
	NSString *strHighlightFrame = [NSString stringWithFormat:@"%@_h.png", strTrimmed];
	m_frameNormal		= [[MRSceneRuntime sharedRuntime].resources frameNamed:strFrame];
	m_frameHighlight	= [[MRSceneRuntime sharedRuntime].resources frameNamed:strHighlightFrame];
	if (m_frameHighlight == nil)
		m_frameHighlight = m_frameNormal;

	self = [super initWithFrame:m_frameNormal];
	if (self == nil)
		return nil;

    // Accessibility stuff...
//    CGSize sizeImage = m_frameNormal.originalSizeInPixels;
//    CGRect rectAcc = CGRectMake(0.0f, 0.0f, sizeImage.width, sizeImage.height);
//    [m_viewAccessible setFrame:rectAcc];

	return self;
}

- (id)initWithTexture:(MRTexture *)texture
{
	self = [super initWithTexture:texture];
	if (self == nil)
		return nil;

	// Done.
	return self;
}

- (void)didEnterScene { [super didEnterScene]; [self registerInput]; }
- (void)registerInput {
    [self.environment.input removeReceiver:self];
    if (enabled && self.inScene) [self.environment.input addReceiver:self priority:m_fTargeted ? -1 : 0 swallows:m_fTargeted];
}
- (void)pointerCancelled:(MRPointerEvent *)event { [self unselect]; m_idTouchEvent=nil; }
- (void)setEnabled:(BOOL)newEnabled
{
    if (newEnabled == enabled)
        return;
    enabled = newEnabled;
    if (newEnabled == NO)
    {
        [self.environment.input removeReceiver:(id)self];
    }
    else
    {
        if (m_fTargeted == YES)
        {
            if (self.inScene) [self.environment.input addReceiver:(id)self priority:-1 swallows:YES];
        }
        else
        {
            if (self.inScene) [self.environment.input addReceiver:(id)self priority:0 swallows:NO];
        }
    }
}

- (void)setTargeted:(BOOL)fTargeted
{
    if (fTargeted == m_fTargeted)
        return;

    [self.environment.input removeReceiver:(id)self];

    if (fTargeted == YES)
    {
        if (self.inScene) [self.environment.input addReceiver:(id)self priority:-1 swallows:YES];
    }
    else
    {
        if (self.inScene) [self.environment.input addReceiver:(id)self priority:0 swallows:NO];
    }
    m_fTargeted = fTargeted;
}

- (void)setHighlightFrame:(BOOL)fOn
{
	if (fOn)
	{
		[self setFrame:m_frameHighlight];
	}
	else
	{
		[self setFrame:m_frameNormal];
		[self setColor:m_colorDefault];
	}

}

- (void)setHighlightsOnTouch:(BOOL)fHighlights
{
	m_fHighlightsOnTouch = fHighlights;
}

- (float)getWorldRotation
{
	float flRotation = self.rotation;
	for (MRNode *p = self.parent; p != nil; p = p.parent)
		flRotation += p.rotation;
	return flRotation;
}

- (void)addTouchTarget:(SEL)selTouch forObject:(id)idObject
{
	m_idTouchBegin = idObject;
	m_selTouchBegin = selTouch;
}

- (BOOL)hasTouchTarget:(SEL)selTouch
{
    if (m_selTouchBegin == selTouch)
        return YES;
    return NO;
}

- (void)setClickOnTouchBegin:(BOOL)fTrue
{
	m_fOnTouchBegin = fTrue;
}

- (void)setDefaultScale:(float)s
{
    [super setDefaultScale:s];
    [self setScale:s];
}

- (void)setScale:(CGFloat)s
{
	float flOldScale = self.scale;
	[super setScale:s];
	[self setHitTestOverrideSize:CGSizeMake(m_sizeHitTestOverride.width * s/flOldScale, m_sizeHitTestOverride.height * s/flOldScale)];
}

- (void)setScaleX:(CGFloat)sx
{
	float flOldScaleX = self.scaleX;
	[super setScaleX:sx];
	[self setHitTestOverrideSize:CGSizeMake(m_sizeHitTestOverride.width * sx/flOldScaleX, m_sizeHitTestOverride.height)];
}

- (void)setScaleY:(CGFloat)sy
{
	float flOldScaleY = self.scaleY;
	[super setScaleY:sy];
	[self setHitTestOverrideSize:CGSizeMake(m_sizeHitTestOverride.width, m_sizeHitTestOverride.height * sy/flOldScaleY)];
}

- (void)setHighlight:(BOOL)fOn
{
	if (m_fHighlightsOnTouch == NO)
		return;

	if (fOn == NO)
	{
        [self removeColorTintForTag:@"button highlight"];
//		[self setColor:m_colorDefault];
//		for (C2DSprite *sprChild in self.children)
//		{
//			if ([sprChild isKindOfClass:[C2DSprite class]] == YES && sprChild.m_fIgnoreParentColor == NO)
//				[sprChild setColor:ccc3(255.0f, 255.0f, 255.0f)];
//		}
	}
	else
	{
//		[self setColor:ccc3(m_colorDefault.r / 2, m_colorDefault.g / 2, m_colorDefault.b / 2)];
        [self setColorTint:MRRGB(128, 128, 128) forTag:@"button highlight"];
//		for (C2DSprite *sprChild in self.children)
//		{
//			if ([sprChild isKindOfClass:[C2DSprite class]] == YES && sprChild.m_fIgnoreParentColor == NO)
//				[sprChild setColor:ccc3(128.0f, 128.0f, 128.0f)];
//		}
	}

}

- (void)setDeselectOnDrag:(BOOL)fTrue
{
    m_fDeselectOnDrag = fTrue;
}

// Standard touch delegate
#pragma mark -
#pragma mark Standard touch delegate

- (void)pointersBegan:(NSSet *)touches
{
    MRPointerEvent *touch = [touches anyObject];
    [self pointerBegan:touch];
}

- (void)pointersMoved:(NSSet *)touches
{
    MRPointerEvent *touch = [touches anyObject];
    [self pointerMoved:touch];
}

- (void)pointersEnded:(NSSet *)touches
{
    MRPointerEvent *touch = [touches anyObject];
    [self pointerEnded:touch];
}

// Targeted touch delegate
#pragma mark -
#pragma mark Targeted touch delegate

- (BOOL)pointerBegan:(MRPointerEvent *)touch
{
	if (enabled == NO)
		return NO;

    // If our parent is running an action (like zooming up, or scaling, etc), don't count this.
    if ([self.parent numberOfRunningActions] > 0)
        return NO;


	BOOL fHitTest = [self hitTest:touch];
	if (fHitTest)
	{
        m_locTouchBegin = touch.position;
		m_fSelected = YES;
		[self setHighlight:YES];
		if (m_fOnTouchBegin == YES)
		{
			NSTimeInterval timeSinceClicked = [MRButton timeSinceButtonFunction];
			if (m_idTouchBegin != nil && m_selTouchBegin != nil)
			{
				if (timeSinceClicked > TIME_BETWEEN_CLICKS)
				{
                    if ([m_idTouchBegin respondsToSelector:m_selTouchBegin] == YES)
                    {
                        [m_idTouchBegin performSelector:m_selTouchBegin withObject:self];
                        [MRButton setRunFunctionToNow];
                    }
				}
			}
		}
		[[MRAudio sharedAudioManager] soundsPlay:m_strTouchSound];
        if (m_fShrinkOnTouch == YES)
        {
            [self animateShrink];
        }
		m_idTouchEvent = touch;
		return YES;
	}
	return NO;
}

- (void)pointerMoved:(MRPointerEvent *)touch
{
    if (enabled == NO || m_fDeselectOnDrag == NO)
    {
        return;
    }

    // If our parent is running an action (like zooming up, or scaling, etc), don't count this.
    if ([self.parent numberOfRunningActions] > 0)
        return;

    if (m_fSelected == YES)
    {
        CGPoint locTouchNow = touch.position;

        BOOL fHitTest = [self hitTest:touch];

        CGRect rectView = [MRSceneRuntime sharedRuntime].view.frame;
        CGSize sizeView = rectView.size;

        float flDistance = length(subtract(m_locTouchBegin, locTouchNow));
//        if (m_fDeselectOnDrag == YES)
//        {
//            NSLog(@"Drag me: distance is %.0f, hitTest is %d.", flDistance, fHitTest);
//        }
        if (flDistance > sizeView.width * 0.05f || fHitTest == NO)
        {
            if (m_fShrinkOnTouch == YES)
            {
                [self animateGrow];
            }
            m_fSelected = NO;
            [self setHighlight:NO];
        }
    }
}

-(void) pointerEnded:(MRPointerEvent *)touch
{
	if (enabled == NO)
		return; //NO

    // If our parent is running an action (like zooming up, or scaling, etc), don't count this.
    int nActions = [self.parent numberOfRunningActions];
    if (nActions > 0)
        return;

//	BOOL fHitTest = [self hitTest:touch];

	if (m_fSelected == YES && touch.identifier == [(MRPointerEvent *)m_idTouchEvent identifier])
	{
		if (m_fDeselectOnDrag == YES)
		{
			CGPoint locTouchNow = touch.position;

			BOOL fHitTest = [self hitTest:touch];

			CGRect rectView = [MRSceneRuntime sharedRuntime].view.frame;
			CGSize sizeView = rectView.size;

			float flDistance = length(subtract(m_locTouchBegin, locTouchNow));
			if (flDistance > sizeView.width * 0.1f || fHitTest == NO)
			{
				if (m_fShrinkOnTouch == YES)
				{
					[self animateGrow];
				}
				m_fSelected = NO;
				[self setHighlight:NO];
				return;
			}
		}

		// Coloring.
		[self setHighlight:NO];

		if (m_fOnTouchBegin == NO)
		{
			NSTimeInterval timeSinceClicked = [MRButton timeSinceButtonFunction];
			if (m_idTouchBegin != nil && m_selTouchBegin != nil)
			{
				if (timeSinceClicked > TIME_BETWEEN_CLICKS)
				{
                    if ([m_idTouchBegin respondsToSelector:m_selTouchBegin] == YES)
                    {
                        [m_idTouchBegin performSelector:m_selTouchBegin withObject:self afterDelay:0.0f];
//                        [m_idTouchBegin performSelector:m_selTouchBegin withObject:self];
                        [MRButton setRunFunctionToNow];
                    }
				}
				else
				{
					NSLog(@"Button -- skipping selector; time too short (%.1f).", timeSinceClicked);
				}
			}
		}
		if (m_fSelected == YES)
        {
            if (m_fShrinkOnTouch == YES)
            {
                [self animateGrow];
            }
		}
		// We are no longer selected.
		m_fSelected = NO;

	}

}

// Making this fall through to C2DSprite version unless that breaks things.

//-(void) setOpacity:(GLubyte) anOpacity
//{
//	// Set our own opacity...
//	[super setOpacity:anOpacity];
//
//	// And all of our sprite children.
//	for (CCSprite *sprite in [self children])
//	{
//		if ([sprite respondsToSelector:@selector(setOpacity:)] == YES)
//			[sprite setOpacity:anOpacity];
//	}
//}

- (void)setShrinkOnTouch:(BOOL)fTrue
{
	m_fShrinkOnTouch = fTrue;
}

- (void)animateShrink
{
    float flSpeed = 0.15f;

    id actionScaleDown = [MRScaleTo actionWithDuration:flSpeed scaleX:0.75f * m_flScaleDefault scaleY:0.75f * m_flScaleDefault];
    // Add the actions.
    [self runAction:actionScaleDown];
}

- (void)animateGrow
{
    float flSpeed = 0.15f;

    id actionScaleUp   = [MRScaleTo actionWithDuration:flSpeed scaleX:1.0f * m_flScaleDefault scaleY:1.0f * m_flScaleDefault];
    // Add the actions.
    [self runAction:actionScaleUp];
}

- (void)unselect
{
	if (m_fSelected == YES)
		[self animateGrow];

	m_fSelected = NO;
}

- (void)cleanup
{
//    NSLog(@"  => Button %x cleaning up.", (int)self);
	(void)0;
	tagString = nil;

	[self.environment.input removeReceiver:(id)self];
}

- (void)dealloc
{
//    NSLog(@"  => Button %x DEALLOCing.", (int)self);
	(void)0;
}

#ifdef DISPLAY_COLLISION
- (void)draw
{
	[super draw];

	if (gsDebugOptions.m_fDisplayCollision == YES)
	{
		CGPoint pAnchor = self.anchorPointInPixels;
		pAnchor.x = pAnchor.x * self.scaleX;
		pAnchor.y = pAnchor.y * self.scaleY;
		CGPoint points[4];
		points[0] = subtract(MRPoint(0,0), pAnchor);
		points[1] = subtract(MRPoint(0, m_sizeHitTestOverride.height), pAnchor);
		points[2] = subtract(MRPoint(m_sizeHitTestOverride.width, m_sizeHitTestOverride.height), pAnchor);
		points[3] = subtract(MRPoint(m_sizeHitTestOverride.width, 0), pAnchor);
		ccDrawPoly(points, 4, 4 );
	}
}
#endif

@end

#endif
