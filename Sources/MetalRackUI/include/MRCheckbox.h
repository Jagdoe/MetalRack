//
//  C2DCheckbox.h
//  Befuddled2
//
//  Created by Michael Scandizzo on 3/15/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRButton.h"
#import "MRUIKit.h"

@interface MRCheckbox : MRButton
{
    BOOL            m_fChecked;
    MRSpriteFrame   *m_frameUnchecked;
    MRSpriteFrame   *m_frameChecked;
    id              m_idTouchCheckbox;
    SEL             m_selTouchCheckbox;
}

@property (nonatomic, readonly, getter = IsChecked) BOOL    m_fChecked;

- (void)setCheckboxCallback:(SEL)selTouch forObject:(id)idObject;
- (void)setCheckboxState:(BOOL)fChecked;

@end
