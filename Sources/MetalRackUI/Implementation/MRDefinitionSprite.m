#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DSprite.m
//  Zombie
//
//  Created by Michael Scandizzo on 6/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRSceneHost.h"
#import "MRSnapshot.h"
#import "MRDefinitionSprite.h"
#import "MRDefinitions.h"
#import "2DMath.h"
#import "MRUtilities.h"
#import "MRTextLabel.h"
#import "MRValues.h"
#import "NSMutableDictionary+Union.h"

@implementation MRDefinitionSprite

@synthesize flScaleDefault = m_flScaleDefault;
@synthesize tagString;
@synthesize m_aAttachments;
@synthesize m_aDecals;
@synthesize m_dictDef;
@synthesize m_dictDisplayDef;
@synthesize m_strDefinition;
@synthesize m_fIconOnly;
@synthesize m_fHidden;
@synthesize m_particleSystem;
@synthesize labelVisible;
@synthesize m_strSubObjectTag;
@synthesize m_fAliasTexture;
@synthesize m_fUseCulling;
@synthesize m_fIgnoreParentColor;

static float sgflWindowWidth = 320.0f;
static float sgflWindowHeight = 480.0f;

#pragma mark -
#pragma mark Static Functions

+ (void)setWindowWidth:(float)flWidth andHeight:(float)flHeight
{
    sgflWindowWidth = flWidth;
    sgflWindowHeight = flHeight;
}

+ (MRSpriteFrame *)getSpriteFrameFromName:(NSString*)strName
{
    // Are we a valid definition? If so, use that.
    MRDefinitions *dMan = [MRDefinitions sharedDefsManager];
    NSDictionary *dictDef = [dMan getDefByName:strName];
    if (dictDef != nil)
        return [MRDefinitionSprite getSpriteFrameFromDefinition:dictDef];

    // Otherwise, assume we're a direct image reference.
    MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:strName];
    if (frame == nil)
    {
        NSLog(@"C2DSprite -- can't find image for %@", strName);
    }

    return frame;
}

+ (MRSpriteFrame *)getSpriteFrameFromDefinition:(NSDictionary *)dictDef
{
    // Pick a random variation.
    int nVariation = (int)random();
    return [self getSpriteFrameFromDefinition:dictDef withVariation:nVariation];
}

+ (MRSpriteFrame *)getSpriteFrameFromDefinition:(NSDictionary *)dictDef withVariation:(int)nVariation
{
	NSString *strImage;
	NSObject *obImage = [dictDef objectForKey:@"image"];

	if ([obImage isKindOfClass:[NSArray class]] == YES)
	{
		NSArray *aImage = (NSArray *)obImage;
		int numTypes = [aImage count];
		int nRandIndex = nVariation % numTypes;
		strImage = [aImage objectAtIndex:nRandIndex];
	}
	else
	{
		strImage = (NSString *)obImage;
	}

	// Check if we are just a reference to another entry
    MRSpriteFrame *frame = nil;
    NSDictionary *dictReference = [[MRDefinitions sharedDefsManager] getDefByName:strImage];
    if (dictReference != nil)
    {
        frame = [MRDefinitionSprite getSpriteFrameFromDefinition:dictReference];
    }

    // Are we still nil? Assume we're the actual image.
    if (frame == nil)
    {
        frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:strImage];
    }

    // If we still failed, and we were TRYING to find a valid strImage...
    if (frame == nil && [strImage length] > 0)
    {
		NSLog(@"Error: Invalid image file %@ ", strImage);
		for (NSString *strItem in dictDef)
		{
			NSString *strValue = [dictDef objectForKey:strItem];
			NSLog(@"  Item: %@ => %@", strItem, strValue);
		}
	}
//	NSAssert1(frame != nil, @"ERROR: invalid image file %@.", strImage);
	return frame;
}

+ (CGSize)getContentSizeFromDefinition:(NSDictionary *)dictDef
{
	MRSpriteFrame *frame = [self getSpriteFrameFromDefinition:dictDef];
	CGRect rectInPoints = frame.pointRect;
	return rectInPoints.size;
}

+ (id)createIconFromDefinition:(NSDictionary *)dictDef
{
	if (dictDef == nil)
		return nil;

	// Use icon definition instead of our own
	NSString *strIconDef = [dictDef objectForKey:@"icon definition"];
	if (strIconDef != nil)
	{
		dictDef = [[MRDefinitions sharedDefsManager] getDefByName:strIconDef];
	}

	MRSpriteFrame *frame = [self getSpriteFrameFromDefinition:dictDef];
    MRDefinitionSprite *sprNew = nil;
    if (frame == nil)
    {
        sprNew = ([[self alloc] init]);
    }
    else
    {
        sprNew = [self spriteWithFrame:frame];
    }
	sprNew.m_fIconOnly = YES;
	[sprNew initFromDefinition:dictDef];
	return sprNew;
}

+ (id)createFromClassDefinition:(NSDictionary *)dictDef
{
    Class cDefClass = [[MRDefinitions sharedDefsManager] getClassByDef:dictDef];
    Class cAlloc = self;
    // Now determine the more derived class...
    if ([cDefClass isSubclassOfClass:self])
        cAlloc = cDefClass;

    return [cAlloc createFromDefinition:dictDef];
}

+ (id)createFromClassDefName:(NSString*)strDef
{
    NSDictionary *dictDef = [[MRDefinitions sharedDefsManager] getDefByName:strDef];
    return [self createFromClassDefinition:dictDef];
}

+ (id)createFromClassDefOrFrameName:(NSString *)strDefOrName
{
    if(!strDefOrName.length)return nil;
	MRDefinitionSprite *sprNew = nil;
	NSDictionary *dictDef = [[MRDefinitions sharedDefsManager] getDefByName:strDefOrName];
	if (dictDef != nil)
	{
		sprNew = [MRDefinitionSprite createFromClassDefinition:dictDef];
	}
	else
	{
		sprNew = [MRDefinitionSprite spriteWithFrameName:strDefOrName];
	}
	return sprNew;
}


+ (id)createFromDefinition:(NSDictionary *)dictDef
{
	MRSpriteFrame *frame = [self getSpriteFrameFromDefinition:dictDef];
    MRDefinitionSprite *sprNew = nil;
    if (frame == nil)
    {
        sprNew = ([[self alloc] init]);
    }
    else
    {
        sprNew = [self spriteWithFrame:frame];
    }
	sprNew.m_fIconOnly = NO;
	[sprNew initFromDefinition:dictDef];
	return sprNew;
}

+ (id)createFromDefName:(NSString*)strDef
{
    NSDictionary *dictDef = [[MRDefinitions sharedDefsManager] getDefByName:strDef];
    return [self createFromDefinition:dictDef];
}

+ (id)createFromDefOrFrameName:(NSString *)strDefOrName
{
    if(!strDefOrName.length)return nil;
	MRDefinitionSprite *sprNew = nil;
	NSDictionary *dictDef = [[MRDefinitions sharedDefsManager] getDefByName:strDefOrName];
	if (dictDef != nil)
	{
		sprNew = [MRDefinitionSprite createFromDefinition:dictDef];
	}
	else
	{
		sprNew = [MRDefinitionSprite spriteWithFrameName:strDefOrName];
	}
	return sprNew;
}

 + (id)createOutlineFromSprite:(MRSprite *)source {
    if (![source isKindOfClass:[MRDefinitionSprite class]]) return nil;
    MRSprite *outline = [self createOutlineFromDef:((MRDefinitionSprite *)source).m_dictDef];
    outline.flipX = source.flipX;
    return outline;
}
 + (id)createOutlineFromDef:(NSDictionary *)definition {
    MRDefinitionSprite *source=[self createFromDefinition:definition];
    if(!source)return nil;
    // Definition outlines are attached in the selected sprite's local canvas.
    // Normalize only the private assembly; the live selected graph is untouched.
    source.flipX=NO;source.scale=1;source.rotation=0;source.anchorPoint=CGPointZero;source.position=CGPointZero;
    NSMutableArray *pending=[NSMutableArray arrayWithObject:source];
    while(pending.count){MRNode *node=pending.lastObject;[pending removeLastObject];if([node isKindOfClass:[MRDefinitionSprite class]])[(MRDefinitionSprite *)node useCulling:NO];[pending addObjectsFromArray:node.children];}
    CGRect local=[source recursiveBoundingBox];CGPoint center=CGPointMake(CGRectGetMidX(local),CGRectGetMidY(local));
    return MRCreateNodeOutline(source,[MRSceneRuntime sharedRuntime].context,center,
        [[MRSceneHost option:@"outlineDensity" fallback:@"1"] doubleValue],
        [[MRSceneHost option:@"outlineThickness" fallback:@"1"] doubleValue]);
}

