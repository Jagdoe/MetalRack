#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DCheckbox.m
//  Befuddled2
//
//  Created by Michael Scandizzo on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MRCheckbox.h"

@implementation MRCheckbox

@synthesize m_fChecked;

//+ (id)createFromDefinition:(NSDictionary *)dictDef
//{
//	CCSpriteFrame *frame = [C2DSprite getSpriteFrameFromDefinition:dictDef];
//	C2DCheckbox *checkbox = [C2DCheckbox spriteWithSpriteFrame:frame];
//	[checkbox initFromDefinition:dictDef];
//	return checkbox;
//}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
    [super initFromDefinition:dictDef];
    NSString *strUnchecked  = [dictDef objectForKey:@"image unchecked"];
    NSString *strChecked    = [dictDef objectForKey:@"image checked"];
    m_frameUnchecked    = [[MRSceneRuntime sharedRuntime].resources frameNamed:strUnchecked];
    m_frameChecked      = [[MRSceneRuntime sharedRuntime].resources frameNamed:strChecked];
    m_fChecked = NO;
    m_idTouchCheckbox   = nil;
    m_selTouchCheckbox  = nil;
    [self setFrame:m_frameUnchecked];
    [self addTouchTarget:@selector(touchCheck:) forObject:self];
}

- (void)touchCheck:(id)idCheckbox
{
    if (m_fChecked == NO)
    {
        m_fChecked = YES;
        [self setFrame:m_frameChecked];
    }
    else
    {
        m_fChecked = NO;
        [self setFrame:m_frameUnchecked];
    }
    [m_idTouchCheckbox performSelector:m_selTouchCheckbox withObject:self];
}

- (void)setCheckboxState:(BOOL)fChecked
{
    m_fChecked = fChecked;
    if (m_fChecked == YES)
    {
        [self setFrame:m_frameChecked];
    }
    else
    {
        [self setFrame:m_frameUnchecked];
    }
}

- (void)setCheckboxCallback:(SEL)selTouch forObject:(id)idObject
{
	m_idTouchCheckbox = idObject;
	m_selTouchCheckbox = selTouch;
}


@end

#endif
