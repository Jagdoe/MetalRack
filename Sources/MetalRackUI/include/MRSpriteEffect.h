//
//  C2DSpriteEffect.h
//  Fingerzilla
//
//  Created by Michael Scandizzo on 5/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRDefinitionSprite.h"

@interface MRSpriteEffect : MRDefinitionSprite
{
	float			m_flDuration;
    float           m_flDurationDelta;
	int				m_nRepeatCount;
    int             m_nRepeatCountDelta;
    BOOL            m_fRandomAngle;
}

@property float m_flDuration;
@property int m_nRepeatCount;


+ (void)initEffects;
+ (MRSpriteEffect *)getFreeEffect:(NSDictionary *)dictEffect withPosition:(CGPoint)posNew;
+ (int)getActiveEffectCountOfType:(NSDictionary *)dictEffect;

- (void)prepareEffect;

- (void)killMe;

@end
