#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DProgressBar.m
//  Befuddled
//
//  Created by Michael Scandizzo on 9/21/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRProgressBar.h"
#import "MRUtilities.h"

@implementation MRProgressBar

#define XPOS_ALIGNMENT_ERROR	(0.5f)
#define YPOS_ALIGNMENT_ERROR	0//(-0.0075f)
#define SCALEX_ERROR			(0.02f)
#define SCALEY_ERROR			0//(0.00175f)

+ (id)createFromDefinition:(NSDictionary *)dictDef
{
	MRProgressBar *barNew = ([[self alloc] init]);
	[barNew initFromDefinition:dictDef];
	return barNew;
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		m_sprLeftOn	= nil;
		m_sprLeftOff = nil;
		m_sprMiddleOn = nil;
		m_sprMiddleOff = nil;
		m_sprRightOn = nil;
		m_sprRightOff = nil;
		m_flPercent	= 0.0f;
	}
	return (self);
}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
	[super initFromDefinition:dictDef];

	float flScreenAdjust = [MRUtilities getDeviceScaleAdjustment];
	float flWidth = [[dictDef objectForKey:@"width"] floatValue];
	flWidth = flWidth * flScreenAdjust / 2.0f;
	m_flFullWidth = flWidth;

	// Off sections

	NSString *strImageLeftOff = [dictDef objectForKey:@"left off"];
	m_sprLeftOff = [MRDefinitionSprite spriteWithFrameName:strImageLeftOff];
	float flHalfHeight = [m_sprLeftOff contentSize].height * 0.5f;
	[self addChild:m_sprLeftOff z:1];
	m_sprLeftOff.visible = YES;
	[m_sprLeftOff allowAliasing:YES];
	m_sprLeftOff.anchorPoint = MRPoint(0.0f, 0.5f);
	[m_sprLeftOff setPosition:MRPoint(0, flHalfHeight)];

	CGSize sizeLeft = [m_sprLeftOff contentSize];

	NSString *strImageRightOff = [dictDef objectForKey:@"right off"];
	m_sprRightOff = [MRDefinitionSprite spriteWithFrameName:strImageRightOff];
	[self addChild:m_sprRightOff z:1];
	m_sprRightOff.visible = YES;
	[m_sprRightOff allowAliasing:YES];
	m_sprRightOff.anchorPoint = MRPoint(1.0f, 0.5f);
	[m_sprRightOff setPosition:MRPoint(flWidth, flHalfHeight)];

	CGSize sizeRight = [m_sprRightOff contentSize];

	NSString *strImageMiddleOff = [dictDef objectForKey:@"middle off"];
	m_sprMiddleOff = [MRDefinitionSprite spriteWithFrameName:strImageMiddleOff];
	[self addChild:m_sprMiddleOff z:0];
	m_sprMiddleOff.visible = YES;
	[m_sprMiddleOff allowAliasing:YES];
	m_sprMiddleOff.anchorPoint = MRPoint(1.0f, 0.5f);
	[m_sprMiddleOff setPosition:MRPoint(flWidth - sizeRight.width + XPOS_ALIGNMENT_ERROR, flHalfHeight)];



	// On sections


	NSString *strImageLeftOn = [dictDef objectForKey:@"left on"];
	m_sprLeftOn = [MRDefinitionSprite spriteWithFrameName:strImageLeftOn];
	[self addChild:m_sprLeftOn z:1];
	m_sprLeftOn.visible = NO;
	[m_sprLeftOn allowAliasing:YES];
	m_sprLeftOn.anchorPoint = MRPoint(0.0f, 0.5f);
	[m_sprLeftOn setPosition:MRPoint(0, flHalfHeight)];

	NSString *strImageRightOn = [dictDef objectForKey:@"right on"];
	m_sprRightOn = [MRDefinitionSprite spriteWithFrameName:strImageRightOn];
	[self addChild:m_sprRightOn z:1];
	m_sprRightOn.visible = NO;
	[m_sprRightOn allowAliasing:YES];
	m_sprRightOn.anchorPoint = MRPoint(1.0f, 0.5f);
	[m_sprRightOn setPosition:MRPoint(flWidth, flHalfHeight)];

	NSString *strImageMiddleOn = [dictDef objectForKey:@"middle on"];
	m_sprMiddleOn = [MRDefinitionSprite spriteWithFrameName:strImageMiddleOn];
	[self addChild:m_sprMiddleOn z:0];
	m_sprMiddleOn.visible = NO;
	[m_sprMiddleOn allowAliasing:YES];
	m_sprMiddleOn.anchorPoint = MRPoint(0.0f, 0.5f);
	[m_sprMiddleOn setPosition:MRPoint(sizeLeft.width - 1.0f, flHalfHeight)];



	m_flMiddleWidth = flWidth - sizeLeft.width - sizeRight.width;
	float flHeight = sizeLeft.height;
	[self setContentSize:CGSizeMake(flWidth, flHeight)];

	m_flPercent = 0.0f;
	m_flTargetPercent = 0.0f;
	[self updatePercent];

}