#pragma mark -
#pragma mark Initialization

- (id)init
{
	m_colorDefault = MRRGB(255.0f, 255.0f, 255.0f);
	self = [super initWithFrame:nil];
    m_colorBase=MRRGB(255,255,255);
	if (self != nil)
	{
		[self setHitTestOverrideSize:CGSizeMake(0, 0)];
        m_flScaleDefault = 1.0f;
        tagString = nil;
		m_aAttachments = nil;
		m_aDecals = nil;
		m_strDefinition = nil;
		m_aAnimationFrames = nil;
		m_fHidden = NO;
		m_fColorChidren = NO;
		m_label = nil;
		m_colorText = MRRGB(255.0f, 255.0f, 255.0f);
		m_particleSystem = nil;
        m_fAliasTexture = NO;
        m_fUseCulling = NO;
		m_fIgnoreParentColor = NO;
        m_dictColorTints = nil;
	}
	return self;
}

- (id) initWithFrame:(MRSpriteFrame*)spriteFrame
{
	if (spriteFrame == nil)
	{
		NSLog(@"ERROR -- C2D Sprite trying to init with invalid frame.");
		return nil;
	}
	if ((self=[self init])) self.frame=spriteFrame;
    return self;
}

// Almost all forms of definitions will want these,
// including in-line decals
- (void)localInitBasicsFromDefinition:(NSDictionary *)dictDef
{
    MRDefinitions *dMan = [MRDefinitions sharedDefsManager];
    int nOpacity = [dMan getIntFromDef:dictDef forKey:@"opacity" withDefault:255];
    // The base object may have a forced opacity
    if (nOpacity == 0)
    {
        //NSLog(@"Opacity of 0, so hiding.");
        self.m_fHidden = YES;
    }
    [self setOpacity:nOpacity];

	NSString *strAnchor		= [dictDef objectForKey:@"anchor"];
	if (strAnchor != nil)
	{
		CGPoint ptAnchor = CGPointFromString(strAnchor);
		float flAnchorX = ptAnchor.x;
		float flAnchorY = ptAnchor.y;
		[self setAnchorPoint:MRPoint(flAnchorX, flAnchorY)];
	}

	// The base object may have predefined rotation.
    float flRotation = [dMan getFloatFromDef:dictDef forKey:MR_ENTRY_SPRITE_ROTATION withDefault:0.0f];
	if (fabs(flRotation) > FLT_EPSILON)
	{
		[self setRotation:flRotation];
	}

	NSString *strColor = [dictDef objectForKey:@"color"];
	if (strColor != nil)
	{
		MRColor3B colorStart = [MRUtilities getColor:strColor];
		[self setDefaultColor:colorStart];
	}

	float flScale = [dMan getFloatFromDef:dictDef forKey:@"scale" withDefault:self.scale];
#if MR_IPHONE
	float flPhoneScale = [[dictDef objectForKey:@"phone scale"] floatValue];
	if (flPhoneScale > FLT_EPSILON)
		flScale = flPhoneScale;
#endif
	if (flScale > FLT_EPSILON)
		[self setScale:flScale];

    // Also store this as our default scale.
    [self setDefaultScale:flScale];

    // We either force or allow mirroring of X.
	BOOL fFlipX = [[dictDef objectForKey:@"flip x"] boolValue];
    if (fFlipX == NO)
    {
        if ([[dictDef objectForKey:@"can flip x"] boolValue] == YES &&
            (random() % 2) == 0)
            fFlipX = YES;
    }
	if (fFlipX == YES)
	{
		//		[self setScaleX:(self.scaleX * -1)];
        [self setFlipX:YES];
	}

	// Test .. create a particle effect if desired.
	NSString *strParticle = [dictDef objectForKey:@"particle"];
	BOOL fParticleOnly = [[dictDef objectForKey:@"particle only"] boolValue];
	if (strParticle != nil && [strParticle length] > 0)
	{

		NSString *strAnchor = [dictDef objectForKey:@"particle anchor"];
		CGPoint ptParticleAnchor = MRPoint(0.5f, 0.0f);
		if (strAnchor != nil)
			ptParticleAnchor = CGPointFromString(strAnchor);
		float flZOffset = [[dictDef objectForKey:@"particle z offset"] floatValue];
		float flRotation = [[dictDef objectForKey:@"particle rotation"] floatValue];
        BOOL fStickToWorld = [[dictDef objectForKey:@"particle sticks to world"] boolValue];
		m_flParticleRotation = flRotation;

		m_particleSystem = [MRParticles particleWithFile:strParticle];
		[self addChild:m_particleSystem z:flZOffset];
		CGSize size = [self contentSize];
		[m_particleSystem setPosition:MRPoint(size.width * ptParticleAnchor.x, size.height * ptParticleAnchor.y)];
		[m_particleSystem setRotation:flRotation];

		//		ccColor3B colorParticle = self.color;
		//		[m_particleSystem setEndColor:ccc4FFromccc3B(colorParticle)];

		// Turn off other visual for now.
		if (fParticleOnly == YES)
			[self setOpacity:0];
        if (fStickToWorld == NO)
            m_particleSystem.positionType = MRParticlePositionGrouped;
	}

}

// This part *only* does visual stuff, not other inherited things.
- (void)initVisualsFromDefinition:(NSDictionary *)dictDef
{
	NSDictionary *dictAttachment = [dictDef objectForKey:@"attachment"];
	if (dictAttachment != nil)
	{
		[self createAttachment:dictAttachment];
		[self schedule:@selector(intervalAnimateAttachments:) interval:0.3f];
	}

	NSDictionary *dictDecal = [dictDef objectForKey:@"decal"];
	if (dictDecal != nil)
	{
		[self createDecal:dictDecal];
		[self schedule:@selector(intervalAnimateDecals:) interval:0.3];
	}

    id idIgnore = [dictDef objectForKey:@"ignore parent color"];
    if (idIgnore != nil)
    {
        [self setIgnoreParentColor:[idIgnore boolValue]];
    }

	id idColor = [dictDef objectForKey:@"color children"];
	if (idColor != nil)
	{
		BOOL fColorChildren = [idColor boolValue];
		[self setColorChildren:fColorChildren];
	}

	[self localInitBasicsFromDefinition:dictDef];

	// Color our children by their "tag" field. Useful when we are using reference definitions
	NSDictionary *dictColorTags = [dictDef objectForKey:@"Color Tags"];
	if (dictColorTags != nil)
	{
		NSMutableArray *aDecalsAndAttachments = [NSMutableArray arrayWithArray:m_aDecals];
		[aDecalsAndAttachments addObjectsFromArray:m_aAttachments];
        // Set ourselves as well, if we are tagged.
        NSString *strTagUs = [dictDef objectForKey:@"tag"];
        if ([strTagUs length] > 0)
        {
            m_strSubObjectTag = strTagUs;
            [aDecalsAndAttachments addObject:self];
        }
		for (MRDefinitionSprite *sprChild in aDecalsAndAttachments)
		{
			NSString *strColor = [dictColorTags objectForKey:sprChild.m_strSubObjectTag];
			if (strColor != nil)
			{
				MRColor3B color = [MRUtilities getColor:strColor];
				[sprChild setColor:color];
			}
		}
	}

	// Load our optional animation
	NSArray *aAnimation = [dictDef objectForKey:@"animation"];
	if (aAnimation != nil)
	{
		m_aAnimationFrames = [[NSMutableArray alloc] initWithCapacity:[aAnimation count]];
		for (NSString *strFrame in aAnimation)
		{
            MRSpriteFrame *frame = [MRDefinitionSprite getSpriteFrameFromName:strFrame];
			//CCSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:strFrame];
			[m_aAnimationFrames addObject:frame];
		}
	}

	[self helperParseMotion:dictDef];
}

