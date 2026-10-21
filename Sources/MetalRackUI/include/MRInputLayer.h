//
//  TouchLayer.h
//  Zombie
//
//  Created by Tom the Great on 5/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRCullLayer.h"

@interface MRInputLayer : MRCullLayer
{
	BOOL	m_fTargeted;
    BOOL m_hasStandardPointer;
    NSUInteger m_standardPointer;
	__weak id		m_idTouchTarget;
	SEL		m_selTouchBegan;
	SEL		m_selTouchMoved;
	SEL		m_selTouchEnded;
}

@property (assign) BOOL isTouchTargeted;

// Yes means CCTargetedDispatchHandler.  No means CCStandardDispatchHandler
+ (id)touchLayerWithTargetedTouches:(BOOL)fValue;

- (void)setTouchTarget:(id)idObject;
- (void)setTouchBegan:(SEL)selTouch;
- (void)setTouchMoved:(SEL)selTouch;
- (void)setTouchEnded:(SEL)selTouch;
- (void)setTouchBegan:(SEL)selBegan withMoved:(SEL)selMoved withEnded:(SEL)selEnded;

@end
