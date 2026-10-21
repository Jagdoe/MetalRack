#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  Effect.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 1/21/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MREffect.h"

@implementation MREffect

@synthesize m_aImages;
@synthesize m_flDuration;
@synthesize m_nRepeatCount;

static BOOL					fIsInitialized = FALSE;	// Have we had our master class init yet?
static NSMutableArray		*aEffects[NUM_EFFECT_TYPES];			// Holds our list of digit values.
static NSMutableArray		*aFreeEffects[NUM_EFFECT_TYPES];
static int					snCacheSize[NUM_EFFECT_TYPES] = { 0, EFFECT_MAX_EXPLOSION };

+ (void)initEffects
{
	[[MRSceneRuntime sharedRuntime] loadAtlasNamed:@"explosion.plist"];

	fIsInitialized = TRUE;
	// Set up and fill our value type array.
	aEffects[EFFECT_EXPLOSION] = ([NSMutableArray arrayWithCapacity:16]);
	for (int nFrames = 0; nFrames < 16; ++nFrames)
	{
		NSString *imageName = [NSString stringWithFormat:@"explosion_%d.png", nFrames];
		MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:imageName];
		[aEffects[EFFECT_EXPLOSION] addObject:frame];
	}

	for (int nEffectType = 0; nEffectType < NUM_EFFECT_TYPES; nEffectType++)
	{
		aFreeEffects[nEffectType] = ([NSMutableArray arrayWithCapacity:snCacheSize[nEffectType]]);
		for (int i = 0; i < snCacheSize[nEffectType]; i++)
		{
			MREffect *pEffect = [[MREffect alloc] initWithEffect:nEffectType];
			[aFreeEffects[nEffectType] addObject:pEffect];
		}
	}
}

+ (MREffect *)getFreeEffect:(EFFECT_TYPE)eType withPosition:(CGPoint)posNew;
{
	// Early out if we don't support hi-res.  Our framerate suffers with effects
	if (1 == 1)
		return nil;

	if ([aFreeEffects[eType] count] > 0)
	{
		MREffect *pEffect = [aFreeEffects[eType] objectAtIndex:0];
		[aFreeEffects[eType] removeObjectAtIndex:0];


		float flDelay = pEffect.m_flDuration * pEffect.m_nRepeatCount;
		float flFrameRate = pEffect.m_flDuration / [aEffects[eType] count];
		MRAnimation *animMixed = [MRAnimation animationWithFrames:aEffects[eType] delay:flFrameRate];
		[pEffect runAction:[MRRepeat actionWithAction:[MRAnimate actionWithAnimation:animMixed restoreOriginalFrame:NO] times:pEffect.m_nRepeatCount]];

		[pEffect performSelector:@selector(killMe) withObject:pEffect afterDelay:flDelay];

		pEffect.position = posNew;

		return (pEffect);
	}
	return (nil);
}

+ (int)getActiveEffectCountOfType:(EFFECT_TYPE)eType
{
	if (fIsInitialized == FALSE)
		[MREffect initEffects];

	if ((int)eType < 0 || eType >= NUM_EFFECT_TYPES)
		return 0;

	int nFree = [aFreeEffects[eType] count];
	int nMax = snCacheSize[eType];
	int nActive = nMax - nFree;
	return nActive;
}

- (id)initWithEffect:(EFFECT_TYPE)eType
{
	if (fIsInitialized == FALSE)
		[MREffect initEffects];

	self = [super initWithFrame:[aEffects[EFFECT_EXPLOSION] objectAtIndex:0]];
	if (self == nil)
		return nil;


	if (eType == EFFECT_EXPLOSION)
	{
		m_aImages =			aEffects[eType];
		m_flDuration =		0.40f + (MRRandomUnit() * 0.2f);
		m_nRepeatCount =	1;
		// Rotate us randomly.
		float flAngle = MRRandomUnit() * 360.0f;
		[self setRotation:flAngle];
	}
//	else if (eType == EFFECT_FIRE)
//	{
//		m_aImages =			aEffects[eType];
//		m_flDuration =		1.00f + (random() % 100) / 800.0f;
//		m_nRepeatCount =	5 + (random() % 5);
//	}

	// We have one more of us active.
	m_eEffect = eType;

	// Done.
	return self;
}

- (void)killMe
{
	// Remove any pending selectors.
	[MREffect cancelPreviousPerformRequestsWithTarget:self selector:@selector(killMe) object:self];


	[self.parent removeChild:self cleanup:YES];
	[self removeFromParent];

	[aFreeEffects[m_eEffect] addObject:self];
}

- (void)dealloc
{
    (void)0;
}


@end

#endif