- (void)initFromDefinition:(NSDictionary *)dictDef
{
	NSString *strImage = [dictDef objectForKey:@"image"];
	NSDictionary *dictReferencedDef = [[MRDefinitions sharedDefsManager] getDefByName:strImage];
	if (dictReferencedDef != nil)
	{
		[self initVisualsFromDefinition:dictReferencedDef];
	}

    // Do our visuals.
    [self initVisualsFromDefinition:dictDef];

    // Any generic paramaters we might have.
    NSDictionary *dictParams = [dictDef objectForKey:@"Parameters"];
    if (dictParams != nil)
        [self addParamValuesFromDict:dictParams];

    // Store our definition and reference name.
	m_dictDef = dictDef;
	m_dictDisplayDef = dictDef;
//    m_strDefinition = [dictDef objectForKey:@"typeName"];
}

// Partially transform a sprite object using a new definition
// Haven't parsed parameters that didn't seem useful yet.
// More might be added later.
- (void)setDisplayDefinition:(NSDictionary *)dictNew
{
    BOOL fFlipX = [self flipX];

	MRSpriteFrame *frame = [MRDefinitionSprite getSpriteFrameFromDefinition:dictNew];
	if (frame != nil)
	{
		[self setFrame:frame];
	}

	// Are we referencing a another definition?
	NSString *strImage = [dictNew objectForKey:@"image"];
	NSDictionary *dictReferenceImage = [[MRDefinitions sharedDefsManager] getDefByName:strImage];

	if (dictReferenceImage == nil)
		dictReferenceImage = dictNew;

//	if (dictReferenceImage != nil)
	{
        // If we have new decals, change to them.
		NSDictionary *dictDecal = [dictReferenceImage objectForKey:@"decal"];

        // If we have no new image OR decals, don't both changing image or decals
        if (frame != nil || dictDecal != nil)
        {
            // Remove old decals.  We may actually want a new image without them, so we need to always remove them.
            for (MRDefinitionSprite *sprDecal in m_aDecals)
            {
                [sprDecal removeFromParentAndCleanup:YES];
            }
            [m_aDecals removeAllObjects];

            if ([dictDecal count] > 0)
            {
                [self createDecal:dictDecal];
            }

            [self localInitBasicsFromDefinition:dictReferenceImage];

            // Recolor us as needed, or restore us to white
            NSString *strColor = [dictNew objectForKey:@"color"];
            if (strColor == nil)
                strColor = [dictReferenceImage objectForKey:@"color"];
            if (strColor == nil)
                strColor = [m_dictDef objectForKey:@"color"];
            MRColor3B color = MRRGB(255, 255, 255);
            if (strColor != nil)
            {
                color = [MRUtilities getColor:strColor];
            }
            [self setColor: color];
        }

		NSDictionary *dictColorTags = [dictNew objectForKey:@"Color Tags"];
        // If we DON'T override, use the original colors.
        if (dictColorTags == nil)
            dictColorTags = [dictReferenceImage objectForKey:@"Color Tags"];
        if (dictColorTags == nil)
            dictColorTags = [m_dictDef objectForKey:@"Color Tags"];
		if (dictColorTags != nil)
		{
			NSMutableArray *aDecalsAndAttachments = [NSMutableArray arrayWithArray:m_aDecals];
			[aDecalsAndAttachments addObjectsFromArray:m_aAttachments];
            // Set ourselves as well, if we are tagged.
            NSString *strTagUs = [m_dictDef objectForKey:@"tag"];
            if ([strTagUs length] > 0)
            {
                m_strSubObjectTag = strTagUs;
                [aDecalsAndAttachments addObject:self];
            }
			for (MRDefinitionSprite *sprChild in aDecalsAndAttachments)
			{
				NSString *strColor = [dictColorTags objectForKey:sprChild.m_strSubObjectTag];
				if (strColor != nil)
				{
					MRColor3B color = [MRUtilities getColor:strColor];
					[sprChild setColor:color];
				}
			}
		}

	}
	m_dictDisplayDef = dictNew;

    [self setFlipX:fFlipX];
}

#pragma mark -
#pragma mark Animations

- (void)wobble:(NSDictionary *)dictDef
{
	float flMotionAmount = [[dictDef objectForKey:@"motion amount"] floatValue];
	if (flMotionAmount == 0)
		flMotionAmount = 1.0f;

	float flMotionSpeed = [[dictDef objectForKey:@"motion speed"] floatValue];
	if (flMotionSpeed == 0)
		flMotionSpeed = 1.0f;

	float flHeight	= flMotionAmount * [self contentSize].height / 2.0;
	float flWidth	= flMotionAmount * [self contentSize].width / 2.0;

	float flDelay	= (0.25f + (MRRandomUnit() / 4.0f)) / flMotionSpeed;
	float flSign	= (random() % 2) == 0 ? -1 : 1;

	// Make a circle using two opposite bezier curves.
	MRBezierConfig tBezier;
	tBezier.controlPoint_1 = MRPoint(flWidth / 2.0, 0);
	tBezier.controlPoint_2 = MRPoint(flWidth / 2.0, 0);
	tBezier.endPosition    = MRPoint(flWidth / 4.0, flSign * flHeight / 2.0);
	id actionBezierUp		= [MRBezierBy actionWithDuration:flDelay bezier:tBezier];
	tBezier.controlPoint_1 = MRPoint(-flWidth / 2.0, 0);
	tBezier.controlPoint_2 = MRPoint(-flWidth / 2.0, 0);
	tBezier.endPosition    = MRPoint(-flWidth / 4.0, flSign * -flHeight / 2.0);
	id actionBezierDown		= [MRBezierBy actionWithDuration:flDelay bezier:tBezier];

	[self runAction:[MRRepeatForever actionWithAction:[MRSequence actions:actionBezierUp, actionBezierDown, nil]]];
}

- (void)spinFast
{
	// Rotate.
	int nReverse = 1;
	if (random() % 2 == 0)
		nReverse = -1;
	float flSpeed = 1.0f + (MRRandomUnit() * 5.0f);
	id actionRotate		= [MRRotateBy actionWithDuration:flSpeed angle:(nReverse * 360.0f)];
	[self runAction:[MRRepeatForever actionWithAction:actionRotate]];
}

