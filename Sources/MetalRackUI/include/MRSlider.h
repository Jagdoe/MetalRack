//
//  C2DSlider.h
//  Zombie
//
//  Created by Michael Scandizzo on 11/15/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRButton.h"
#import "MRDefinitionSprite.h"

@interface MRSlider : MRDefinitionSprite <MRPointerReceiver>
{
	MRButton       *m_buttonControl;
	SEL				m_selTouchBegin;
	id				m_idTouchBegin;
}

- (id)initWithFrameName:(NSString *)strFrame;
- (void)addTouchTarget:(SEL)selTouch forObject:(id)idObject;
- (float)getPercent;
- (void)setPercent:(float)flPercent;

@end
