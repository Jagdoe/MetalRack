//
//  C2DToolbar.h
//  Zombie
//
//  Created by Michael Scandizzo on 5/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"

@class MRDefinitionSprite;
@class MRButton;

@interface MRToolbar : MRLayer
{
	MRDefinitionSprite	*m_sprBackground;
	float		m_flXPlacement;
	float		m_flYPlacement;
	float		m_flXSpacing;
}

- (id)initWithContentSize:(CGSize)size margin:(CGSize)sizeMargin;
- (void)setBackgroundWithSpriteFrameName:(NSString *)strName;
- (id)addSpriteWithSpriteFrameName:(NSString *)strName;
- (id)addButtonWithSpriteFrameName:(NSString *)strName label:(NSString *)strLabel tag:(int)nTag selector:(SEL)selTouch target:(id)idTouch;
- (void)setXSpacing:(float)flXSpacing;
- (void)setLabelForButton:(MRButton*)button withLabel:(NSString *)strLabel;

- (BOOL)hitTest:(MRPointerEvent *)touch;

@end