- (void)helperParseMotion:(NSDictionary *)dictDef
{
	NSUInteger dwMotionRock	= [@"rock" hash];
	NSUInteger dwMotionWiggle	= [@"wiggle" hash];
	NSUInteger dwMotionWobble	= [@"wobble" hash];

	NSArray *aMotions = nil;
	id idMotion = [dictDef objectForKey:@"motion"];
	if (idMotion == nil)
		return;

	if ([idMotion isKindOfClass:[NSArray class]] == YES)
		aMotions = (NSArray *)idMotion;
	else
		aMotions = [NSArray arrayWithObject:idMotion];

    MRDefinitions *dMan = [MRDefinitions sharedDefsManager];

	// Parse one or more motions
	for (NSDictionary *dictSubDef in aMotions)
	{
		NSString *strMotion = [dictSubDef objectForKey:@"motion"];
		NSUInteger dwMotion = [strMotion hash];
		if (dwMotion == dwMotionRock)
		{
            //NSLog(@"Doing Motion for %@\n\n", dictDef);
            float flMaxRotation = 22.0f;
            float flAmount = [dMan getFloatFromDef:dictSubDef forKey:@"motion amount" withDefault:1.0f];
            float flAngle = flMaxRotation * flAmount;
			[self setRotation:-flAngle];
            float flDuration = [dMan getFloatFromDef:dictSubDef forKey:@"motion duration" withDefault:1.0f];
			// Rotation.
			id actionRotate1		= [MRRotateBy actionWithDuration:(flDuration * 0.5f) angle:(flAngle * 2.0f)];
			id actionRotate2		= [MRRotateBy actionWithDuration:(flDuration * 0.5f) angle:(flAngle * -2.0f)];

			[self runAction:[MRRepeatForever actionWithAction:[MRSequence actions:actionRotate1, actionRotate2, nil]]];
		}
		else if (dwMotion == dwMotionWiggle)
		{
			[self wobble:dictDef];
			[self spinFast];
		}
		else if (dwMotion == dwMotionWobble)
		{
			[self wobble:dictDef];
		}
		else if ([self isMemberOfClass:[MRDefinitionSprite class]] == YES &&
				[[dictDef objectForKey:@"rotate"] boolValue] == YES)
		{
			// If we're only a sprite, use this spin code.
			// Derived classes (such as Body) use their own rotation code
			[self spinFast];
		}
		else
		{
            SEL selMotion = NSSelectorFromString(strMotion);
			if ([self respondsToSelector:selMotion])
				[self performSelector:selMotion];
		}
	}
}


- (void)rockAnimation
{
	float flRockFrom	= [[m_dictDef objectForKey:@"rock from"] floatValue];
	float flRockTo		= [[m_dictDef objectForKey:@"rock to"] floatValue];
	float flRockTime	= [[m_dictDef objectForKey:@"rock time"] floatValue];

	// Rotation.
	id actionRotate0		= [MRRotateBy actionWithDuration:(flRockTime) angle:flRockFrom];
	id actionRotate1		= [MRRotateBy actionWithDuration:(flRockTime) angle:-flRockFrom + flRockTo];
	id actionRotate2		= [MRRotateBy actionWithDuration:(flRockTime) angle:-flRockTo];

	[self runAction:[MRSequence actions:actionRotate0, actionRotate1, actionRotate2, nil]];
}

- (void)hopAnimation
{
	float flRockFrom	= [[m_dictDef objectForKey:@"hop height"] floatValue];
	float flRockTime	= [[m_dictDef objectForKey:@"hop time"] floatValue];

	// Rotation.
	id actionHop			= [MRMoveBy actionWithDuration:flRockTime / 2.0f position:MRPoint(0, flRockFrom)];
    //	id actionBounceUp		= [CCEaseOut actionWithAction:actionHop];
	id actionDrop			= [MRMoveBy actionWithDuration:flRockTime / 2.0f position:MRPoint(0, -flRockFrom)];
    //	id actionBounceDown		= [CCEaseIn actionWithAction:actionDrop];

	[self runAction:[MRSequence actions:actionHop, actionDrop, nil]];
}

- (void)playAnimation
{
	if (m_aAnimationFrames != nil)
	{
		float flFrameRate = 1.0f / 15.0f;
		float flPlayTime	= [[m_dictDef objectForKey:@"interval time"] floatValue];
		if (flPlayTime > 0)
			flFrameRate = flPlayTime / [m_aAnimationFrames count];
		MRAnimation *animMixed = [MRAnimation animationWithFrames:m_aAnimationFrames delay:flFrameRate];
		[self runAction:[MRAnimate actionWithAnimation:animMixed restoreOriginalFrame:YES]];
	}
}

- (void)playAnimationForever
{
	if (m_aAnimationFrames != nil)
	{
        //		if ([self numberOfRunningActions] > 0)
        //			return;

		float flFrameRate = 1.0f / 15.0f;
		float flPlayTime	= [[m_dictDef objectForKey:@"interval time"] floatValue];
		if (flPlayTime > 0)
			flFrameRate = flPlayTime / [m_aAnimationFrames count];
		MRAnimation *animMixed = [MRAnimation animationWithFrames:m_aAnimationFrames delay:flFrameRate];
		id animAnimate = [MRAnimate actionWithAnimation:animMixed restoreOriginalFrame:NO];
		[self runAction:[MRRepeatForever actionWithAction:animAnimate]];
	}
}


- (void)scream:(float)flY
{
    float flDuration = 0.8f;
    float flDelay = 1.0f;

    [self scream:flY toScale:1.0f withDuration:flDuration withDelay:flDelay];
}

- (void)scream:(float)flY toScale:(float)flScale withDuration:(float)flDuration withDelay:(float)flDelay
{
    [self setScale:0];
    [self setOpacity:0];
    id actionGrow       = [MRScaleTo actionWithDuration:flDuration scale:flScale];
    id actionFadeIn     = [MRFadeIn actionWithDuration:flDuration];
    id actionMoveTo     = [MRMoveTo actionWithDuration:flDuration position:MRPoint(MR_HALF_SCREEN_MINOR, flY)];
    id actionFirst      = [MRSpawn actions:actionGrow, actionFadeIn, actionMoveTo, nil];
    id actionDelay      = [MRDelayTime actionWithDuration:flDelay];
    id actionShrink     = [MRScaleTo actionWithDuration:flDuration scale:0.9f];
    id actionFadeOut    = [MRFadeOut actionWithDuration:flDuration];
    id actionLast       = [MRSpawn actions:actionShrink, actionFadeOut, nil];
    id animateDie       = [MRCallFunc actionWithTarget:self selector:@selector(suicide)];

    [self runAction:[MRSequence actions:actionFirst, actionDelay, actionLast, animateDie, nil]];
}

- (void)screamDiagonally:(float)flY atX:(float)flX
{
    float flSpeed = 0.5f;
    float flDelay = 1.0f;

    float flDiffX = flX - MR_HALF_SCREEN_MINOR;
    int nSign = flDiffX / fabs(flDiffX);

    [self setScale:0];
    [self setOpacity:0];
    id actionGrow       = [MRScaleTo actionWithDuration:flSpeed scale:1.0f];
    id actionFadeIn     = [MRFadeIn actionWithDuration:flSpeed];
    id actionMoveTo     = [MRMoveTo actionWithDuration:flSpeed position:MRPoint(flX, flY)];
    id actionRotate     = [MRRotateTo actionWithDuration:flSpeed angle:45*nSign];
    id actionFirst      = [MRSpawn actions:actionGrow, actionFadeIn, actionMoveTo, actionRotate, nil];

    id actionDelay      = [MRDelayTime actionWithDuration:flDelay];

    id actionShrink     = [MRScaleTo actionWithDuration:flSpeed scale:0.9f];
    id actionFadeOut    = [MRFadeOut actionWithDuration:flSpeed];
    id actionLast       = [MRSpawn actions:actionShrink, actionFadeOut, nil];

    id animateDie       = [MRCallFunc actionWithTarget:self selector:@selector(suicide)];

    [self runAction:[MRSequence actions:actionFirst, actionDelay, actionLast, animateDie, nil]];
}

