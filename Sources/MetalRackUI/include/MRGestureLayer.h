//
//  TouchLadderLayer.h
//  Fingerzilla
//
//  Created by Michael Scandizzo on 5/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"

@protocol MRGestureDelegate <NSObject>

@required
- (BOOL)singleTouchBegan:(MRPointerEvent*)touch;
- (BOOL)singleTouchMoved:(MRPointerEvent *)touch;
- (BOOL)singleTouchEnded:(MRPointerEvent *)touch;

@end

@interface MRGestureLayer : MRLayer
{
	__weak id<MRGestureDelegate>		m_idTouchTarget;
    __weak id                          m_idNextTarget;
}

- (void)setNextTarget:(id)idObject;

- (void)setTouchTarget:(id<MRGestureDelegate>)idObject;

@end