- (void)updatePercent
{
	CGSize sizeLeft = [m_sprLeftOn contentSize];
	CGSize sizeRight = [m_sprRightOn contentSize];
	CGSize sizeMiddleActual = [m_sprMiddleOn contentSize];
	float flFillWidth = m_flPercent * m_flFullWidth;
	if (flFillWidth < sizeLeft.width + sizeRight.width)
	{
		// All off
		m_sprLeftOn.visible		= NO;
		m_sprLeftOff.visible	= YES;
		m_sprRightOn.visible	= NO;
		m_sprRightOff.visible	= YES;

		m_sprMiddleOn.visible	= NO;
		float flScaleX = (m_flMiddleWidth + XPOS_ALIGNMENT_ERROR + 2.0f) / sizeMiddleActual.width;
		m_sprMiddleOff.visible	= YES;
		[m_sprMiddleOff setScaleX:flScaleX + SCALEX_ERROR];
		[m_sprMiddleOff setScaleY:1.0f - SCALEY_ERROR];
		flFillWidth = sizeLeft.width;
	}
	else // Has left end cap
	{
		m_sprLeftOn.visible		= YES;
		m_sprLeftOff.visible	= NO;

		float flMiddleOnWidth = flFillWidth - sizeLeft.width - sizeRight.width;
		flMiddleOnWidth = MIN(flMiddleOnWidth, m_flMiddleWidth);
		flMiddleOnWidth = MAX(0, flMiddleOnWidth);
		flMiddleOnWidth += XPOS_ALIGNMENT_ERROR;
		float flScaleX = (flMiddleOnWidth + 2.0f) / sizeMiddleActual.width;
		if (flScaleX > FLT_EPSILON)
		{
			[m_sprMiddleOn setScaleX:flScaleX + SCALEX_ERROR];
			[m_sprMiddleOn setScaleY:1.0f - SCALEY_ERROR];
			m_sprMiddleOn.visible = YES;
		}
		else
		{
			m_sprMiddleOn.visible = NO;
		}

		float flMiddleOffWidth = m_flMiddleWidth - flMiddleOnWidth;
		flMiddleOffWidth += XPOS_ALIGNMENT_ERROR;
		float flScaleXOff = (flMiddleOffWidth + 2.0f )/ sizeMiddleActual.width;
		if (flScaleXOff > FLT_EPSILON)
		{
			[m_sprMiddleOff setScaleX:flScaleXOff + SCALEX_ERROR];
			[m_sprMiddleOff setScaleY:1.0f - SCALEY_ERROR];
			m_sprMiddleOff.visible = YES;
		}
		else
		{
			m_sprMiddleOff.visible = NO;
		}

//		if (m_flPercent > 0.99f)
//		{
//			m_sprRightOn.visible = YES;
//			m_sprRightOff.visible = NO;
//		}
//		else
//		{
//			m_sprRightOn.visible = NO;
//			m_sprRightOff.visible = YES;
//		}

		m_sprRightOff.visible = YES;
		m_sprRightOn.visible = YES;
		[m_sprRightOn setPosition:MRPoint(flFillWidth, sizeRight.height / 2.0f)];
	}
}

- (void)setPercent:(float)flPercent
{
    flPercent = MIN(1.0f, flPercent);
    if (flPercent > m_flPercent)
    {
        m_flPercentPerCycle = STANDARD_SPEED;
    }
    else
    {
        m_flPercentPerCycle = HIGH_SPEED;
    }
    m_flTargetPercent = flPercent;
    [self updatePercent];
    [self schedule:@selector(animatePercent:)];

}

- (void)setPercentImmediate:(float)flPercent
{
    // Stop animating...
    [self unschedule:@selector(animatePercent:)];

    // And set us directly.
    flPercent = MIN(1.0f, flPercent);
    m_flTargetPercent = flPercent;
    m_flPercent = flPercent;
    [self updatePercent];
}

- (void)snapPercentToCurrent
{
    m_flPercent = m_flTargetPercent;
    [self updatePercent];
}

- (float)getPercent
{
    return m_flTargetPercent;
}

- (void)animatePercent:(MRTime)timeDelta
{
	float flDelta = m_flPercentPerCycle * timeDelta;
	if ((m_flTargetPercent - m_flPercent) > flDelta)
	{
		m_flPercent += flDelta;
	}
	else if ((m_flPercent - m_flTargetPercent) > flDelta)
	{
		m_flPercent -= flDelta;
	}
	else
	{
		m_flPercent = m_flTargetPercent;
		[self unschedule:@selector(animatePercent:)];
	}
	[self updatePercent];
}

@end

#endif