- (void)animateBubbleIn
{
    // Get our current default scale.
    float flScaleEnd = self.flScaleDefault;
    [self setScale:0.1f];
    id actionGrow = [MRScaleTo actionWithDuration:0.2f scale:(1.2f * flScaleEnd)];
    id actionShrink = [MRScaleTo actionWithDuration:0.1f scale:flScaleEnd];
    [self runAction:[MRSequence actions:actionGrow, actionShrink, nil]];
}

#pragma mark -
#pragma mark Sub-objects / Decals

// For inheritance
- (void)initFromSubObjectDefinition:(NSDictionary *)dictSubObjectDef
{
    m_strSubObjectTag = [dictSubObjectDef objectForKey:@"tag"];

    // Why not parse EVERYTHING?
    [self initVisualsFromDefinition:dictSubObjectDef];
//	[self localInitBasicsFromDefinition:dictSubObjectDef];
}

- (void)addSubObject:(MRDefinitionSprite*)sprItem withOffset:(CGPoint)ptOffset withRotation:(float)flRotation withZ:(float)flZ
{
    // This version will add inside of us; derived classes can change this behavior.
	[sprItem setPosition:ptOffset];
	[sprItem setRotation:flRotation];
	[self addChild:sprItem z:flZ];
}

- (id)createSubObject:(NSDictionary *)dictDef forList:(NSMutableArray *)aList
{
	float flScaleAdjust = [MRUtilities getDeviceScaleAdjustment];
	// If we are actually an array of entries, walk the array
	if ([dictDef isKindOfClass:[NSArray class]] == YES)
	{
		NSArray *aObArray = (NSArray *)dictDef;
		NSMutableArray *aSubObs = [NSMutableArray arrayWithCapacity:[aObArray count]];
		for (dictDef in aObArray)
		{
            if ([dictDef isKindOfClass:[NSDictionary class]] == YES)
            {
                MRDefinitionSprite *sprSubOb = [self createSubObject:dictDef forList:aList];
                [aSubObs addObject:sprSubOb];
            }
            else
            {
                NSLog(@"Ignoring non-dictionary.");
            }
		}
		return aSubObs;
	}

    if ([dictDef isKindOfClass:[NSDictionary class]] == NO)
    {
        NSLog(@"Ignoring non-dictionary for createSubObject.");
        return nil;
    }

	NSString *strPosition = [dictDef objectForKey:@"position"];
	CGPoint ptPosition = CGPointFromString(strPosition);
	float flPosX = ptPosition.x * flScaleAdjust;
	float flPosY = ptPosition.y * flScaleAdjust;
	float flZOffset = [[dictDef objectForKey:@"z offset"] floatValue];
	float flRotation = [[dictDef objectForKey:@"rotation"] floatValue];

	// We might have a delta rotation, which can adjust us up or down.
	float flRotationRange = [[dictDef objectForKey:@"rotation range"] floatValue];
	if (flRotationRange > FLT_EPSILON)
	{
		float flAdjust = MRRandomUnit() * flRotationRange;
		if (random() % 2 == 0)
			flRotation += flAdjust;
		else
			flRotation -= flAdjust;
	}

	NSString *strType = [dictDef objectForKey:@"type"];
	NSString *strImage = [dictDef objectForKey:@"image"];
	MRDefinitionSprite *sprSubOb = nil;

	// If we have a type, it's our def name.
	// If we don't, image might be a def name (new standard)
	NSString *strSubObDef = strType;
	if (strType == nil)
	{
		strSubObDef = strImage;
	}

	// Look up our def
    // If our passed in def exists in the defs manager, use it.
    // Else, use our referenced def.
    NSDictionary *dictSubObDef;
    if ([[MRDefinitions sharedDefsManager] getClassByDef:dictDef] != nil)
        dictSubObDef = dictDef;
    else
        dictSubObDef = [[MRDefinitions sharedDefsManager] getDefByName:strSubObDef];

	// If we have a def, create our object using that and supply an anchor
	if (dictSubObDef != nil)
	{
		if (dictSubObDef == nil)
		{
			NSLog(@"Error: cannot find definition for attachment with type <%@>.", strSubObDef);
		}

		Class cAlloc = [[MRDefinitions sharedDefsManager] getClassByDef:dictSubObDef];

		// Override class
		if (self.m_fIconOnly == YES)
		{
			cAlloc = [MRDefinitionSprite class];
			sprSubOb = [cAlloc createIconFromDefinition:dictSubObDef];
		}
		else
		{
			sprSubOb = [cAlloc createFromDefinition:dictSubObDef];
		}

		NSString *strAnchor		= [dictSubObDef objectForKey:@"anchor"];
		if (strAnchor != nil)
		{
			CGPoint ptAnchor = CGPointFromString(strAnchor);
			float flAnchorX = ptAnchor.x;
			float flAnchorY = ptAnchor.y;
			[sprSubOb setAnchorPoint:MRPoint(flAnchorX, flAnchorY)];
		}
	}
	else if ([strImage length] > 0)
	{
		// We have no def.  Create a sprite without a definition.
		sprSubOb = [MRDefinitionSprite spriteWithFrameName:strImage];
        [sprSubOb setDefinition:dictDef];
	}

	if (sprSubOb == nil)
		return nil;

	NSString *strColor = [dictDef objectForKey:@"color"];
	if (strColor != nil)
	{
		MRColor3B color = [MRUtilities getColor:strColor];
		[sprSubOb setColor:color];
	}

    [sprSubOb initFromSubObjectDefinition:dictDef];

    [self addSubObject:sprSubOb withOffset:MRPoint(flPosX, flPosY) withRotation:flRotation withZ:flZOffset];

//	[sprSubOb helperParseMotion:dictDef];

	if (aList != nil)
		[aList addObject:sprSubOb];

	// Store our definition if we have one
	[sprSubOb setDefinitionString:strType];
	return sprSubOb;
}

- (id)createAttachment:(NSDictionary *) dictAttachment
{
	if (m_aAttachments == nil)
		m_aAttachments = [[NSMutableArray alloc] initWithCapacity:1];

	return [self createSubObject:dictAttachment forList:m_aAttachments];
}

- (id)createDecal:(NSDictionary *) dictDecal
{
	if (m_aDecals == nil)
		m_aDecals = [[NSMutableArray alloc] initWithCapacity:1];

	return [self createSubObject:dictDecal forList:m_aDecals];
}

- (NSArray *)findAllDecalsByTag:(NSString *)strTag
{
	NSMutableArray *aTagged = [NSMutableArray arrayWithCapacity:5];
	for (MRDefinitionSprite *sprDecal in self.m_aDecals)
	{
		if ([sprDecal.m_strSubObjectTag isEqualToString:strTag] == YES)
		{
			[aTagged addObject:sprDecal];
		}
	}
	return aTagged;
}

- (void)addAttachment:(id)bodyAttachment
{
	if (m_aAttachments == nil)
		m_aAttachments = [[NSMutableArray alloc] initWithCapacity:1];

	// Attachments must at least be a body
	[m_aAttachments addObject:bodyAttachment];
	[self addChild:bodyAttachment];
}

- (void)removeAttachment:(id)idAttachment
{
	[m_aAttachments removeObject:idAttachment];
}

- (void)removeDecal:(id)idDecal
{
	[m_aDecals removeObject:idDecal];
}

- (id)getAttachmentParent
{
	MRDefinitionSprite *sprParent = (MRDefinitionSprite *)self.parent;
	if ([sprParent isKindOfClass:[MRDefinitionSprite class]] == YES)
		return sprParent;
	return nil;
}

- (void)removeAttachmentFromParent
{
	MRDefinitionSprite *sprParent = (MRDefinitionSprite *)self.parent;
	if ([sprParent isKindOfClass:[MRDefinitionSprite class]] == YES)
		[sprParent removeAttachment:self];
//	[sprParent removeChild:self cleanup:NO];
}

