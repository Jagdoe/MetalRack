//
//  C2DPanel.h
//  Gnomes
//
//  Created by Michael Scandizzo on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MRDefinitionSprite.h"

@interface MRPanel : MRDefinitionSprite
{
	MRDefinitionSprite		*m_sprTop;
	MRDefinitionSprite		*m_sprMiddle;
	MRDefinitionSprite		*m_sprBottom;
}

+ (id)panelFromDefaults;

- (id)initFromDefaults;

- (void)setHeight:(float)flMiddleHeight withWidth:(float)flWidth;
- (void)setHeight:(float)flMiddleHeight withScale:(float)flWidthScale;
- (void)setHeight:(float)flMiddleHeight withScale:(float)flWidthScale withColor:(MRColor3B)colorPanel;

@end
