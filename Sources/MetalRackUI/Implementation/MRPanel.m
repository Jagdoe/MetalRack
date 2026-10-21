#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DPanel.m
//  Gnomes
//
//  Created by Michael Scandizzo on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MRPanel.h"

@implementation MRPanel

// Need a custom one so it won't barf on not having an image
+ (id)createFromDefinition:(NSDictionary *)dictDef
{
	MRPanel *panelNew = ([[self alloc] init]);
	[panelNew initFromDefinition:dictDef];
	return panelNew;
}

+ (id)panelFromDefaults
{
	return ([[self alloc] initFromDefaults]);
}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
	[super initFromDefinition:dictDef];

    // We'll always color our children by default.
    [self setColorChildren:YES];

	NSString *strTop	= [dictDef objectForKey:@"top image"];
	NSString *strMiddle	= [dictDef objectForKey:@"middle image"];
	NSString *strBottom	= [dictDef objectForKey:@"bottom image"];

	m_sprTop	= [MRDefinitionSprite createFromDefOrFrameName:strTop];
	m_sprMiddle	= [MRDefinitionSprite createFromDefOrFrameName:strMiddle];
	m_sprBottom	= [MRDefinitionSprite createFromDefOrFrameName:strBottom];
	[self addChild:m_sprTop];
	[self addChild:m_sprMiddle];
	[self addChild:m_sprBottom];

    [self setAnchorPoint:MRPoint(0.5f, 0.5f)];
}

- (id)initFromDefaults
{
	self = [super init];
	if (self != nil)
	{
		m_sprTop = [MRDefinitionSprite spriteWithFrameName:@"panel_top.png"];
		m_sprMiddle = [MRDefinitionSprite spriteWithFrameName:@"panel_middle.png"];
		m_sprBottom = [MRDefinitionSprite spriteWithFrameName:@"panel_bottom.png"];
		[self addChild:m_sprMiddle];
		[self addChild:m_sprTop];
		[self addChild:m_sprBottom];

		[self setAnchorPoint:MRPoint(0.5f, 0.5f)];
	}
	return self;
}

- (void)setHeight:(float)flMiddleHeight withWidth:(float)flWidth
{
    float flScale = flWidth / m_sprMiddle.contentSize.width;
    [self setHeight:flMiddleHeight withScale:flScale];
}

- (void)setHeight:(float)flMiddleHeight withScale:(float)flWidthScale
{
	MRColor3B white = MRRGB(255, 255, 255);
	[self setHeight:flMiddleHeight withScale:flWidthScale withColor:white];
}

- (void)setHeight:(float)flMiddleHeight withScale:(float)flWidthScale withColor:(MRColor3B)colorPanel
{
    // Panel
	float flIPadFactor = 4.0f;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        flIPadFactor = 8.0f;

    [m_sprTop setAnchorPoint:MRPoint(0.5f, 1.0f)];
    [m_sprTop setColor:colorPanel];
    [m_sprTop setScale:flWidthScale];
    CGSize sizeTop = [m_sprTop boundingBox].size;

    float flBaseHeight = [m_sprMiddle contentSize].height;
    [m_sprMiddle setAnchorPoint:MRPoint(0.5f, 0.0f)];
    [m_sprMiddle allowAliasing:YES];
    [m_sprMiddle setColor:colorPanel];
	float flMiddleScaleY = flMiddleHeight;
    [m_sprMiddle setScaleY:flMiddleScaleY / flBaseHeight];
    [m_sprMiddle setScaleX:flWidthScale];
    CGSize sizeMiddle = [m_sprMiddle boundingBox].size;

    float flYOffset = 0;
    sizeMiddle.height -= 2.0f * flIPadFactor; // Fudge height for overlap
    flYOffset = 1.0f * flIPadFactor;

    [m_sprBottom setAnchorPoint:MRPoint(0.5f, 0.0f)];
    [m_sprBottom setColor:colorPanel];
    [m_sprBottom setScale:flWidthScale];

    CGSize sizeBottom = [m_sprBottom boundingBox].size;

    float flWidth = sizeTop.width; // + sizeMiddle.width + sizeBottom.width;
    float flHeight = sizeTop.height + sizeBottom.height + sizeMiddle.height;
    CGSize sizePanel = CGSizeMake(flWidth, flHeight);

    [self setContentSize:sizePanel];

    [m_sprTop setPosition:MRPoint(sizePanel.width * 0.5f, sizePanel.height + flYOffset / 2)];
    [m_sprBottom setPosition:MRPoint(sizePanel.width * 0.5f, 0)];
    [m_sprMiddle setPosition:MRPoint(sizePanel.width * 0.5f, sizeBottom.height - flYOffset)];
}

@end

#endif