- (void)intervalAnimateAttachments:(MRTime)deltaTime
{
	unsigned int nPlay = [@"play" hash];
	unsigned int nRock = [@"rock" hash];
	unsigned int nHop  = [@"hop" hash];

	for (MRDefinitionSprite *sprAttach in self.m_aAttachments)
	{
		// Don't animate if we already are running some action
		if ([sprAttach numberOfRunningActions] > 0)
			continue;

		id idFrequency = [sprAttach.m_dictDef objectForKey:@"interval frequency"];
		if (idFrequency == nil)
			continue;

		int nFrequency = [idFrequency intValue];

		if (nFrequency > 0 && random() % nFrequency == 0)
		{
			unsigned int nIntAnimate = [[sprAttach.m_dictDef objectForKey:@"interval motion"] hash];
			if (nIntAnimate == nPlay)
				[sprAttach playAnimation];
			else if (nIntAnimate == nRock)
				[sprAttach rockAnimation];
			else if (nIntAnimate == nHop)
				[sprAttach hopAnimation];
		}
	}
}

- (void)intervalAnimateDecals:(MRTime)deltaTime
{
	unsigned int nPlay = [@"play" hash];
	unsigned int nPlayForever = [@"play forever" hash];
	unsigned int nRock = [@"rock" hash];
	unsigned int nHop  = [@"hop" hash];

    int nOngoingCount = 0;
	for (MRDefinitionSprite *sprDecal in self.m_aDecals)
	{
		// Don't animate if we already are running some action
		if ([sprDecal numberOfRunningActions] > 0)
			continue;

        if ([self respondsToSelector:@selector(intervalAnimateDecal:)] == YES)
        {
            int nCount = [[self performSelector:@selector(intervalAnimateDecal:) withObject:sprDecal] intValue];
            nOngoingCount += nCount;
        }

		id idFrequency = [sprDecal.m_dictDef objectForKey:@"interval frequency"];
		if (idFrequency == nil)
			continue;

		int nFrequency = [idFrequency intValue];

		if ((nFrequency > 0 && random() % nFrequency == 0))
		{
			unsigned int nIntAnimate = [[sprDecal.m_dictDef objectForKey:@"interval motion"] hash];
			if (nIntAnimate == nPlay)
				[sprDecal playAnimation];
			else if (nIntAnimate == nRock)
				[sprDecal rockAnimation];
			else if (nIntAnimate == nHop)
				[sprDecal hopAnimation];
            nOngoingCount++;
		}
		else
		{
			unsigned int nIntAnimate = [[sprDecal.m_dictDef objectForKey:@"interval motion"] hash];
			if (nIntAnimate == nPlayForever)
				[sprDecal playAnimationForever];
		}

	}
    if (nOngoingCount < 1)
        [self unschedule:@selector(intervalAnimateDecals:)];
}

#pragma mark -
#pragma mark Accessors

- (NSString*)getTypeName
{
    return [m_dictDef objectForKey:@"typeName"];
}

- (void)setDefinitionString:(NSString*)strDefinition
{
	if (m_strDefinition != nil)
	{
		(void)0;
		m_strDefinition = nil;
	}

	if (strDefinition == nil)
		return;

	// copy across the new message.
	//NSLog(@"---Set %@ to %@", self, strDefinition);
	m_strDefinition = ([NSString stringWithString:strDefinition]);

}

- (void)setDefinition:(NSDictionary*)dictDef
{
    m_dictDef = dictDef;
	m_dictDisplayDef = dictDef;
}

- (void)setDefaultScale:(float)flScale
{
    if (flScale > FLT_EPSILON)
        m_flScaleDefault = flScale;
}


- (void)setTagText:(NSString*)strTag
{
	if (tagString != nil)
	{
		(void)0;
		tagString = nil;
	}

	if (strTag == nil)
		return;

	// copy across the new message.
	//NSLog(@"---Set %@ to %@", self, strDefinition);
	tagString = ([NSString stringWithString:strTag]);
}


- (CGPoint)getCenter
{
	CGSize size = self.contentSize;
	CGPoint pAnchor = self.anchorPoint;
	CGPoint pCenter = MRPoint(size.width * pAnchor.x, size.height * pAnchor.y);
	return pCenter;
}

- (CGPoint)getWorldPosition
{
	return [self convertAnchorRelativePointToWorld:MRPoint(0,0)];
}

- (float)getWorldRotation
{
	float rotation = self.rotation;

	for (MRNode *p = self.parent; p != nil; p = p.parent)
	{
		rotation += p.rotation;
		if (rotation >= 180.0f)
			rotation -= 360.0f;
		else if (rotation <= -180.0f)
			rotation += 360.0f;
	}

	return rotation;
}

- (float)getWorldScale
{
	float flScale = self.scale;
	for (MRNode *p = self.parent; p != nil; p = p.parent)
	{
		flScale *= p.scale;
	}
	return flScale;
}

- (MRSpriteFrame *)getSpriteFrame
{
	MRTexture *texture = [self texture];
	CGRect rect = self.textureRect;
	MRSpriteFrame *frame = self.frame;
	return frame;
}

-(CGFloat) scale
{
	if (self.scaleX == self.scaleY)
		return self.scaleX;

	float flScaleApprox = sqrt(fabs(self.scaleX) * fabs(self.scaleY));
	return flScaleApprox;
}

-(void) setOpacity:(uint8_t) anOpacity
{
	if (m_fHidden == NO)
		[super setOpacity:anOpacity];
	else
		[super setOpacity:0];
	if (m_fColorChidren == YES)
	{
		for (MRDefinitionSprite *sprChild in self.children)
		{
			if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == YES)
				[sprChild setOpacity:anOpacity];
			else if ([sprChild isKindOfClass:[MRParticles class]] == YES)
			{
				MRParticles *particleSystem = (MRParticles *)sprChild;
				if (anOpacity < 50)
					particleSystem.visible = NO;
				else
					particleSystem.visible = YES;
			}
		}
	}
}


- (void)setFlipX:(BOOL)flipX
{
//    NSLog(@"Flip X of %d.", flipX);
    [super setFlipX:flipX];

    // Do this for children as well.
    for (MRSprite *sprChild in self.children)
    {
        if ([sprChild isKindOfClass:[MRSprite class]] == YES)
        {
            if (flipX != [sprChild flipX])
            {
                // Our decals are not anchor relative, so instead of flipping the X sign,
                // we need to position from the right edge instead of the left.
                //                [sprChild setPosition:ccp(-sprChild.position.x, sprChild.position.y)];
//                NSLog(@" Child flip: Width is %.0f, were at %.0f, so our new X is %.0f", self.contentSize.width, sprChild.position.x, self.contentSize.width - sprChild.position.x);
                [sprChild setPosition:MRPoint(self.contentSize.width - sprChild.position.x, sprChild.position.y)];
            }
            [sprChild setFlipX:flipX];
        }
    }
}

- (void)setFlipY:(BOOL)flipY
{
    [super setFlipY:flipY];

    // Do this for children as well.
    for (MRSprite *sprChild in self.children)
    {
        if ([sprChild isKindOfClass:[MRSprite class]] == YES)
        {
            if (flipY != [sprChild flipY])
                [sprChild setPosition:MRPoint(sprChild.position.x, -sprChild.position.y)];
            [sprChild setFlipY:flipY];
        }
    }
}

#pragma mark -
#pragma mark Parameters.
// Parameter stuff
- (void)addParamValue:(id)idValue forKey:(NSString*)strKey
{
    if (idValue == nil)
        return;

    if (m_dictParams == nil)
    {
        m_dictParams = [[NSMutableDictionary alloc] initWithCapacity:2];
    }
    [m_dictParams setObject:idValue forKey:strKey];
}

