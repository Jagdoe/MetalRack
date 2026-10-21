#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  TouchLadderLayer.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 5/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MRGestureLayer.h"


@implementation MRGestureLayer

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		m_idTouchTarget	= nil;
        m_idNextTarget = nil;
	}

	return (self);
}

- (void)dealloc
{
	// Just clear targets.
	m_idTouchTarget	= nil;

    m_idNextTarget = nil;

	// Lastly, do parent stuff.
	(void)0;
}

#pragma mark -
#pragma mark Standard Interface

// We'll send to our parent if we haven't had this
// specifically set.
- (void)setTouchTarget:(id<MRGestureDelegate>)idObject
{
	m_idTouchTarget = idObject;
}

- (void)setNextTarget:(id)idObject
{
    m_idNextTarget = idObject;
}

#pragma mark -
#pragma mark Touch Routines

-(void) pointersBegan:(NSSet *)touches
{
	MRPointerEvent *touch = [touches anyObject];
    BOOL fAbsorb = [m_idTouchTarget singleTouchBegan:touch];
    if (fAbsorb == NO && m_idNextTarget != nil)
    {
        [m_idNextTarget performSelector:@selector(pointersBegan:) withObject:touches];
    }
}

-(void) pointersMoved:(NSSet *)touches
{
	MRPointerEvent *touch = [touches anyObject];
    BOOL fAbsorb = [m_idTouchTarget singleTouchMoved:touch];
    if (fAbsorb == NO && m_idNextTarget != nil)
    {
        [m_idNextTarget performSelector:@selector(pointersMoved:) withObject:touches];
    }
}

-(void) pointersEnded:(NSSet *)touches
{
	MRPointerEvent *touch = [touches anyObject];
    BOOL fAbsorb = [m_idTouchTarget singleTouchEnded:touch];
    if (fAbsorb == NO && m_idNextTarget != nil)
    {
        [m_idNextTarget performSelector:@selector(pointersEnded:) withObject:touches];
    }
}

@end

#endif
