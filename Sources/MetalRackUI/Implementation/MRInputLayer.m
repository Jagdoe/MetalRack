#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  TouchLayer.m
//  Zombie
//
//  Created by Tom the Great on 5/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRInputLayer.h"
#import "MRUIKit.h"

// Macros.

// Statics.

@implementation MRInputLayer

@synthesize isTouchTargeted = m_fTargeted;

+ (id)touchLayerWithTargetedTouches:(BOOL)fValue
{
	MRInputLayer *newLayer = ([[self alloc] init]);
	newLayer.isTouchTargeted = fValue;
	return newLayer;
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		m_idTouchTarget	= nil;
		m_selTouchBegan = nil;
		m_selTouchMoved = nil;
		m_selTouchEnded = nil;
		m_fTargeted = NO;
	}

	return (self);
}

- (void)dealloc
{
	// Just clear targets.
	m_idTouchTarget	= nil;
	m_selTouchBegan = nil;
	m_selTouchMoved = nil;
	m_selTouchEnded = nil;

	// Lastly, do parent stuff.
	(void)0;
}

#pragma mark -
#pragma mark Private Routines
- (void)localPerformSelector:(SEL)selector withObject:(id)idObject
{
	if (selector == nil)
		return;

	id idTarget = m_idTouchTarget;
	if (idTarget == nil)
		idTarget = self.parent;
	if ([idTarget respondsToSelector:selector] == YES)
    {
        void (*callback)(id, SEL, id)=(void *)[idTarget methodForSelector:selector];
        callback(idTarget,selector,idObject);
    }
}

- (void)registerInput
{
    [self.environment.input removeReceiver:self];
    if (self.inScene && self.isTouchEnabled)
        [self.environment.input addReceiver:self priority:self.inputPriority swallows:m_fTargeted];
}

#pragma mark -
#pragma mark Standard Interface

// We'll send to our parent if we haven't had this
// specifically set.
- (void)setTouchTarget:(id)idObject
{
	m_idTouchTarget = idObject;
}

- (void)setTouchBegan:(SEL)selTouch
{
	m_selTouchBegan = selTouch;
}

- (void)setTouchMoved:(SEL)selTouch
{
	m_selTouchMoved = selTouch;
}

- (void)setTouchEnded:(SEL)selTouch
{
	m_selTouchEnded = selTouch;
}

- (void)setTouchBegan:(SEL)selBegan withMoved:(SEL)selMoved withEnded:(SEL)selEnded
{
	m_selTouchBegan = selBegan;
	m_selTouchMoved = selMoved;
	m_selTouchEnded = selEnded;
}

#pragma mark -
#pragma mark Touch Routines

// Standard
-(void) pointersBegan:(NSSet *)touches
{
	//NSLog(@"TouchLayer - began.");
	MRPointerEvent *touch = [touches anyObject];
	[self localPerformSelector:m_selTouchBegan withObject:touch];
}

-(void) pointersMoved:(NSSet *)touches
{
	//NSLog(@"TouchLayer - moved.");
	MRPointerEvent *touch = [touches anyObject];
	[self localPerformSelector:m_selTouchMoved withObject:touch];
}

-(void) pointersEnded:(NSSet *)touches
{
	//NSLog(@"TouchLayer - ended.");
	MRPointerEvent *touch = [touches anyObject];
	[self localPerformSelector:m_selTouchEnded withObject:touch];
}

//Targeted
// Returning YES claims the touch
- (BOOL)pointerBegan:(MRPointerEvent *)touch
{
    if (!m_fTargeted) { if(m_hasStandardPointer)return NO;m_hasStandardPointer=YES;m_standardPointer=touch.identifier;return [super pointerBegan:touch]; }
    if (m_selTouchBegan == nil) return NO;

	id idTarget = m_idTouchTarget;
	if (idTarget == nil)
		idTarget = self.parent;
	if ([idTarget respondsToSelector:m_selTouchBegan] == YES)
    {
        BOOL (*callback)(id, SEL, MRPointerEvent *)=(void *)[idTarget methodForSelector:m_selTouchBegan];
        return callback(idTarget,m_selTouchBegan,touch);
    }
	return NO;
}

- (void)pointerMoved:(MRPointerEvent *)touch
{
    if(!m_fTargeted && (!m_hasStandardPointer || touch.identifier!=m_standardPointer))return;
	[self localPerformSelector:m_selTouchMoved withObject:touch];
}

- (void)pointerEnded:(MRPointerEvent *)touch
{
    if(!m_fTargeted){if(!m_hasStandardPointer || touch.identifier!=m_standardPointer)return;m_hasStandardPointer=NO;}
	[self localPerformSelector:m_selTouchEnded withObject:touch];
}

- (void)pointerCancelled:(MRPointerEvent *)event {
    if(!m_fTargeted && event.identifier==m_standardPointer)m_hasStandardPointer=NO;
    [super pointerCancelled:event];
}
@end

#endif