- (void)addParamValuesFromDict:(NSDictionary*)dictValues
{
    for (NSString *strKey in dictValues)
    {
        id idValue = [dictValues objectForKey:strKey];
        [self addParamValue:idValue forKey:strKey];
    }
}

- (id)getParamValueForKey:(NSString*)strKey
{
    return [m_dictParams objectForKey:strKey];
}

#pragma mark -
#pragma mark Sorting.
// Sorting functions.

// Compare based on a generic "value" parameter.
- (NSComparisonResult)compareValue:(MRDefinitionSprite*)spriteOther
{
    int nCostUs = [[self getParamValueForKey:@"value"] intValue];
    int nCostOther = [[spriteOther getParamValueForKey:@"value"] intValue];

    if (nCostUs < nCostOther)
        return NSOrderedAscending;
    else if (nCostUs > nCostOther)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

// custom cleanup

#pragma mark -
#pragma mark Text

- (MRTextLabel*)setText:(NSString *)strText
{
    // Where should our text be centered over? Just our center, I guess.
    CGSize sizeUs = self.contentSize;
//    CGRect rectUs = [self recursiveBoundingBox];
//    CGSize sizeUs = rectUs.size;
    CGPoint ptAnchor = MRPoint(0.5f, 0.5f); //[self getAdjustedAnchorForAnchor:ccp(0.5f, 0.5f)];
    CGPoint ptMiddle = MRPoint(sizeUs.width * ptAnchor.x, sizeUs.height * ptAnchor.y);
    MRTextLabel *textNew = [self setText:strText atPosition:ptMiddle];
    return textNew;
}

- (MRTextLabel*)setText:(NSString *)strText atPosition:(CGPoint)Position
{
	return [self setText:strText atPosition:Position withAlignment:UITextAlignmentLeft];
}

- (MRTextLabel*)setText:(NSString *)strText atPosition:(CGPoint)Position withAlignment:(UITextAlignment)alignment
{
	if (m_label)
		[self removeChild:m_label cleanup:YES];
    float flScaleAdjust = [MRUtilities getDeviceScaleAdjustment];
    float flFontSize = MR_DEFAULT_FONT_SIZE + 1.0f;
//    float flHeight = self.contentSize.height;
    CGSize sizeText = [self recursiveBoundingBox].size; //self.contentSize;
    CGSize sizeOriginal = sizeText;
    NSString *strFont = [[MRUtilities sharedUtilityManager] getDefaultFont];

	float flScale = 1.1f;

    while (flScale > 0.25f && (m_label == nil || ((sizeText.height > sizeOriginal.height * 0.9f || sizeText.width > sizeOriginal.width * 0.9f) && flFontSize > 4.0f)))
    {
//        flFontSize -= 1.0f;

		flScale = flScale / 1.1f;
        m_label = [MRTextLabel textWithParagraph:strText fontName:strFont fontSize:(flFontSize * flScaleAdjust) maxWidth:(sizeOriginal.width * 0.95f) centered:YES];
        sizeText = [m_label contentSize];
//		[m_label setScaleX:m_label.scaleX * flScale];
		sizeText.width *= flScale;
        flFontSize *= flScale;
    }
//	m_label = [[C2DText alloc] initWithWord:strText fontName:strFont fontSize:MR_DEFAULT_FONT_SIZE * flScaleAdjust];
//	[m_label setColor:m_colorText];
//    CGPoint ptAnchor = [self getAdjustedAnchorForAnchor:ccp(0.5f, 0.5f)];
//	[m_label setAnchorPoint:ptAnchor];
    [m_label setAnchorPoint:MRPoint(0.5f, 0.5f)];
	[m_label setPosition:Position]; //ccp(16, -24)];
	[self addChild:m_label];

	return m_label;
}

- (void)setTextColor:(MRColor3B)color
{
	// This changes the color for FUTURE text calls,
	// not text that already exists in the button.
	m_colorText = color;
}

- (void)setLabelVisible:(BOOL)fVisible
{
	labelVisible = fVisible;
	if (labelVisible == YES)
	{
		[m_label setOpacity:255];
	}
	else
	{
		[m_label setOpacity:0];
	}
}

#pragma mark -
#pragma mark Colors

// Only do this if we really want it to happen everywhere. :)
-(void)setColor:(MRColor3B)color
{
    m_colorBase = color;
	// First set our children, if desired.
	if (m_fColorChidren == YES)
	{
		for (MRDefinitionSprite *sprChild in self.children)
		{
			if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == YES &&
				sprChild.m_fIgnoreParentColor == NO)
			{
				[sprChild setColor:color];
			}
		}
	}

    MRColor3B colorFinal = [self localApplyColorTints];
	[super setColor:colorFinal];
}

- (void)setDefaultColor:(MRColor3B)color
{
	// First set our children, if desired.
	if (m_fColorChidren == YES)
	{
		for (MRDefinitionSprite *sprChild in self.children)
		{
			if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == YES &&
				sprChild.m_fIgnoreParentColor == NO)
            {
				[sprChild setDefaultColor:color];
            }
		}
	}

	m_colorDefault = color;
	[self setColor:color];
}

- (void)restoreToDefaultColor
{
	// First set our children, if desired.
	if (m_fColorChidren == YES)
	{
		for (MRDefinitionSprite *sprChild in self.children)
		{
			if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == YES &&
				sprChild.m_fIgnoreParentColor == NO)
            {
			 	[sprChild setColor:m_colorDefault];
            }
		}
	}

	[self setColor:m_colorDefault];

}

- (void)setColorTint:(MRColor3B)colorTint forTag:(NSString *)strTag
{
    if (m_dictColorTints == nil)
        m_dictColorTints = ([NSMutableDictionary dictionaryWithCapacity:1]);

    MRColorValue *colorOb = [MRColorValue colorWithColor3B:colorTint];
    [m_dictColorTints setObject:colorOb forKey:strTag];

    MRColor3B colorFinal = [self localApplyColorTints];
    for (MRDefinitionSprite *sprChild in self.children)
    {
        if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == YES)
        {
            [sprChild setColorTint:colorTint forTag:strTag];
        }
    }

    [super setColor:colorFinal];

}

- (void)removeColorTintForTag:(NSString *)strTag
{
    [m_dictColorTints removeObjectForKey:strTag];
    MRColor3B colorFinal = [self localApplyColorTints];
    for (MRDefinitionSprite *sprChild in self.children)
    {
        if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == YES)
        {
            [sprChild removeColorTintForTag:strTag];
        }
    }
    [super setColor:colorFinal];
}

- (MRColor3B)localApplyColorTints
{
    MRColor3B colorConcat = m_colorBase;
    for (NSString *strTag in m_dictColorTints)
    {
        MRColorValue *colorObTint = [m_dictColorTints objectForKey:strTag];
        MRColor3B colorTint = [colorObTint getColor3B];
        colorConcat = MRRGB(colorConcat.r * colorTint.r / 255, colorConcat.g * colorTint.g / 255, colorConcat.b * colorTint.b / 255);
    }
    return colorConcat;
}

-(void) setHitTestOverrideSize:(CGSize)size
{
	m_sizeHitTestOverride = CGSizeMake(size.width, size.height);
}

- (void)setColorChildren:(BOOL)fColorChildren
{
	m_fColorChidren = fColorChildren;
	for (MRDefinitionSprite *sprChild in self.children)
	{
		if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == YES)
			[sprChild setColorChildren:fColorChildren];
	}
}

#pragma mark -
#pragma mark ContentSize and BoundingBox

- (CGSize) transformedSize
{
    CGSize size = [self contentSize];
    size.width *= self.scaleX;
    size.height *= self.scaleY;
    return size;
}

