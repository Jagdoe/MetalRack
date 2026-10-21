//
//  C2DProgressBar.h
//  Zombie
//
//  Created by Michael Scandizzo on 9/21/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRSceneConfiguration.h"
#import "MRDefinitionSprite.h"

#define STANDARD_SPEED	(0.1f)
#define HIGH_SPEED      (0.8f)

@interface MRProgressBar : MRDefinitionSprite
{
	MRDefinitionSprite	*m_sprLeftOn;
	MRDefinitionSprite	*m_sprLeftOff;
	MRDefinitionSprite	*m_sprMiddleOn;
	MRDefinitionSprite	*m_sprMiddleOff;
	MRDefinitionSprite	*m_sprRightOn;
	MRDefinitionSprite	*m_sprRightOff;
	float		m_flPercent;
	float		m_flTargetPercent;
	float		m_flFullWidth;
	float		m_flMiddleWidth;
    float       m_flPercentPerCycle;
}

+ (id)createFromDefinition:(NSDictionary *)dictDef;

- (void)setPercent:(float)flPercent;
- (void)setPercentImmediate:(float)flPercent;
- (void)snapPercentToCurrent;
- (float)getPercent;

// Private forward definition
- (void)updatePercent;

@end
