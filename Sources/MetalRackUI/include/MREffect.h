//
//  Effect.h
//  Fingerzilla
//
//  Created by Michael Scandizzo on 1/21/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRUIKit.h"

#define EFFECT_MAX_EXPLOSION	5

typedef enum EFFECT_TYPE
{
	EFFECT_NONE = 0,
	EFFECT_EXPLOSION,

	NUM_EFFECT_TYPES,
} EFFECT_TYPE;

@interface MREffect : MRSprite
{
	NSMutableArray	*m_aImages;
	float			m_flDuration;
	int				m_nRepeatCount;

@protected
	EFFECT_TYPE	 m_eEffect;
}

@property (nonatomic, strong) NSMutableArray *m_aImages;
@property float m_flDuration;
@property int m_nRepeatCount;

+ (void)initEffects;
+ (MREffect *)getFreeEffect:(EFFECT_TYPE)eType withPosition:(CGPoint)posNew;
+ (int)getActiveEffectCountOfType:(EFFECT_TYPE)eType;

- (id)initWithEffect:(EFFECT_TYPE)eType;

- (void)killMe;

@end