- (CGRect) localRecursiveBoundingBox
{
	CGRect rectNew;
	rectNew.size = [self contentSize];
	rectNew.origin = MRPoint(0,0);

	for (MRDefinitionSprite *sprChild in self.children)
	{
		if ([sprChild isKindOfClass:[MRDefinitionSprite class]] == NO)
			continue;
		CGRect rectA = rectNew;
		CGRect rectB = [sprChild localRecursiveBoundingBox];

        // The transform is in pixels, so we need to convert it to points.

		rectB = CGRectApplyAffineTransform(rectB, [sprChild nodeToParentTransform]);


		rectNew = rectAddRect(rectA, rectB);
	}

	return rectNew;
}

- (CGRect)recursiveBoundingBox
{
	// Top level only transforms scale.
	CGRect rect = [self localRecursiveBoundingBox];
	CGAffineTransform transform = CGAffineTransformScale(CGAffineTransformIdentity, self.scaleX, self.scaleY);
	rect = CGRectApplyAffineTransform(rect, transform);

	return rect;
}


// Make sure we're not bigger that a given size.
- (void)constrainToSize:(CGSize)sizeMax
{
    // Make sure we're not bigger than a certain width/height.
    CGRect rectUs = [self recursiveBoundingBox];
	// RecursiveBoundingBox takes existing scale into account,
	//  so we alter our scale based on existing scale.
    float flScaleX = self.scaleX;
    float flScaleY = self.scaleY;
    if (rectUs.size.height > sizeMax.height)
    {
        flScaleY *= sizeMax.height / rectUs.size.height;
    }
    if (rectUs.size.width > sizeMax.width)
        flScaleX *= sizeMax.width / rectUs.size.width;
    if (flScaleX < flScaleY)
        [self setScale:flScaleX];
    else
        [self setScale:flScaleY];
}


// Get an adjusted anchor point when we have decals affecting our recursive bounding box.
- (CGPoint)getAdjustedAnchorForAnchor:(CGPoint)ptOriginal
{
    // Our base size:
    CGSize sizeUs = self.contentSize;
    sizeUs.width *= self.scaleX;
    sizeUs.height *= self.scaleY;

	CGRect rectRecurseive = [self recursiveBoundingBox];

    // Our recursive size:
    CGSize sizeRecursive = rectRecurseive.size;

    CGPoint ptNew = ptOriginal;

	ptNew.x = ((sizeRecursive.width * ptOriginal.x) + rectRecurseive.origin.x) / sizeUs.width;
	ptNew.y = ((sizeRecursive.height * ptOriginal.y) + rectRecurseive.origin.y) / sizeUs.height;

    return ptNew;
}


#pragma mark -
#pragma mark Particle system

- (MRParticles*)setParticleSystem:(NSString*)strParticleSystem
{
    // Remove any old particle system.
    [self removeParticleSystem];

    // Add the new particle system.
    m_particleSystem = [MRParticles particleWithFile:strParticleSystem];
    [self addChild:m_particleSystem];
    [m_particleSystem setPosition:MRPoint(self.contentSize.width * 0.5f, self.contentSize.height * 0.5f)];
    return m_particleSystem;
}

- (void)removeParticleSystem
{
    if (m_particleSystem != nil)
    {
        [m_particleSystem stopSystem];
        [self removeChild:m_particleSystem cleanup:YES];
        m_particleSystem = nil;
    }
}

- (void)removeChildParticles
{
	NSArray *arrKids = [self children];
	for (id idKid in arrKids)
	{
		if ([idKid isKindOfClass:[MRParticles class]] == YES)
		{
//			NSLog(@"Removing [%@ %x] from [%@ %x]",
//				  [idKid class], idKid,
//				  [self class], self);
			[idKid stopSystem];
			[self removeChild:idKid cleanup:YES];
		}
	}
}

#pragma mark -
#pragma mark C2DCulling Layer Compatibility

- (void)updateWorldPositionCache
{
    m_positionInWorldCached = [self getWorldPosition];
}

- (void)setPosition:(CGPoint)position
{
    [super setPosition:position];
    [self updateWorldPositionCache];
}

// Note: never directly set UseCulling.  It is set by the parent layer ONLY if the parent layer
//   supports culling!
- (void)visit:(MRRenderContext *)context
{
    [self updateWorldPositionCache];
    if (m_fUseCulling == YES)
    {
        CGPoint position = m_positionInWorldCached;

        CGSize size = [self contentSize];
        float flWidth = size.width * self.scaleX;
        float flHeight = size.height * self.scaleY;
        CGPoint ptAnchor = [self anchorPoint];
        // Off to the left.
        if (position.x < -(flWidth * (1.0f - ptAnchor.x)))
        {
            return;
        }
        // Off to the right.
        if (position.x > (sgflWindowWidth + (flWidth * ptAnchor.x)))
        {
            return;
        }

        // Off to the bottom.
        if (position.y < -(flHeight * (1.0f - ptAnchor.y)))
        {
            return;
        }

        // Off to the top.
        if (position.y > (sgflWindowHeight + (flHeight * ptAnchor.y)))
        {
            return;
        }

        // Old version assumed anchor of (0.5f, 0.0f).
//        if (position.x < -flWidth / 2 || position.x > sgflWindowWidth + flWidth / 2)
//        {
//            return;
//        }
//        if (position.y < -flHeight || position.y > sgflWindowHeight)
//        {
//            return;
//        }
    }
    [super visit:context];
}


- (BOOL)hitTest:(MRPointerEvent *)touch
{
	if ([self.parent isKindOfClass:[MRLayer class]] == YES)
	{
		MRLayer *layParent = (MRLayer *)self.parent;
		if ([layParent isTouchEnabled] == NO)
			return NO;
	}

	if (self.parent.visible == NO || self.parent.inScene == NO)
		return NO;

	CGSize szContent;
	if (m_sizeHitTestOverride.width > 0)
		szContent = m_sizeHitTestOverride;
	else
		szContent = [self contentSize];

    // Adjust for our default scale.
    szContent.width  *= [self getWorldScale];
    szContent.height *= [self getWorldScale];

	CGPoint ptOrigin = [self convertAnchorRelativePointToWorld:MRPoint(0, 0)];

	CGPoint ptAnchor = self.anchorPoint;

	ptOrigin.x -= szContent.width * ptAnchor.x;
	ptOrigin.y -= szContent.height * ptAnchor.y;

	CGRect rectBounding = CGRectMake(ptOrigin.x, ptOrigin.y, szContent.width, szContent.height);

	CGPoint Position = touch.position;

	Position = Position;

	if (m_aAttachments != nil)
	{
		for (MRDefinitionSprite *bodyAttachment in m_aAttachments)
		{
			if ([bodyAttachment hitTest:touch] == YES)
				return YES;
		}
	}

	return CGRectContainsPoint(rectBounding, Position);
}

- (void)draw:(MRRenderContext *)context {
    MRTextureSampling saved=self.sampling;
    if (m_fAliasTexture) self.sampling=(MRTextureSampling){MRFilterNearest,MRFilterNearest,MRAddressClamp,MRAddressClamp};
    [super draw:context]; self.sampling=saved;
}


#pragma mark -
#pragma mark Cleanup


-(void) cleanup
{
	if (m_aAnimationFrames != nil)
	{
		(void)0;
		m_aAnimationFrames = nil;
	}

    (void)0;
    m_dictColorTints = nil;

	[super cleanup];
}


- (void)suicide
{
	[self.parent removeChild:self cleanup:YES];
}

- (void)dealloc
{
	// Kill any particle inside us.
	[self removeChildParticles];

    (void)0;
    m_dictParams = nil;

	(void)0;
	(void)0;
	(void)0;

	(void)0;
}


@end

#endif
