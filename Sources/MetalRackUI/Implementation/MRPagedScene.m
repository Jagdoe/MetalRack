#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  PagedScene.m
//  Befuddled2
//
//  Created by Michael Scandizzo on 3/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MRPagedScene.h"
#import "MRInputLayer.h"
#import "MRSceneHost.h"
#import "MRUtilities.h"

@implementation MRPagedScene

@synthesize selOnChanged = m_selOnChanged;

- (id)init
{
    if ((self = [super init]))
    {
        m_nodePageDots = nil;
        m_selOnChanged = nil;
        m_flPageSize = MR_SCREEN_MINOR;
        m_nPages = 0;
    }
    return self;
}

- (void)setPageSize:(float)flPageSize
{
    m_flPageSize = flPageSize;
    [self setPageCount:m_nPages];
}

- (void)setPageCount:(int)nPages
{
    m_nPages = nPages;
    m_flXMin = -m_flPageSize * (nPages - 1);
    m_flYMin = 0.0f;
    m_flXMax = 0.0f;
    m_flYMax = 0.0f;
}

- (void)singleTouchEnded:(MRPointerEvent*)touch
{
    int nPreviousPage = m_nCurrentPage;

	CGPoint pointCurrent = layMain.position;
    float flDragDelta = (nPreviousPage * m_flPageSize) + pointCurrent.x;
    float flPageStart = -nPreviousPage * m_flPageSize;
    if (fabs(flDragDelta) > m_flPageSize * 0.25f)
    {
        float flDirection = fabsf(flDragDelta) / flDragDelta;
        flPageStart = flPageStart + flDirection * m_flPageSize;
    }

    int nCurrentPage = fabs(round(flPageStart / m_flPageSize));

	CGPoint pointDestination = MRPoint(flPageStart, pointCurrent.y);
	float flDuration = fabs(flPageStart - pointCurrent.x) * 0.5f / m_flPageSize;
	id actionMove = [MRMoveTo actionWithDuration:flDuration position:pointDestination];
	[layMain runAction:actionMove];

    // Do we have a selector to call when we've changed pages?
    if (m_selOnChanged != nil)
    {
        if (nPreviousPage != nCurrentPage)
            [self performSelector:m_selOnChanged];
    }

    [self updatePageDots:abs(nCurrentPage)];
}

- (int)getCurrentPage
{
    CGPoint posMain = layMain.position;
    int nPage = (int) round(-posMain.x / m_flPageSize);
    return nPage;
}


- (void)gotoPage:(int)nPage
{
    [layMain setPosition:MRPoint(-nPage * m_flPageSize, layMain.position.y)];
    [self updatePageDots:nPage];
}

- (void)updatePageDots:(int)nPage
{
    if (m_nodePageDots == nil)
        return;

    [m_nodePageDots removeAllChildrenWithCleanup:YES];
    float flX = 0.0f;

    if (m_nPages < 2)
        return;

	if (nPage >= m_nPages)
		nPage = m_nPages - 1;

    float flScaleAdjustment = [MRUtilities getDeviceScaleAdjustment];
    for (int i = 0; i < m_nPages; i++)
    {
        MRDefinitionSprite *sprDot;
        if (nPage == i)
            sprDot = [MRDefinitionSprite spriteWithFrameName:@"page_dot_on.png"];
        else
            sprDot = [MRDefinitionSprite spriteWithFrameName:@"page_dot_off.png"];

        CGSize sizeDot = [sprDot contentSize];
        [m_nodePageDots addChild:sprDot];
        [sprDot setPosition:MRPoint(flX, 0)];
        flX += sizeDot.width / 2.0f;
        flX += 10.0f * flScaleAdjustment;

    }
    m_nCurrentPage = nPage;
}

- (id)createPageDots:(int)nPageCount
{
	m_nodePageDots = [MRNode node];
    m_nPages = nPageCount;

    if (nPageCount < 2)
        return m_nodePageDots;

    float flWidth = 0.0f;

    float flScaleAdjustment = [MRUtilities getDeviceScaleAdjustment];

    MRDefinitionSprite *sprDotOn = [MRDefinitionSprite spriteWithFrameName:@"page_dot_on.png"];
    [m_nodePageDots addChild:sprDotOn];
    CGSize sizeDot = [sprDotOn contentSize];
    flWidth += sizeDot.width / 2.0f;
    [sprDotOn setPosition:MRPoint(0,0)];

    for (int i = 1; i < nPageCount; i++)
    {
        flWidth += 10.0f * flScaleAdjustment;
        MRDefinitionSprite *sprDotOff = [MRDefinitionSprite spriteWithFrameName:@"page_dot_off.png"];
        CGSize sizeDot = [sprDotOff contentSize];
        [m_nodePageDots addChild:sprDotOff];
        [sprDotOff setPosition:MRPoint(flWidth, 0)];
        flWidth += sizeDot.width / 2.0f;
    }

    [m_nodePageDots setContentSize:CGSizeMake(flWidth, sizeDot.height)];
    [m_nodePageDots setAnchorPoint:MRPoint(0.5f, 0.5f)];
    return m_nodePageDots;
}

@end

#endif
