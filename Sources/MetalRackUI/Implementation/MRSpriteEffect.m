#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DSpriteEffect.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 5/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MRSpriteEffect.h"
#import "MRDefinitions.h"
#import "MRDefinitionSprite.h"

@implementation MRSpriteEffect


@synthesize m_flDuration;
@synthesize m_nRepeatCount;

static BOOL					sgfIsInitialized = NO;	// Have we had our master class init yet?
static NSMutableDictionary  *sgdictFreeEffects;


+ (void)initEffects
{
    // Don't re-run this code
    if (sgfIsInitialized == YES)
        return;

	NSArray *aEffectDefs = [[MRDefinitions sharedDefsManager] getDefsOfClass:@"C2DSpriteEffect" addSubclasses:YES];

    sgdictFreeEffects = ([NSMutableDictionary dictionaryWithCapacity:[aEffectDefs count]]);

    for (NSString *strEffect in aEffectDefs)
    {
        NSDictionary *dictEffect = [[MRDefinitions sharedDefsManager] getDefByName:strEffect];
        // First load the art files
        NSString *strTextureFile = [dictEffect objectForKey:@"texture plist"];
        [[MRSceneRuntime sharedRuntime] loadAtlasNamed:strTextureFile];

        // Find how many effects we want to cache
        int nCacheSize = [[dictEffect objectForKey:@"cache size"] intValue];

        NSMutableArray *aEffectsOfThisType = ([NSMutableArray arrayWithCapacity:nCacheSize]);

		for (int i = 0; i < nCacheSize; i++)
		{
			MRSpriteEffect *pEffect = ([MRSpriteEffect createFromDefinition:dictEffect]);
			[aEffectsOfThisType addObject:pEffect];
		}
        [sgdictFreeEffects setObject:aEffectsOfThisType forKey:dictEffect];
	}
    sgfIsInitialized = YES;

}

+ (MRSpriteEffect *)getFreeEffect:(NSDictionary *)dictEffect withPosition:(CGPoint)posNew
{
//	// Early out if we don't support hi-res.  Our framerate suffers with effects
//	if (1 == 1)
//		return nil;

    if (sgfIsInitialized == FALSE)
		[MRSpriteEffect initEffects];

    NSMutableArray *aFreeEffects = [sgdictFreeEffects objectForKey:dictEffect];

	if ([aFreeEffects count] > 0)
	{
		MRSpriteEffect *pEffect = [aFreeEffects objectAtIndex:0];
		[aFreeEffects removeObjectAtIndex:0];

        [pEffect prepareEffect];

		[pEffect setPosition:posNew];

		return (pEffect);
	}
	return (nil);
}

+ (int)getActiveEffectCountOfType:(NSDictionary *)dictEffect
{
	if (sgfIsInitialized == FALSE)
		[MRSpriteEffect initEffects];

    NSMutableArray *aFreeEffects = [sgdictFreeEffects objectForKey:dictEffect];

	int nFree = [aFreeEffects count];
    int nCacheSize = [[dictEffect objectForKey:@"cache size"] intValue];
	int nActive = nCacheSize - nFree;
	return nActive;
}

+ (id)createFromDefinition:(NSDictionary *)dictDef
{
	MRSpriteFrame *frame = [MRDefinitionSprite getSpriteFrameFromDefinition:dictDef];
	MRSpriteEffect *effectNew = [MRSpriteEffect spriteWithFrame:frame];
	[effectNew initFromDefinition:dictDef];
	return effectNew;
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
	}
	return (self);
}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
	[super initFromDefinition:dictDef];

    m_flDuration        = [[dictDef objectForKey:@"duration"] floatValue];
    m_flDurationDelta   = [[dictDef objectForKey:@"duration delta"] floatValue];
    m_nRepeatCount      = [[dictDef objectForKey:@"repeat count"] intValue];
    m_nRepeatCountDelta = [[dictDef objectForKey:@"repeat count delta"] intValue];
    m_fRandomAngle      = [[dictDef objectForKey:@"random angle"] boolValue];
}


- (void)prepareEffect
{
    float flDuration = m_flDuration + (MRRandomUnit() * m_flDurationDelta);
    int nRepeatCount = m_nRepeatCount + (random() % (m_nRepeatCountDelta + 1));
    if (m_fRandomAngle == YES)
    {
		// Rotate us randomly.
		float flAngle = MRRandomUnit() * 360.0f;
		[self setRotation:flAngle];
    }

    float flDelay = flDuration * (nRepeatCount + 1);
    float flFrameRate = flDuration / [m_aAnimationFrames count];
    MRAnimation *animMixed = [MRAnimation animationWithFrames:m_aAnimationFrames delay:flFrameRate];

    [self stopAllActions];
    if (nRepeatCount > 0)
    {
        [self runAction:[MRRepeat actionWithAction:[MRAnimate actionWithAnimation:animMixed restoreOriginalFrame:NO] times:nRepeatCount + 1]];

    }
    else
    {
        [self runAction:[MRAnimate actionWithAnimation:animMixed restoreOriginalFrame:NO]];
    }
    [self unschedule:@selector(killMe)];
    [self performSelector:@selector(killMe) withObject:self afterDelay:flDelay];

    if (self.parent != nil)
        NSLog(@"Error! Free Effect has parent %@!", self.parent);
}

/*
- (id)initWithEffect:(EFFECT_TYPE)eType
{

	if (eType == EFFECT_EXPLOSION)
	{
		m_aImages =			aEffects[eType];
		m_flDuration =		0.40f + (CCRANDOM_0_1() * 0.2f);
		m_nRepeatCount =	1;
		// Rotate us randomly.
		float flAngle = CCRANDOM_0_1() * 360.0f;
		[self setRotation:flAngle];
	}
	else if (eType == EFFECT_FIRE)
	{
		m_aImages =			aEffects[eType];
		m_flDuration =		1.00f + (random() % 100) / 800.0f;
		m_nRepeatCount =	5 + (random() % 5);
	}

	// Done.
	return self;
}
*/

- (void)killMe
{
    NSMutableArray *aFreeEffects = [sgdictFreeEffects objectForKey:self.m_dictDef];
    if (aFreeEffects == nil)
    {
        NSLog(@"Warning! Illegal effect attempted to return to the cache!");
        return;
    }
    if ([aFreeEffects containsObject:self] == YES)
    {
        NSLog(@"Warning! killMe: Can't return a C2DSpriteEffect to the cache twice.");
        return;
    }

	// Remove any pending selectors.
    [self stopAllActions];
	[MRSpriteEffect cancelPreviousPerformRequestsWithTarget:self selector:@selector(killMe) object:self];


	[self.parent removeChild:self cleanup:NO];
	[self removeFromParent];
    [self setColor:MRRGB(255, 255, 255)];

    [aFreeEffects addObject:self];
}

- (void)cleanup
{
    // Don't call super.  Protects us from a cleanup that would delete rather than re-insert us to the queue
    NSMutableArray *aFreeEffects = [sgdictFreeEffects objectForKey:self.m_dictDef];
    if (aFreeEffects == nil)
    {
        NSLog(@"Warning! Illegal effect attempted to return to the cache!");
        return;
    }
    if ([aFreeEffects containsObject:self] == YES)
    {
        NSLog(@"Warning! cleanup: Can't return a C2DSpriteEffect to the cache twice.");
        return;
    }

    [MRSpriteEffect cancelPreviousPerformRequestsWithTarget:self selector:@selector(killMe) object:self];
    [self removeFromParent];
    [aFreeEffects addObject:self];

}

- (void)dealloc
{
    (void)0;
}

@end

#endif
