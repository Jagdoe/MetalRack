#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DToolbar.m
//  Zombie
//
//  Created by Michael Scandizzo on 5/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRToolbar.h"
#import "MRButton.h"

@implementation MRToolbar

- (id)initWithContentSize:(CGSize)size margin:(CGSize)sizeMargin;
{
	if ((self = [super init]))
	{
		[self setContentSize:size];
		m_flXPlacement = -size.width / 2.0 + sizeMargin.width;
		m_flYPlacement = -size.height / 2.0 + sizeMargin.height;
		self.isTouchEnabled = YES;
		m_sprBackground = nil;
		m_flXSpacing = 2.0f;
		[self setAnchorPoint:MRPoint(0.5f, 0.0f)];
	}
	return self;
}
- (void)setXSpacing:(float)flXSpacing
{
	m_flXSpacing = flXSpacing;
}

- (void)setLabelForButton:(MRButton*)button withLabel:(NSString *)strLabel
{
	[button setText:strLabel atPosition:MRPoint(16, -24)];
}

- (void)setBackgroundWithSpriteFrameName:(NSString *)strName
{
	m_sprBackground = [MRDefinitionSprite spriteWithFrameName:strName];
	[self addChild:m_sprBackground];
	[m_sprBackground setPosition:MRPoint(0, 0)];
}

- (id)addSpriteWithSpriteFrameName:(NSString *)strName
{
	MRDefinitionSprite *sprNew = [MRDefinitionSprite spriteWithFrameName:strName];

	[self addChild:sprNew];
	CGSize sizeNew = [sprNew contentSize];
	[sprNew setAnchorPoint:MRPoint(0.5f, 1.0f)];
	[sprNew setPosition:MRPoint(m_flXPlacement + sizeNew.width / 2.0, m_flYPlacement)];
	m_flXPlacement += sizeNew.width + m_flXSpacing;
	return sprNew;
}

- (id)addButtonWithSpriteFrameName:(NSString *)strName label:(NSString *)strLabel tag:(int)nTag selector:(SEL)selTouch target:(id)idTouch
{
	MRButton *button = ([[MRButton alloc] initWithFrameName:strName]);
	[self addChild:button];
	[button addTouchTarget:selTouch forObject:idTouch];
	CGSize sizeNew = [button contentSize];
	//[button setAnchorPoint:ccp(0.5f, 1.0f)];
	[button setPosition:MRPoint(m_flXPlacement + sizeNew.width / 2.0f, m_flYPlacement - (sizeNew.height / 2.0f))];
	[self setLabelForButton:button withLabel:strLabel];
	m_flXPlacement += sizeNew.width + m_flXSpacing;
	[button setTag:nTag];
	return button;
}

- (BOOL)hitTest:(MRPointerEvent *)touch
{
	if (m_sprBackground != nil)
		return [m_sprBackground hitTest:touch];
	else
	{
		if ([self isTouchEnabled] == NO)
				return NO;

		if (self.visible == NO || self.inScene == NO)
			return NO;

		CGSize szContent;
		szContent = [self contentSize];

		CGPoint ptOrigin = self.position;

		CGPoint ptAnchor = self.anchorPoint;

		ptOrigin.x -= szContent.width * ptAnchor.x;
		ptOrigin.y -= szContent.height * ptAnchor.y;

		CGRect rectBounding = CGRectMake(ptOrigin.x, ptOrigin.y, szContent.width, szContent.height);

		CGPoint Position = touch.position;

		Position = Position;

		return CGRectContainsPoint(rectBounding, Position);	}
}


@end

#endif
