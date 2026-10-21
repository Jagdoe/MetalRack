#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  UtilityManager.h
//  Zombie
//
//  Created by Stretchy Tom on 8/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRUtilities.h"
#import <MessageUI/MessageUI.h>
#import "MRSceneHost.h"
#import "MRDefinitions.h"
#import "MRCurrencyStore.h"
#ifndef PROJECT_IGNORE_POPUPMANAGER
#import "PopupManager.h"
#endif
#import "MRDefinitionSprite.h"
#import "MRValues.h"
#import "Reachability.h"
#import <SystemConfiguration/SystemConfiguration.h>

// Kinda hack.
#if (COCOS2D_VERSION == 0x00020000)
#else
//    #import "TJCUtil.h"
#endif

// Third-party ASI HTTP stuff.
#import "ASIFormDataRequest.h"

// Replacement UDID stuff.
//#import "UIDevice+IdentifierAddition.h"
#import "UIDevice+IdentifierAddition.h"
#import "NSString+MD5Addition.h"

#import "2DMath.h"
#import "MRPointValue.h"
//#import "Body.h"

// For generic network stuff.
#import <CFNetwork/CFHost.h>
#import <SystemConfiguration/SCNetwork.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#import <CommonCrypto/CommonDigest.h>

// For Game Center stuff.
#import <GameKit/GameKit.h>

#define POINTER_FADE_IN_TIME	(2.0f)
#define POINTER_FADE_OUT_TIME	(0.5f)

//#define MR_PREF_NICKNAME				@"BefuddledNickname"

static MRUtilities *sgUtilityManager = nil;

static BOOL sfInitted = NO;

// Store our number formatter; doesn't need to change per iteration.
static NSNumberFormatter *snumberFormatter = nil;

// Store our defaults stuff.
static NSUserDefaults *suserDefaults = nil;

// Stuff for keystyles.
static NSString* sstrKeyStyles[NUM_EKS_TYPES] =
{
	@"",			// EKS_NONE
	@"|Score",		// EKS_SCORE
	@"|Completed",	// EKS_COUNT
	@"|Currency",	// EKS_CURRENCY
	@"|Tech",		// EKS_TECH
};
static int snNumKeyStyles = sizeof(sstrKeyStyles) / sizeof(NSString*);

@implementation MRUtilities

@synthesize eGameplayMode = m_eGameplayMode;
@synthesize eGameplayForJumps = m_eGameplayForJumps;

@synthesize strFacebookID = m_strFacebookID;
@synthesize nickname = m_strNickname;
@synthesize arrLeaderboardNames = m_arrLeaderboardNames;
@synthesize arrLeaderboardCategories = m_arrLeaderboardCategories;
@synthesize fUseInApp = m_fUseInApp;

+ (void)prepare
{
    // Kind of like Init, but for the global class thing.
    if (suserDefaults == nil)
        suserDefaults = [NSUserDefaults standardUserDefaults];
}

+ (MRUtilities *)sharedUtilityManager
{
	if (sgUtilityManager == nil)
		sgUtilityManager = [[MRUtilities alloc] init];

	return sgUtilityManager;
}

+ (MRUtilities *)sharedUtilityManagerWithOptions:(NSDictionary*)dictOptions
{
	if (sgUtilityManager == nil)
    {
        sgUtilityManager = [MRUtilities alloc];
        [sgUtilityManager initWithOptions:dictOptions];
//		sgUtilityManager = [[UtilityManager alloc] initWithOptions:dictOptions];
    }

	return sgUtilityManager;
}

- (id)initWithOptions:(NSDictionary*)dictOptions
{
	if (sfInitted == YES)
		return self;

	NSLog(@"  UM: Beginning init.");

	self = [super init];
	NSLog(@"  UM: Done with super init.");

	if (self != nil)
	{
		m_appDelegate = [MRSceneHost sharedAppDelegate];

        if (suserDefaults == nil)
            suserDefaults = [NSUserDefaults standardUserDefaults];

		snumberFormatter = [[NSNumberFormatter alloc] init];
		[snumberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

        // No shape-group entries.
        m_dictGroupsCombined = nil;

        // Set up color access.
        [self initColors];

		NSString *strTempNickname = [MRUtilities getContentStringForKey:MR_PREF_NICKNAME];
		if (strTempNickname != nil)
			m_strNickname = [NSString stringWithString:strTempNickname];

		// Keep a copy of the font to use.
		m_strDefaultFont = ([NSString stringWithString:[self getDefaultFont]]);

		[self initNetwork];
		NSLog(@"  UM: Done with initNetwork.");

		// Game Center.
		BOOL fDoGameCenter = YES;
		id idGameCenter = [dictOptions objectForKey:OPTIONS_USE_GAME_CENTER];
		if (idGameCenter != nil)
			fDoGameCenter = [idGameCenter boolValue];
		if (fDoGameCenter == YES)
			[self GCinit];
		else
			m_fIsGCAvailable = NO;
		NSLog(@"  UM: Done with GCinit.");

		// In-App purchase.
		m_fUseInApp = YES;
		id idInApp = [dictOptions objectForKey:OPTIONS_USE_IN_APP];
		if (idInApp != nil)
			m_fUseInApp = [idInApp boolValue];
		if (m_fUseInApp == YES)
			[self initInApp];
		NSLog(@"  UM: Done with initInApp.");

        // Facebook.
        m_fUseFacebook = NO;
        id idUseFacebook = [dictOptions objectForKey:OPTIONS_USE_FACEBOOK];
        if (idUseFacebook != nil)
            m_fUseFacebook = [idUseFacebook boolValue];
        m_fRequireFacebook = NO;
        id idRequireFacebook = [dictOptions objectForKey:OPTIONS_REQUIRE_FACEBOOK];
        if (idRequireFacebook != nil)
            m_fRequireFacebook = [idRequireFacebook boolValue];
        if (m_fUseFacebook == YES || m_fRequireFacebook == YES)
        {
            [self initFacebook];
        }

        // ASI Networking.
        m_queueASI = [[NSOperationQueue alloc] init];
        [m_queueASI setMaxConcurrentOperationCount:1];

        m_idISCRequestDelegate = nil;
	}

	sfInitted = YES;
	NSLog(@"  UM: Done with all init.");
	return self;
}

- (void)setFacebookCallbackDelegate:(id)idDelegate
{
    m_idFacebookCallbackOb = idDelegate;
}

- (id)init
{
	return [self initWithOptions:nil];
}


- (void)dealloc
{
	// First our stuff:
	(void)0;
	snumberFormatter = nil;
	sfInitted = NO;
	(void)0;
    m_strDefaultFont = nil;

    (void)0;
    m_strFacebookID = nil;

    [m_queueASI cancelAllOperations];
    (void)0;
    m_queueASI = nil;

	// Now the super.
	(void)0;

}

- (void)setGameplayMode:(EGameplayMode)eMode
{
    // Tom turning this off -- zombie specific? 12/28/11
////	NSLog(@"Entering setGameplayMode (%d).", eMode);
//	m_eGameplayMode = eMode;
//	m_eGameplayForJumps = eMode;
//
//	// If we're in multi-mode, but we're the last unlocked level,
//	// behave like single-mode for jumps.
//	if (eMode == EGM_MULTI)
//	{
//		MRSceneHost *appAAD = [MRSceneHost sharedAppDelegate];
//		// Are we the last mission?
//		int nLastMissionForSet = [MRSceneHost getLastMissionForSet:appAAD.m_nMissionSet];
//		if (nLastMissionForSet == appAAD.m_nMission)
//		{
//			m_eGameplayForJumps = EGM_SINGLE;
//		}
//		else
//		{
//			// Do we have an unlocked next mission to go to?
//			// Hack -- ask this as though we weren't in multi-mode.
//			m_eGameplayMode = EGM_SINGLE;
//			int nCount = [MRSceneHost getCountForSet:appAAD.m_nMissionSet withMission:appAAD.m_nMission];
//			m_eGameplayMode = EGM_MULTI;
//			if (nCount == 0)
//			{
//				// If we haven't completed this mission, our next one is locked.
//				m_eGameplayForJumps = EGM_SINGLE;
//			}
//		}
//	}
}

#pragma mark -
#pragma mark General
+ (NSString*)getTimeForSeconds:(int)nTimeInSeconds
{
	int nHours		= nTimeInSeconds / (60 * 24);
	nTimeInSeconds	-= (nHours * 60 * 24);
	int nMinutes	= nTimeInSeconds / 60;
	nTimeInSeconds	-= (nMinutes * 60);
	int nSeconds	= nTimeInSeconds;
	NSString *strTime = [NSString stringWithFormat:@"%02dh %02dm %02ds", nHours, nMinutes, nSeconds];
	return strTime;
}

+ (NSString*)getFormattedNumber:(float)flValue
{
	NSNumber *theValue = [NSNumber numberWithFloat:flValue];
	return [snumberFormatter stringFromNumber:theValue];
}

+ (NSString *)getFormattedTime:(float)flSeconds
{
	int nHours = flSeconds / 3600;
	int nMinutes = (((int)flSeconds) % 3600) / 60;
	int nSeconds = (((int)flSeconds) % 60);
	NSString *strTime = nil;
	if (nHours > 0)
		strTime = [NSString stringWithFormat:@"%d:%02d:%02d", nHours, nMinutes, nSeconds];
	else
		strTime = [NSString stringWithFormat:@"%d:%02d", nMinutes, nSeconds];
	return strTime;
}

+ (NSString*)getTruncatedString:(NSString*)strLabel forWidth:(float)flWidth withFont:(NSString*)strFont withSize:(float)flFontSize addElipses:(BOOL)fAddDots
{
	// Note .. we're doing this a very slow, dumb way.  If we're using it a lot, it needs a rewrite.
	MRSystemText *label = [MRSystemText labelWithString:strLabel fontName:strFont fontSize:flFontSize];

	BOOL fShrunk = NO;
	while (label.contentSize.width > flWidth && [strLabel length] >= 2)
	{
		//NSLog(@"%d: [%@] has width %.0f", nCount, strLabel, labelName.contentSize.width);
		strLabel = [strLabel substringToIndex:([strLabel length] - 2)];
		// Sigh .. kill the old one and re-do.
		[label removeFromParentAndCleanup:YES];
		label = [MRSystemText labelWithString:strLabel fontName:strFont fontSize:flFontSize];
		fShrunk = YES;
	}
	// Remove any final label.
	[label removeFromParentAndCleanup:YES];

	// Now add dots if we want, and return the string.
	if (fShrunk == YES && fAddDots == YES)
		strLabel = [NSString stringWithFormat:@"%@...", strLabel];

	return strLabel;
}

+ (NSString*)getFortuneCookieQuoteForCategory:(NSString*)strCategory;
{
	static NSString *sstrQuote = nil;

	NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"fortune_cookies" ofType:@"plist"];
	NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:plistPath];

	// Do we have this category?
	NSArray *arrCategory = [dictionary objectForKey:strCategory];
	int nItems = [arrCategory count];
	if (arrCategory == nil || nItems < 1)
		return nil;

	// We're just going to return an entry at random.
	// Note: Use Option+Return for a carriage return.
	int nIndex = random() % nItems;
	sstrQuote = [NSString stringWithFormat:@"%@", [arrCategory objectAtIndex:nIndex]];

	(void)0;

	return sstrQuote;
}

+ (MRSystemText*)createTextRegion:(NSString *)strText size:(CGSize)sizeRegion fontSize:(float)flFontSize
{
	NSString *strFont = @"Helvetica-Bold";//[[UtilityManager sharedUtilityManager] getDefaultFont];
	UIFont *font = [UIFont fontWithName:strFont size:flFontSize];
	CGSize sizeText = [strText sizeWithFont:font constrainedToSize:sizeRegion lineBreakMode:UILineBreakModeWordWrap];
    int nTries = 0;
    while (sizeText.width <= 1 && nTries < 10) // If we have a long name and can't fit, shrink?
    {
        flFontSize -= 1.0f;
        UIFont *font = [UIFont fontWithName:strFont size:flFontSize];
        sizeText = [strText sizeWithFont:font constrainedToSize:sizeRegion lineBreakMode:UILineBreakModeWordWrap];
        ++nTries;
    }
    if (sizeText.width <= 1)
        sizeText = sizeRegion;

    sizeText.width += 1;
    sizeText.height += 1;


	MRSystemText *labelTextShadow = [MRSystemText labelWithString:strText dimensions:sizeText alignment:UITextAlignmentLeft
													 fontName:strFont fontSize:flFontSize];

	[labelTextShadow setColor:MRRGB(0, 0, 0)];
	[labelTextShadow setAnchorPoint:MRPoint(0.5f, 1.0f)];

	MRSystemText *labelText = [MRSystemText labelWithString:strText dimensions:sizeText alignment:UITextAlignmentLeft
											   fontName:strFont fontSize:flFontSize];

	[labelText setAnchorPoint:MRPoint(0.0f, 0.0f)];
	[labelText setPosition:MRPoint(-1, 1)];
	[labelTextShadow addChild:labelText];
	return labelTextShadow;
}

-(void)setNickname:(NSString *)strNickname
{
	// We only need to do this since we're also storing to prefs.
	// Otherwise, just using (copy) will make our string safe.
    if ([m_strNickname isEqualToString:strNickname] == NO)
	{
        (void)0;
        m_strNickname = [strNickname copy];

		// Save to prefs.
		[MRUtilities setContentStringForKey:MR_PREF_NICKNAME withString:strNickname];

		// And inform the world.
		[self sendISCPing];
    }
}

#pragma mark -
#pragma mark Preferences & Status

+ (BOOL)getContentStatusForKey:(NSString*)strKey
{
	BOOL fStatus = [suserDefaults boolForKey:strKey];
	return fStatus;
	//return YES; // HACK!
}

+ (void)setContentStatusForKey:(NSString*)strKey asActive:(BOOL)fActive
{
	[suserDefaults setBool:fActive forKey:strKey];
}

+ (BOOL)doesContentStatusExistForKey:(NSString*)strKey
{
	if ([suserDefaults objectForKey:strKey] == nil)
		return NO;
	return YES;
}

+ (int)getContentIntForKey:(NSString*)strKey
{
	int nValue = [suserDefaults integerForKey:strKey];
	return nValue;
}

+ (void)setContentIntForKey:(NSString*)strKey withInt:(int)nValue
{
	[suserDefaults setInteger:nValue forKey:strKey];
}

+ (int)adjustContentIntForKey:(NSString*)strKey withDelta:(int)nDelta
{
    int nOld = [self getContentIntForKey:strKey];
    int nNew = nOld + nDelta;
    [self setContentIntForKey:strKey withInt:nNew];
    return nNew;
}

+ (BOOL)doesContentIntExistForKey:(NSString*)strKey
{
	return [self doesContentStatusExistForKey:strKey];
}

// Float prefs.
+ (float)getContentFloatForKey:(NSString*)strKey
{
	float flValue = [suserDefaults floatForKey:strKey];
	return flValue;
}

+ (float)adjustContentFloatForKey:(NSString*)strKey withDelta:(float)flValue
{
	float flOld = [self getContentFloatForKey:strKey];
	float flNew = flOld + flValue;
	[self setContentFloatForKey:strKey withFloat:flNew];
	return flNew;
}

+ (void)setContentFloatForKey:(NSString*)strKey withFloat:(float)flValue
{
	[suserDefaults setFloat:flValue forKey:strKey];
}

+ (BOOL)doesContentFloatExistForKey:(NSString*)strKey
{
	return [self doesContentStatusExistForKey:strKey];
}

// Double prefs (rarely used).
+ (double)getContentDoubleForKey:(NSString*)strKey
{
	double dbValue = [suserDefaults doubleForKey:strKey];
	return dbValue;
}

+ (double)adjustContentDoubleForKey:(NSString*)strKey withDelta:(double)dbValue
{
	double dbOld = [self getContentDoubleForKey:strKey];
	double dbNew = dbOld + dbValue;
	[self setContentDoubleForKey:strKey withDouble:dbNew];
	return dbNew;
}

+ (void)setContentDoubleForKey:(NSString*)strKey withDouble:(double)dbValue
{
	[suserDefaults setDouble:dbValue forKey:strKey];
}

+ (BOOL)doesContentDoubleExistForKey:(NSString*)strKey
{
	return [self doesContentStatusExistForKey:strKey];
}

+ (NSString *)getContentStringForKey:(NSString*)strKey
{
	NSString *strValue = [suserDefaults stringForKey:strKey];
	return strValue;
}

+ (void)setContentStringForKey:(NSString*)strKey withString:(NSString *)strValue
{
	[suserDefaults setObject:strValue forKey:strKey];
}

+ (BOOL)doesContentExistForKey:(NSString*)strKey
{
	return [self doesContentIntExistForKey:strKey];
}

+ (NSMutableArray *)getContentArrayForKey:(NSString*)strKey
{
    // MutableArrayValue seems to be bad now. Let's just make a safe mutable copy...
    NSArray *arrSource = [suserDefaults arrayForKey:strKey];
    NSMutableArray *arrMutable = [NSMutableArray arrayWithArray:arrSource];
    return arrMutable;
//	return [suserDefaults mutableArrayValueForKey:strKey];
}

+ (void)setContentArrayForKey:(NSString*)strKey withArray:(NSArray*)arrValue
{
	[suserDefaults setObject:arrValue forKey:strKey];
}

+ (NSDictionary *)getContentDictionaryForKey:(NSString*)strKey
{
	return [suserDefaults dictionaryForKey:strKey];
}

+ (void)setContentDictionaryForKey:(NSString*)strKey withDictionary:(NSDictionary*)dictValue
{
    //	NSLog(@"Attempting to set new content:\n%@\nFor key [%@].", dictValue, strKey);

	[suserDefaults removeObjectForKey:strKey];
	[suserDefaults setObject:dictValue forKey:strKey];
}

+ (void)removePrefForKey:(NSString*)strKey
{
	[suserDefaults removeObjectForKey:strKey];
}

+ (NSString*)getSubvalueKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue
{
	// Our string will be: <Key>:<Subvalue>
	return [NSString stringWithFormat:@"%@:%@", strKey, strSubvalue];
}

+ (int)getContentSubvalueForKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue
{
	NSString *strFull = [self getSubvalueKey:strKey withSubvalue:strSubvalue];
	int nValue = [suserDefaults integerForKey:strFull];
	return nValue;
}

+ (void)setContentSubvalueForKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue withValue:(int)nValue
{
	NSString *strFull = [self getSubvalueKey:strKey withSubvalue:strSubvalue];
    //	NSLog(@"Del: Setting [%@] to %d.", strFull, nValue);
	[suserDefaults setInteger:nValue forKey:strFull];
}

+ (int)adjustContentSubvalueForKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue withDelta:(int)nDelta
{
	int nOld = [self getContentSubvalueForKey:strKey withSubvalue:strSubvalue];
	int nNew = nOld + nDelta;
	// Let's not let it go below zero right now.
	nNew = MAX(0, nNew);
	[self setContentSubvalueForKey:strKey withSubvalue:strSubvalue withValue:nNew];
	return nNew;
}

+ (int)getLimitedKeyCountForKey:(NSString*)strKey
{
    // We'll always construct the value of key with "count" for this.
    return [MRUtilities getContentSubvalueForKey:strKey withSubvalue:@"count"];
}

+ (int)decrementLimitedKey:(NSString*)strKey
{
    // We'll always construct the value of key with "count" for this.

    int nRemaining = [MRUtilities adjustContentSubvalueForKey:strKey withSubvalue:@"count" withDelta:-1];

    // If we've gone to zero, also turn us off as a def.
    if (nRemaining < 1)
    {
        [MRUtilities setContentStatusForKey:strKey asActive:NO];
    }

    return nRemaining;
}

+ (NSString*)getKeyForTech:(NSString*)strTech
{
	// Our format will be: [unlocked|Tech:type]
	NSString *strKey = [NSString stringWithFormat:@"%@%@:%@", PREFS_KEY_UNLOCKED, sstrKeyStyles[EKS_TECH], strTech];
	return strKey;
}

+ (ELevelState)getTechState:(NSString*)strTech
{
	// For now we're just doing a bool...
	NSString *strKey = [MRUtilities getKeyForTech:strTech];
	BOOL fUnlocked = [MRUtilities getContentStatusForKey:strKey];
	if (fUnlocked == NO)
		return ELS_LOCKED_HIDDEN;

	// Otherwise, we're good.
	return ELS_UNLOCKED;
}

#pragma mark -
#pragma mark Keys.
+ (NSString*)getKeyForSet:(int)nSet withStyle:(EKeyStyle)eKey
{
	if ((int)eKey < 0 || eKey >= snNumKeyStyles)
		eKey = EKS_NONE;
	return [NSString stringWithFormat:@"Set%d%@", nSet, sstrKeyStyles[eKey]];
}

+ (NSString*)getKeyForMission:(int)nMission withStyle:(EKeyStyle)eKey
{
	if ((int)eKey < 0 || eKey >= snNumKeyStyles)
		eKey = EKS_NONE;
	return [NSString stringWithFormat:@"Mission%d%@", nMission, sstrKeyStyles[eKey]];
}

+ (NSString*)getKeyForLifetimeWithStyle:(EKeyStyle)eKey
{
	if ((int)eKey < 0 || eKey >= snNumKeyStyles)
		eKey = EKS_NONE;
	return [NSString stringWithFormat:@"%@%@", PREFS_KEY_LIFETIME, sstrKeyStyles[eKey]];
}

+ (NSString*)getKeyForCurrentWithStyle:(EKeyStyle)eKey
{
	if ((int)eKey < 0 || eKey >= snNumKeyStyles)
		eKey = EKS_NONE;
	return [NSString stringWithFormat:@"%@%@", PREFS_KEY_CURRENT, sstrKeyStyles[eKey]];
}

+ (NSString*)getKeyForLevelWithStyle:(EKeyStyle)eKey
{
	if ((int)eKey < 0 || eKey >= snNumKeyStyles)
		eKey = EKS_NONE;
	return [NSString stringWithFormat:@"%@%@", PREFS_KEY_LEVEL, sstrKeyStyles[eKey]];
}


#pragma mark -
#pragma mark Graphics

- (id)createMapNodePointer:(MRDefinitionSprite *)sprNode inLayer:(MRLayer*)layer atPoint:(CGPoint)pIntersect
{
	MRDefinitionSprite *sprNew = [self createMapNodePointer:sprNode inLayer:layer];
	[sprNew setPosition:pIntersect];

	// And we're visible by default.
	// Now not -- going to fade in.
//	sprNew.visible = YES;

	return sprNew;
}

- (id)createMapNodePointer:(MRDefinitionSprite *)sprNode inLayer:(MRLayer*)layer
{
	MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:@"map_bubble.png"];
	MRDefinitionSprite *sprNew = [MRDefinitionSprite spriteWithFrame:frame];
	CGSize size = [sprNew contentSize];
	[layer addChild:sprNew];

	// Try to get this item from a definition...
	MRDefinitionSprite *sprIcon = nil;
	NSDictionary *defIcon = [[MRDefinitions sharedDefsManager] getDefByName:sprNode.m_strDefinition];
	if (defIcon != nil)
	{
		sprIcon = [MRDefinitionSprite createIconFromDefinition:defIcon];
	}
	else
	{
		MRSpriteFrame *frameIcon = [sprNode getSpriteFrame];
		sprIcon = [MRDefinitionSprite spriteWithFrame:frameIcon];
	}

	// Zombie hack -- rotate our objects to face "up" properly.
	sprIcon.rotation -= 90.0f;

	[sprNew addChild:sprIcon];
	CGSize sizeIcon = [sprIcon recursiveBoundingBox].size;
	float flIconWidth = MAX(sizeIcon.width, sizeIcon.height);
	[sprIcon setScale:(size.width / 2.5f) / flIconWidth];
	[sprIcon setPosition:MRPoint(size.width / 2.0f, size.height / 2.0f)];

	// Start hidden by default.
	sprNew.visible = NO;
	[sprNew setOpacity:0];

	return sprNew;
}

@class SkyScene;

- (void)updateMapNodePointer:(MRDefinitionSprite*)sprNode forBody:(MRDefinitionSprite*)bodyItem
{
	static float sflMinBubbleDistance = 200.0f;

	if (sprNode == nil || bodyItem == nil)
		return;

	CGPoint pNode = bodyItem.position;

	// If we're in-game, we might have an altered scale.
    CGRect sgrectScreen = {0, 0, MR_SCREEN_MAJOR, MR_SCREEN_MINOR};

	CGRect rectScreen = sgrectScreen;
	float flScale = 1.0f;
	MRNode *sceneStars;
	if ([MRSceneHost respondsToSelector:@selector(getSkyScene)] == YES)
		sceneStars = [MRSceneHost performSelector:@selector(getSkyScene)];
	else if ([MRSceneHost respondsToSelector:@selector(getGameScene)] == YES)
        sceneStars = [MRSceneHost performSelector:@selector(getGameScene)];

	if (sceneStars != nil)
	{
		if ([sceneStars respondsToSelector:@selector(getZoomLevel)] == YES)
		{
			flScale = 1.0f; //(float)[sceneStars getZoomLevel];
		}
		if (fabs(flScale - 1.0f) > FLT_EPSILON)
		{
			rectScreen.size.width  /= flScale;
			rectScreen.size.height /= flScale;
			rectScreen.origin.x = MR_HALF_SCREEN_MAJOR - (rectScreen.size.width  / 2.0f);
			rectScreen.origin.y = MR_HALF_SCREEN_MINOR - (rectScreen.size.height / 2.0f);
		}
	}

	if (CGRectContainsPoint(rectScreen, pNode) == NO)
	{
		// Are we just appearing? If so, fade in.
		if (sprNode.opacity == 0)
		{
			// Only do this if we haven't started the action yet.
			if(sprNode.numberOfRunningActions < 1)
				[self fadeInForNode:sprNode];
		}

		// Update the node.
		CGPoint pCenter = MRPoint(MR_HALF_SCREEN_MAJOR, MR_HALF_SCREEN_MINOR);
		CGPoint vCenterToNode = subtract(pNode, pCenter);
		CGPoint pIntersect = [self findScreenEdgeforRay:vCenterToNode withPoint:pCenter];
		sprNode.position = pIntersect;
		CGPoint vUp = MRPoint(0, 1.0f);
		float flAngle = angleBetweenVectors(vCenterToNode, vUp);
		[sprNode setRotation:flAngle];
		// Scale us based on how far offscreen we are.
		float flDistanceFromIntersect = length(subtract(pNode, pIntersect));
		float flDistFull = sflMinBubbleDistance / flScale;
		if (flDistanceFromIntersect <= flDistFull)
		{
			sprNode.scale = 1.0f;
		}
		else
		{
			float flRemainder = flDistanceFromIntersect - flDistFull;
			// Don't go above 100% or below 50%
			float flPercent = MIN(1.0f, 1.0f - (flRemainder / flDistFull));
			flPercent = MAX(0.5f, flPercent);
			sprNode.scale = flPercent;
		}
		// Kinda hack: if we're near a L/R edge, snap us to that side.
		if ((MR_SCREEN_MAJOR - pIntersect.x) < 50.0f)
		{
			float flAdjustX = sprNode.contentSize.width / 2.0f;
			pIntersect.x = MR_SCREEN_MAJOR - (flAdjustX * sprNode.scale);
			sprNode.position = pIntersect;
		}
		else if (pIntersect.x < 50.0f)
		{
			float flAdjustX = sprNode.contentSize.width / 2.0f;
			pIntersect.x = (flAdjustX * sprNode.scale);
			sprNode.position = pIntersect;
		}
	}
	else
	{
		// Are we just vanishing? If so, fade out.
		if (sprNode.opacity == 255)
		{
			// Only do this if we haven't started the action yet.
			if(sprNode.numberOfRunningActions < 1)
				[self fadeOutForNode:sprNode];
		}
	}
}

- (void)fadeInForNode:(MRDefinitionSprite*)sprNode
{
	sprNode.visible = YES;
	[sprNode setOpacity:0];
	MRFadeIn *animFadeIn = [MRFadeIn actionWithDuration:POINTER_FADE_IN_TIME];
	[sprNode stopAllActions];
	[sprNode runAction:animFadeIn];

	// And for all children.
	for (MRDefinitionSprite *sprChild in [sprNode children])
	{
		if ([sprChild isKindOfClass:[MRDefinitionSprite class]])
			[self fadeInForNode:sprChild];
		else
			sprChild.visible = YES;
	}
}

- (void)fadeOutForNode:(MRDefinitionSprite*)sprNode
{
	sprNode.visible = YES;
	[sprNode setOpacity:255];
	MRFadeOut *animFadeOut = [MRFadeOut actionWithDuration:POINTER_FADE_OUT_TIME];
	[sprNode stopAllActions];
	[sprNode runAction:animFadeOut];

	// And for all children.
	for (MRDefinitionSprite *sprChild in [sprNode children])
	{
		if ([sprChild isKindOfClass:[MRDefinitionSprite class]])
			[self fadeOutForNode:sprChild];
		else
			sprChild.visible = NO;
	}
}

- (CGPoint)findScreenEdgeforRay:(CGPoint)vCenterToNode withPoint:(CGPoint)pCenter
{
	CGPoint pIntersect;
	CGPoint vUp = MRPoint(0, 1.0f);
	float flBorder = 20.0f;
	float flYMax = MR_SCREEN_MINOR - flBorder;
	float flXMax = MR_SCREEN_MAJOR - flBorder;
	float flYMin = flBorder;
	float flXMin = flBorder;

#define ANGLE_BASE (53.130096)
#define ANGLE_DL (90.0f + ANGLE_BASE)
#define ANGLE_UL (90.0f - ANGLE_BASE)
#define ANGLE_UR -(ANGLE_UL)
#define ANGLE_DR -(ANGLE_DL)

	// Since our screen isn't square, we need to compare versus the (non-45 degree) angle at a corner
	// to decide which edge we're off of.
	float flAngle = angleBetweenVectors(vUp, vCenterToNode);
	//NSLog(@"CenterToNode is (%.0f, %.0f), angle is %.1f", vCenterToNode.x, vCenterToNode.y, flAngle);

	if (flAngle >= ANGLE_UR && flAngle <= ANGLE_UL)
	{
		// Intersect is above
		float flScale = MR_HALF_SCREEN_MINOR / vCenterToNode.y;
		pIntersect = MRPoint(vCenterToNode.x * flScale + MR_HALF_SCREEN_MAJOR, flYMax);
		//NSLog(@"  ABOVE");
	}
	else if (flAngle >= ANGLE_UL && flAngle <= ANGLE_DL)
	{
		// Intesect is to the left
		float flScale = MR_HALF_SCREEN_MAJOR / vCenterToNode.x;
		pIntersect = MRPoint(flXMin, vCenterToNode.y * -flScale + MR_HALF_SCREEN_MINOR);
		//NSLog(@"  LEFT");
	}
	else if (flAngle >= ANGLE_DR && flAngle <= ANGLE_UR)
	{
		// Intersect is to the right
		float flScale = MR_HALF_SCREEN_MAJOR / vCenterToNode.x;
		pIntersect = MRPoint(flXMax, vCenterToNode.y * flScale + MR_HALF_SCREEN_MINOR);
		//NSLog(@"  RIGHT");
	}
	else
	{
		// Intersect is below
		float flScale = MR_HALF_SCREEN_MAJOR / vCenterToNode.y;
		pIntersect = MRPoint(vCenterToNode.x * -flScale + MR_HALF_SCREEN_MINOR, flYMin);
		//NSLog(@"  BELOW");
	}

	if (pIntersect.x < flXMin)
		pIntersect.x = flXMin;
	else if (pIntersect.x > flXMax)
		pIntersect.x = flXMax;

	if (pIntersect.y < flYMin)
		pIntersect.y = flYMin;
	else if (pIntersect.y > flYMax)
		pIntersect.y = flYMax;

	//NSLog(@"Intersect at (%.0f, %.0f)", pIntersect.x, pIntersect.y);

	return pIntersect;
}

static int snDotCount = 0;

- (MRDefinitionSprite*)localGimmeADotWithFuzz:(BOOL)fWithFuzz;
{
    NSString *strDot = @"dot_fuzzy_little.png";
    if (fWithFuzz == YES)
        strDot = @"dot_fuzzy.png";
	MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:strDot];
    MRDefinitionSprite *sprDot = ([[MRDefinitionSprite alloc] initWithFrame:frame]);
    [sprDot setAnchorPoint:MRPoint(0.5f, 0.5f)];
    snDotCount++;

    return sprDot;
}

- (MRDefinitionSprite*)localGimmeADotIn:(MRSprite*)sprContainer atPos:(CGPoint)ptPos
{
    MRDefinitionSprite *sprDot = [self localGimmeADotWithFuzz:NO];
    [sprContainer addChild:sprDot z:100];
    [sprDot setPosition:ptPos];

    // Test -- make each twice as big for now.
    [sprDot setScaleX:4.0f];
    [sprDot setScaleY:2.0f];

    MRDefinitionSprite *sprFuzz = [self localGimmeADotWithFuzz:YES];
    [sprContainer addChild:sprFuzz z:1];
    [sprFuzz setPosition:ptPos];
    [sprFuzz setScale:1.0f];
    [sprFuzz setColor:[MRUtilities getColor:@"blueDark"]];
    [sprFuzz setScale:2.0f];

    return sprDot;
}

// Local hack test thing...
- (void)createBoltFromPointA:(CGPoint)ptA toPointB:(CGPoint)ptB withDepth:(int)nDepth intoContainer:(MRSprite*)sprContainer
{
    // We need a non-nil container.
    if (sprContainer == nil)
        return;

    // Early out if we're too deep.
    if (nDepth >= 8)
        return;

    // Kinda hack: if we're the zero-th entry, create the dots for
    // our start and end points right now.
    if (nDepth == 0)
    {
        snDotCount = 0;
        MRDefinitionSprite *sprA = [self localGimmeADotIn:sprContainer atPos:ptA];
        [sprA setScale:(sprA.scale * 4.0f)];
        MRDefinitionSprite *sprB = [self localGimmeADotIn:sprContainer atPos:ptB];
        [sprB setScale:(sprB.scale * 4.0f)];
    }

    // Get the midpoint between A and B.
    CGPoint vDelta = subtract(ptB, ptA);
    float flLength = length(vDelta);
    if (flLength < 4.0f)
        return;

    // What is our angle?
    float flAngleAtoB = angleBetweenPoints(ptB, ptA);

    CGPoint vUnit = normalize(vDelta);
    CGPoint vHalf = scale(vUnit, flLength / 2.0f);
    CGPoint ptMid = add(ptA, vHalf);

    //    NSLog(@"Bolt: A = (%.0f, %.0f), B = (%.0f, %.0f), Mid = (%.0f, %.0f)",
    //          ptA.x, ptA.y, ptB.x, ptB.y, ptMid.x, ptMid.y);

    // Get the right angle.
    float flAngle = 90.0f;
    if (rand() % 2 == 0)
        flAngle = -90.0f;
    // Pick a smaller amount...
    float flMult = 0.5f / (nDepth + 1.0f);
    flMult = MRRandomUnit() * flMult;
    CGPoint vFraction = scale(vUnit, flLength * flMult);
    CGPoint vRight = rotateVectorByAngle(vFraction, flAngle);

    // Get that actual point.
    CGPoint ptNew = add(ptMid, vRight);
    //    NSLog(@"Bolt: New point is (%.0f, %.0f)", ptNew.x, ptNew.y);

    // Create the point.
    MRDefinitionSprite *sprDot = [self localGimmeADotIn:sprContainer atPos:ptNew];
    [sprDot setRotation:flAngleAtoB];

    // Now do our next subdivided points.
    [self createBoltFromPointA:ptA toPointB:ptNew withDepth:(nDepth+1) intoContainer:sprContainer];
    [self createBoltFromPointA:ptNew toPointB:ptB withDepth:(nDepth+1) intoContainer:sprContainer];

    // We may have little extra jaggies coming off.
    if (nDepth >= 1 && nDepth <= 4)
    {
        if (rand() % 10 == 0)
        {
            CGPoint vSpike = subtract(ptB, ptNew);
            float flAngleSpike = -45.0f + (MRRandomUnit() * 90.0f);
            vSpike = rotateVectorByAngle(vSpike, flAngleSpike);
            CGPoint ptSpike = add(ptNew, vSpike);
            [self createBoltFromPointA:ptNew toPointB:ptSpike withDepth:(nDepth+1) intoContainer:sprContainer];
        }
    }

//    if (nDepth == 0)
//    {
//        NSLog(@"Bolt had %d segments.", snDotCount);
//    }
}

- (void)createBoltFromPointA:(CGPoint)ptA toPointB:(CGPoint)ptB intoLayer:(MRLayer*)layContainer
{
    if (layContainer == nil)
        return;

    MRDefinitionSprite *nodeHolder = [MRDefinitionSprite node];
	[nodeHolder setContentSize:CGSizeMake(MR_SCREEN_MINOR, MR_SCREEN_MAJOR)];
    [nodeHolder setPosition:MRPoint(0.0f, 0.0f)];
    [nodeHolder setAnchorPoint:MRPoint(0.0f, 0.0f)];
    [nodeHolder setColorChildren:YES];
    [nodeHolder setTag:SPRITE_TAG_LIGHTNING];

    [self createBoltFromPointA:ptA
                      toPointB:ptB
                     withDepth:0
                 intoContainer:nodeHolder];
    [layContainer addChild:nodeHolder];

    //	NSLog(@"*** Bolt has %d dots.", snDotCount);

    id idFadeOut = [MRFadeOut actionWithDuration:0.5f];
    id idDie     = [MRCallFunc actionWithTarget:nodeHolder selector:@selector(suicide)];
    [nodeHolder runAction:[MRSequence actions:idFadeOut, idDie, nil]];
}

- (void)createBoltsFromParams:(NSMutableDictionary*)dictParams
{
    if (dictParams == nil)
        return;

    // What is our count?
    int nRemaining = [[dictParams objectForKey:@"count"] intValue];
    if (nRemaining < 1)
        return;
    [dictParams setObject:[NSNumber numberWithInt:(nRemaining - 1)] forKey:@"count"];

    // Get the holder and points.
    MRLayer *layContainer = (MRLayer*)[dictParams objectForKey:@"layer"];
    MRPointValue *obStart    = (MRPointValue*)[dictParams objectForKey:@"ptA"];
    MRPointValue *obEnd      = (MRPointValue*)[dictParams objectForKey:@"ptB"];

    [self createBoltFromPointA:obStart.ptPoint toPointB:obEnd.ptPoint intoLayer:layContainer];

     // And call us again in a bit.
    [self performSelector:@selector(createBoltsFromParams:) withObject:dictParams afterDelay:0.125f];
}

#pragma mark -
#pragma mark Hardware

- (NSString *) getModel
{
	static NSString *sstrModel = nil;

	if (sstrModel == nil)
	{
		UIDevice *device = [UIDevice currentDevice];
		sstrModel = ([device model]);
	}
	return sstrModel;
}

- (BOOL) modelIsIpad
{
	static BOOL sfChecked = NO;
	static BOOL sfIsIpad = NO;
	if (sfChecked == NO)
	{
		if ([[self getModel] isEqualToString:@"iPad"] == YES)
			sfIsIpad = YES;
		sfChecked = YES;
	}
	return sfIsIpad;
}

- (NSString *) getPlatform
{
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *machine = (char*)malloc(size);
	sysctlbyname("hw.machine", machine, &size, NULL, 0);
	NSString *platform = [NSString stringWithUTF8String:machine];
	free(machine);
	return platform;
}

- (NSString *) getPlatformString
{
	static NSString *platformName = nil;
	if (platformName == nil)
	{
		NSString *strPlatform = [self getPlatform];

		if ([strPlatform isEqualToString:@"iPhone1,1"]) platformName = IPHONE_1G_NAMESTRING;
		else if ([strPlatform isEqualToString:@"iPhone1,2"]) platformName = IPHONE_3G_NAMESTRING;
		else if ([strPlatform isEqualToString:@"iPhone2,1"]) platformName = IPHONE_3GS_NAMESTRING;
		else if ([strPlatform isEqualToString:@"iPod1,1"])   platformName = IPOD_1G_NAMESTRING;
		else if ([strPlatform isEqualToString:@"iPod2,1"])   platformName = IPOD_2G_NAMESTRING;
	}
	return platformName;
}

- (BOOL) getPlatformIsFirstGen
{
	static BOOL sfChecked = NO;
	static BOOL sfIsFirstGen = NO;
	if (sfChecked == NO)
	{
		NSString *strPlatform = [self getPlatformString];
		if ([strPlatform isEqualToString:IPHONE_1G_NAMESTRING])
			sfIsFirstGen = YES;
		else if ([strPlatform isEqualToString:IPOD_1G_NAMESTRING])
			sfIsFirstGen = YES;
		sfChecked = YES;
	}
	return sfIsFirstGen;
}

- (BOOL) getPlatformIsSecondGen
{
	static BOOL sfChecked = NO;
	static BOOL sfIsSecondGen = NO;
	if (sfChecked == NO)
	{
		NSString *strPlatform = [self getPlatformString];
		if ([strPlatform isEqualToString:IPHONE_3G_NAMESTRING])
			sfIsSecondGen = YES;
		if ([strPlatform isEqualToString:IPOD_2G_NAMESTRING])
			sfIsSecondGen = YES;
		sfChecked = YES;
	}
	return sfIsSecondGen;
}

- (BOOL) getPlatformIsThirdGen
{
	static BOOL sfChecked = NO;
	static BOOL sfIsThirdGen = NO;
	if (sfChecked == NO)
	{
		NSString *strPlatform = [self getPlatformString];
		if ([strPlatform isEqualToString:IPHONE_3GS_NAMESTRING])
			sfIsThirdGen = YES;
		sfChecked = YES;
	}
	return sfIsThirdGen;
}

- (void)setDefaultFont:(NSString*)strFont
{
    (void)0;
    m_strDefaultFont = ([NSString stringWithString:strFont]);
}

// This is for TrueType fonts.
- (NSString *)getDefaultSystemFont
{
	if ([self getPlatformIsFirstGen] == YES)
		return DEFAULT_FONT_GEN1_SYSTEM;
	else
		return DEFAULT_FONT_SYSTEM;
}

// This is for our own generated fonts.
- (NSString *)getDefaultFont
{
    if (m_strDefaultFont != nil)
        return m_strDefaultFont;
    else
        return DEFAULT_FONT;
}

- (NSString *)getDefaultFontCachedFast
{
    return [self getDefaultSystemFont];
	// We've already pre-calculated all this in startup.
//	return m_strDefaultFont;
}


+ (float)getDeviceScaleAdjustment
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        return 2;
    else
        return 1;
}

+ (BOOL)isIPad1
{
    NSString *strPlatform = [[MRUtilities sharedUtilityManager] getPlatform];
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [strPlatform hasPrefix:@"iPad1"] == YES);
}

+ (BOOL)isIPad
{
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}

#pragma mark -
#pragma mark Colors

- (void)initColors
{
	// Create our list of color stuff.
    NSString *path = [MRBundleResources pathForResource:@"colors.plist"];
    NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:path];
    m_dictColors = ([NSMutableDictionary dictionaryWithCapacity:[dictionary count]]);
    for (NSString *strColor in dictionary)
    {
        id obColor = [dictionary objectForKey:strColor];
        if ([obColor isKindOfClass:[NSDictionary class]] == YES)
        {
            NSDictionary *dictColor = (NSDictionary *)obColor;
            uint8_t byRed   = (uint8_t)[[dictColor objectForKey:@"red"] integerValue];
            uint8_t byGreen = (uint8_t)[[dictColor objectForKey:@"green"] integerValue];
            uint8_t byBlue  = (uint8_t)[[dictColor objectForKey:@"blue"] integerValue];
            MRColorValue *colItem = [MRColorValue colorWithRed:byRed withGreen:byGreen withBlue:byBlue];
            [m_dictColors setObject:colItem forKey:strColor];
        }
        else if ([obColor isKindOfClass:[NSArray class]] == YES)
        {
            NSArray *aRawSet = (NSArray *)obColor;
            NSMutableArray *aColorSet = [NSMutableArray arrayWithCapacity:[aRawSet count]];
            for (NSDictionary *dictColor in aRawSet)
            {
                uint8_t byRed   = (uint8_t)[[dictColor objectForKey:@"red"] integerValue];
                uint8_t byGreen = (uint8_t)[[dictColor objectForKey:@"green"] integerValue];
                uint8_t byBlue  = (uint8_t)[[dictColor objectForKey:@"blue"] integerValue];
                MRColorValue *colItem = [MRColorValue colorWithRed:byRed withGreen:byGreen withBlue:byBlue];
                [aColorSet addObject:colItem];
            }
            [m_dictColors setObject:aColorSet forKey:strColor];
        }
    }
    (void)0;

	NSLog(@"    UM: Done with Colors.");
}

- (MRColor3B)localGetColor:(NSString*)strColor
{
    MRColorValue *color = nil;
    NSArray *aColorSet = [strColor componentsSeparatedByString:@"::"];
    if ([aColorSet count] == 2)
    {
        NSString *strColorSet = [aColorSet objectAtIndex:0];
        int nIndex = [[aColorSet objectAtIndex:1] intValue];
        NSArray *aColorSet = [self localGetColorSet:strColorSet];
        color = [aColorSet objectAtIndex:nIndex];
    }
    else
    {
        id idColor = [m_dictColors objectForKey:strColor];
        if ([idColor isKindOfClass:[NSArray class]] == YES)
        {
            return [MRUtilities getColorInSet:strColor atIndex:random()];
        }
        else // Just a regular color.
        {
            color = idColor;
        }
    }
    if (color == nil)
    {
        NSLog(@"Color warning -- [%@] not found! Returning black.", strColor);
        return MRRGB(0, 0, 0);
    }
    return [color getColor3B];
}

+ (MRColor3B)getColor:(NSString*)strColor
{
	return [[MRUtilities sharedUtilityManager] localGetColor:strColor];
}

- (MRRenderColor)localGetColorAs4B:(NSString*)strColor
{
    MRColorValue *color = nil;
    NSArray *aColorSet = [strColor componentsSeparatedByString:@"::"];
    if ([aColorSet count] == 2)
    {
        NSString *strColorSet = [aColorSet objectAtIndex:0];
        int nIndex = [[aColorSet objectAtIndex:1] intValue];
        NSArray *aColorSet = [self localGetColorSet:strColorSet];
        color = [aColorSet objectAtIndex:nIndex];
    }
    else
    {
        color = [m_dictColors objectForKey:strColor];
    }
    if (color == nil)
    {
        NSLog(@"Color warning -- [%@] not found! Returning black.", strColor);
        return MRRGBA(0, 0, 0, 255);
    }
	return [color getColor4B];
}

+ (MRRenderColor)getColorAs4B:(NSString*)strColor
{
	return [[MRUtilities sharedUtilityManager] localGetColorAs4B:strColor];
}

- (NSArray *)localGetColorSet:(NSString *)strColorSet
{
    NSArray *aColorSet = [m_dictColors objectForKey:strColorSet];
    return aColorSet;
}

+ (NSArray *)getColorSet:(NSString *)strColorSet
{
    return [[MRUtilities sharedUtilityManager] localGetColorSet:strColorSet];
}

- (MRColor3B)localGetColorInSet:(NSString *)strColorSet atIndex:(int)nIndex
{
    NSArray *aColorSet = [self localGetColorSet:strColorSet];
    MRColorValue *color = nil;
    if (aColorSet != nil)
    {
        nIndex = nIndex % [aColorSet count];
        color = [aColorSet objectAtIndex:nIndex];
    }
    if (color == nil)
	{
		NSLog(@"Color warning -- [%@ index %d] not found in set! Returning black.", strColorSet, nIndex);
		return MRRGB(0, 0, 0);
    }
    return [color getColor3B];
}

+ (MRColor3B)getColorInSet:(NSString *)strColorSet atIndex:(int)nIndex
{
    return [[MRUtilities sharedUtilityManager] localGetColorInSet:strColorSet atIndex:nIndex];
}

#pragma mark -
#pragma mark Shape-Groups
- (NSString*)groupsGetMasterPath
{
	NSString *strPath = [MRBundleResources pathForResource:@"groups.plist"];
	if (strPath == nil)
	{
		NSLog(@"ERROR: Groups file %@ is missing from bundle.", strPath);
        return nil;
	}
    return strPath;
}

- (NSDictionary*)groupsGetMasterDictionary
{
    NSString *path = [self groupsGetMasterPath];
	NSDictionary *dictionary = ([[NSDictionary alloc] initWithContentsOfFile:path]);

    return dictionary;
}

- (NSString*)groupsGetDynamicPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

	// Get the path to user data.
	NSString *userDocumentsPath = [NSString stringWithString:[paths objectAtIndex:0]];

    NSString *strPath = [NSString stringWithFormat:@"%@/groups_dynamic.plist", userDocumentsPath];
	if (strPath == nil)
	{
		NSLog(@"ERROR: Writeable-Groups file %@ is missing from bundle.", strPath);
        return nil;
	}
    return strPath;
}

- (NSMutableDictionary*)groupsGetDynamicDictionary
{
    NSString *strPath = [self groupsGetDynamicPath];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithContentsOfFile:strPath];
    if (dictionary == nil)
        dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    return dictionary;
    //    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:1];
}

- (NSDictionary*)groupsGetCombinedDictionary
{
    if (m_dictGroupsCombined == nil)
        [self groupsReloadCombinedDictionary];
    return m_dictGroupsCombined;
}

- (void)groupsReloadCombinedDictionary
{
    // If we had old entries, clear them.
    (void)0;
    m_dictGroupsCombined = nil;

    // Load in the master/static entries.
    NSDictionary *dictMaster = [self groupsGetMasterDictionary];

    // Load in the dynamic entries.
    NSMutableDictionary *dictDynamic = [self groupsGetDynamicDictionary];

    // Cram them together, letting dynamic entries override master ones (may reverse this later!)
    for (NSString *strEntry in dictMaster)
    {
        if ([dictDynamic objectForKey:strEntry] == nil)
        {
            NSDictionary *dictEntry = [dictMaster objectForKey:strEntry];
            [dictDynamic setObject:dictEntry forKey:strEntry];
        }
    }

    // Copy them out into our combined group.
    m_dictGroupsCombined = [[NSDictionary alloc] initWithDictionary:dictDynamic copyItems:YES];
}

#pragma mark -
#pragma mark Network
// Network related.

- (void)initNetwork
{
	static BOOL sfDidInit = FALSE;
	NSLog(@"    iN: Beginning init.");
	// TEST InertSoapConnect
	if (sfDidInit == NO)
	{
		m_arrQueuedRequests = [[NSMutableArray alloc] initWithCapacity:4];
		m_dictISCParams = ([self genericParameters]);
		NSLog(@"    iN: Done genericParameters.");
		m_connectionISC = nil;
		m_dataISC = nil;
		// Let's delay our ping so that it comes after full boot time, for faster-to-menu performance.
		[self performSelector:@selector(sendISCPing) withObject:self afterDelay:4.0f];
//		[self sendISCPing];
		NSLog(@"    iN: Done sendISCPing.");
		sfDidInit = YES;
	}
	NSLog(@"    iN: Done init.");
}

- (BOOL)isInternetReachable
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    return !(networkStatus == NotReachable);
}

//void MyHostClientCallBack (
//						   CFHostRef theHost,
//						   CFHostInfoType typeInfo,
//						   const CFStreamError *error,
//						   void *info
//						   )
//{
////    UtilityManager *utilityManager = (UtilityManager *)info;
//    CFDataRef    data;
//
//    if (error->error == noErr)
//	{
//        if (typeInfo == kCFHostReachability)
//		{
//                /* CFHostGetReachability retrieves the reachability of the given host.  Returns a
//				 CFDataRef which wraps the reachability flags.  The possible values of these flags
//				 is declared in SystemConfiguration/SCNetwork.h.  */
//
//                data = CFHostGetReachability(theHost, NULL);
//        }
//    }
//	else
//	{
//        //fprintf(stderr, "MyCFHostClientCallBack returned (%d, %ld)\n", error->domain, error->error);
//
//    }
//
//
//    /* The CFHost callback only gets called once, so we cleanup now that we're done. */
//    CFHostUnscheduleFromRunLoop(theHost, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
//
//
//    /* This removes the client callback association from the host object. */
//    CFHostSetClient(theHost, NULL, NULL);
//    CFRelease(theHost);
//
//    /* Stop the run loop now that we've retrieved the host info. */
//    CFRunLoopStop(CFRunLoopGetCurrent());
//}

- (BOOL)isNetworkAvailable
{
	NSLog(@"   ==> isNetworkAvailable call.");

    // ... can we piggyback on OpenFeint?
//    return [OFManager isConnectedToInternet];

    // Say yes for now...
    return YES;

//	CFStreamError cfStreamError;
//
//	CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, CFSTR("itunes.apple.com"));
//	//CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, CFSTR("inertsoap.com"));
//
//	// Needed for asynchronous operation
////    CFHostClientContext  context = { 0, (void *)self, CFRetain, CFRelease, NULL };
////	BOOL fSuccess = CFHostSetClient(hostRef, MyHostClientCallBack, &context);
////	if (fSuccess)
////	{
////		CFHostScheduleWithRunLoop(hostRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
////
////		success = CFHostStartInfoResolution(hostRef, kCFHostReachability, &cfStreamError);
////		if (!success)
////		{
////            MyCFHostCleanup(hostRef);
////        }
////    }
////	else
////	{
////        CFRelease(hostRef);
////    }
//
//	CFHostStartInfoResolution(hostRef, kCFHostReachability, &cfStreamError);
//
//	CFDataRef data = CFHostGetReachability(hostRef, nil);
//
//	SCNetworkConnectionFlags *flags;
//
//	flags = (SCNetworkConnectionFlags *)CFDataGetBytePtr(data);
//
//	int reachable = *flags & kSCNetworkReachabilityFlagsReachable;
//
//	// We don't care about cellular verus non right now.
//	//	int cellular = *flags & kSCNetworkReachabilityFlagsIsWWAN;
//
//	// In synchronous mode, we can now release our references.
//	CFRelease(hostRef);
//
//	NSLog(@"   ==> isNetworkAvailable END.");
//
//	if (reachable == 0)
//	{
//		return NO;
//	}
//
//	return YES;
}

- (NSString *)md5sum:(NSString *)plainStr
{
	unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
	CC_MD5([plainStr UTF8String], [plainStr lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
	NSMutableString *ms = [NSMutableString string];
	for (i=0;i<CC_MD5_DIGEST_LENGTH;i++) {
		[ms appendFormat: @"%02x", (int)(digest[i])];
	}
	return ([ms copy]);
}

- (NSString *)getDeviceTag
{
    NSString *deviceTag = [[UIDevice currentDevice] uniqueGlobalDeviceIdentifier];

    if ([self facebookRequestedAndRequired] == YES && m_strFacebookID != nil)
    {
        deviceTag = [NSString stringWithFormat:@"facebook:%@", m_strFacebookID];
    }
    return deviceTag;
}

- (NSString*)generateConnectKey
{
	// We're not going to be as secure as, say, TapJoy.  We're just
	// going to hash our [DeviceTag+Secret+AppName] for now.
	// See the TJConnectLite for sample other code.

//	NSString *deviceTag = [[UIDevice currentDevice] uniqueIdentifier];
    NSString *deviceTag = [self getDeviceTag];

	NSString *rawConnectKey = [NSString stringWithFormat:@"%@:%@:%@",
							   deviceTag, ISC_SECRET, MR_ISC_APP_NAME];
	NSString *strHash = [self md5sum:rawConnectKey];
	//NSLog(@"Hash of %@ => %@", rawConnectKey, strHash);
	return strHash;
}

- (NSString*)generateValueKey:(int)nValue
{
	// Our value key will be [DeviceTag+Secret+AppName+Value]
//	NSString *deviceTag = [[UIDevice currentDevice] uniqueIdentifier];
    NSString *deviceTag = [[UIDevice currentDevice] uniqueGlobalDeviceIdentifier];

	NSString *rawConnectKey = [NSString stringWithFormat:@"%@:%@:%@:%d",
							   deviceTag, ISC_SECRET, MR_ISC_APP_NAME, nValue];
	NSString *strHash = [self md5sum:rawConnectKey];
	//NSLog(@"Value Hash of %@ => %@", rawConnectKey, strHash);
	return strHash;
}

- (NSMutableDictionary *)genericParameters{
	UIDevice *device = [UIDevice currentDevice];
	NSString * identifier = [device uniqueGlobalDeviceIdentifier]; //[device uniqueIdentifier];
	NSString * model = [device model];
	NSString * systemVersion = [device systemVersion];
	NSString * appName	= MR_ISC_APP_NAME;
	NSString * appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	NSString * connectionKey = [self generateConnectKey];
	float connectLibraryVersion = 1.0f;
	NSString * strHardware = [self getPlatform];
	NSString * strScore = [NSString stringWithFormat:@"%d", [MRPersistentCounters getScoreForLifetime]];
	NSString * strNickname = [self GCgetAlias];
	if (strNickname == nil)
		strNickname = m_strNickname;
	if (strNickname == nil)
		strNickname = @"";

    // Facebook ID.
    NSString * strFacebook = @"";
    if (m_strFacebookID != nil)
        strFacebook = m_strFacebookID;

    // If we require Facebook, we're going to use that instead of a regular ID.
    if ([self facebookRequestedAndRequired] == YES)
    {
        if ([strFacebook length] > 0)
            identifier = [NSString stringWithFormat:@"facebook:%@", strFacebook];
        else
            identifier = ISC_FACEBOOK_INVALID;
    }

	NSMutableDictionary * genericDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
										 identifier,	ISC_NAME_DEVICE_TAG,
										 model,			ISC_NAME_DEVICE_TYPE,
										 systemVersion,	ISC_NAME_DEVICE_OS_VERSION,
										 appName,		ISC_NAME_APP_NAME,
										 appVersion,	ISC_NAME_APP_VERSION,
										 [NSNumber numberWithFloat:connectLibraryVersion], ISC_NAME_LIBRARY_VERSION,
										 connectionKey,	ISC_NAME_KEY,
										 strHardware,	ISC_NAME_DEVICE_HARDWARE,
										 strScore,		ISC_NAME_SCORE,
										 strNickname,	ISC_NAME_NICKNAME,
                                         strFacebook,   ISC_NAME_FACEBOOK,
										 //										 [NSNumber numberWithInt:timeStamp],TIME_STAMP,
										 nil];

	return (genericDict);
}

- (void)localStopParsing:(NSXMLParser*)parser
{
	[parser abortParsing];
	(void)0;
	m_dataISC = nil;
}

- (NSString*)localFreshenISCRequest:(NSString*)strRequest
{
    // If we had an invalid Device ID cached, replace it.
    NSString *strFacebook = [NSString stringWithFormat:@"facebook:%@", m_strFacebookID];
    strRequest = [strRequest stringByReplacingOccurrencesOfString:ISC_FACEBOOK_INVALID withString:strFacebook];

    // Our URL is before a ? character...
    NSArray *arrSections = [strRequest componentsSeparatedByString:@"?"];
    if ([arrSections count] < 2)
        return strRequest;

    strRequest = [NSString stringWithFormat:@"%@?", [arrSections objectAtIndex:0]];
    NSString *strValues = [arrSections objectAtIndex:1];

    // Split up our elements based on the & character.
    NSArray *arrItems = [strValues componentsSeparatedByString:@"&"];
    int nCount = [arrItems count];
    for (__strong NSString *strItem in arrItems)
    {
        // Add separating &'s for each item.
        if (nCount > 0)
            strRequest = [strRequest stringByAppendingString:@"&"];
        nCount++;

        // Each item may be an X=Y value.
        NSArray *arrSubItems = [strItem componentsSeparatedByString:@"="];
        if ([arrSubItems count] < 2)
        {
            // Just append us as-is.
            strRequest = [strRequest stringByAppendingString:strItem];
        }
        else
        {
            // Replace things we care about, like connection key.
            NSString *strKey = [arrSubItems objectAtIndex:0];
            NSString *strValue = [arrSubItems objectAtIndex:1];
            if ([strKey isEqualToString:ISC_NAME_KEY])
            {
                strValue = [self generateConnectKey];
            }
            // And rebuild our X=Y...
            strItem = [NSString stringWithFormat:@"%@=%@", strKey, strValue];
            strRequest = [strRequest stringByAppendingString:strItem];
        }
    }

    return strRequest;
}

- (void)localSendISCRequest:(NSString*)strRequest withRetain:(BOOL)fRetain
{
	BOOL fCouldReachHost = [self isNetworkAvailable];
	if (fCouldReachHost == NO)
	{
		NSLog(@"ISC - Network unavailable.");
		if (fRetain == YES)
		{
			//			// Set the RewardsController to ready.
			//			RewardsController *rwController = [FingerzillaAppDelegate getRewardsController];
			//			[rwController setBusyMessage:@"" asBusy:NO];
		}
		return;
	}

    // Also queue if we require Facebook and aren't yet connected.
    if ([self facebookRequestedAndRequired] == YES && m_strFacebookID == nil)
    {
        NSLog(@"Not connected to Facebook, so queueing!");
        [m_arrQueuedRequests addObject:strRequest];
        return;
    }

	if (([m_arrQueuedRequests count] > 0 || fRetain == YES) && m_connectionISC != nil)
	{
		// Can't do this if we have an existing connection.
		// Add this request to the queue.
//		NSLog(@"ISC -- Adding request to queue.");
		[m_arrQueuedRequests addObject:strRequest];
		return;
	}

    // Make sure we're up-to-date with various values.
    strRequest = [self localFreshenISCRequest:strRequest];

	// Get rid of spaces 'n stuff.
	NSString *strFixed =   [strRequest stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

#ifdef DEBUG
	NSLog(@"ISC Request: %@", strFixed);
#endif

	NSURL * myURL = [[NSURL alloc] initWithString:strFixed];
	NSMutableURLRequest *myRequest = [NSMutableURLRequest requestWithURL: myURL
															 cachePolicy: NSURLRequestUseProtocolCachePolicy
														 timeoutInterval: 15];
	(void)0;
	[[NSURLCache sharedURLCache] setMemoryCapacity:0];
	[[NSURLCache sharedURLCache] setDiskCapacity:0];
	if (fRetain == YES)
	{
		// Get rid of old data...
		if (m_dataISC != nil)
		{
			(void)0;
			m_dataISC = nil;
		}
		m_connectionISC = [[NSURLConnection alloc] initWithRequest: myRequest delegate: self];
	}
	else
	{
		// Tom note: we don't care about response ... delegate to nil, don't set connection, and release.
		([[NSURLConnection alloc] initWithRequest: myRequest delegate: nil]);
	}
}

- (void)sendISCCreateCouponRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_COUPONREQ_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY]
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

// This is for when B wants to use the coupon from A.
- (void)sendISCClaimCouponRequest:(NSString*)strCoupon
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_COUPONUSE_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY],
							ISC_NAME_COUPON,		strCoupon
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

// Check to see if our friends have used the coupons we have sent, and
// reward us if they have.
- (void)sendISCRedeemCouponsRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_COUPONREDEEM_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY]
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

// We want to clear out coupons we have geneated that never got claimed.
- (void)sendISCClearCouponsRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_COUPONCLEAR_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY]
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

// Ask for a list of bi-directional friends.
- (void)sendISCGetFriendRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_FRIENDREQ_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY]
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

// Ask for a list of Inert Soap apps this user has installed.
- (void)sendISCGetAppsRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_APPSREQ_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY]
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

// Ask for messages relating to this application.
- (void)sendISCGetMessagesRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_MESSAGEREQ_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY]
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

// Ask for popups relating to this application.
- (void)sendISCGetPopupRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_POPUPSREQ_SNIP,
							ISC_NAME_DEVICE_TAG,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_APP_NAME,		[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_KEY,			[m_dictISCParams objectForKey:ISC_NAME_KEY]
							];
	[self localSendISCRequest:strRequest withRetain:YES];
}

- (void)sendISCGetRewardsRequest
{
	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_REWARDSREQ_SNIP,
							ISC_NAME_DEVICE_TAG,		[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_KEY,				[m_dictISCParams objectForKey:ISC_NAME_KEY],
							ISC_NAME_DEVICE_TYPE,		[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TYPE],
							ISC_NAME_DEVICE_HARDWARE,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_HARDWARE],
							ISC_NAME_DEVICE_OS_VERSION, [m_dictISCParams objectForKey:ISC_NAME_DEVICE_OS_VERSION],
							ISC_NAME_APP_NAME,			[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_APP_VERSION,		[m_dictISCParams objectForKey:ISC_NAME_APP_VERSION],
							ISC_NAME_SCORE,				[m_dictISCParams objectForKey:ISC_NAME_SCORE],
							ISC_NAME_NICKNAME,			[m_dictISCParams objectForKey:ISC_NAME_NICKNAME]
							];

	[self localSendISCRequest:strRequest withRetain:YES];
}

- (void)sendISCPingWithExtra:(NSString*)strExtra
{
	// Ping needs to regenerate parameters for score.
	(void)0;
	m_dictISCParams = nil;
	m_dictISCParams = ([self genericParameters]);

	NSString *strRequest = [NSString stringWithFormat:@"%@%@?%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@&%@=%@",
							ISC_MAIN_URL, ISC_PING_SNIP,
							ISC_NAME_DEVICE_TAG,		[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TAG],
							ISC_NAME_KEY,				[m_dictISCParams objectForKey:ISC_NAME_KEY],
							ISC_NAME_DEVICE_TYPE,		[m_dictISCParams objectForKey:ISC_NAME_DEVICE_TYPE],
							ISC_NAME_DEVICE_HARDWARE,	[m_dictISCParams objectForKey:ISC_NAME_DEVICE_HARDWARE],
							ISC_NAME_DEVICE_OS_VERSION, [m_dictISCParams objectForKey:ISC_NAME_DEVICE_OS_VERSION],
							ISC_NAME_APP_NAME,			[m_dictISCParams objectForKey:ISC_NAME_APP_NAME],
							ISC_NAME_APP_VERSION,		[m_dictISCParams objectForKey:ISC_NAME_APP_VERSION],
							ISC_NAME_SCORE,				[m_dictISCParams objectForKey:ISC_NAME_SCORE],
							ISC_NAME_NICKNAME,			[m_dictISCParams objectForKey:ISC_NAME_NICKNAME],
                            ISC_NAME_FACEBOOK,          [m_dictISCParams objectForKey:ISC_NAME_FACEBOOK]
							];

    // Do we have extra stuff?
    if ([strExtra length] > 0)
    {
        strRequest = [NSString stringWithFormat:@"%@&%@", strRequest, strExtra];
    }

	// We don't care about the response, so we won't retain this.
	[self localSendISCRequest:strRequest withRetain:NO];
}

- (void)sendISCPing
{
    [self sendISCPingWithExtra:nil];
}

- (void)sendISCData:(NSData*)postData forFriend:(NSString*)strFriend forKey:(NSString*)strKey withDelegate:(id)idTarget forceSynchronous:(BOOL)fSynch
{
//    int nLength = [postData length];
//    NSLog(@"Data size = %d, Outgoing data = %@", nLength, postData);

    // Get standard params we care about.
    NSDictionary *dictParams = [self genericParameters];

    // Construct our URL.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", ISC_MAIN_URL, ISC_POSTDATA_SNIP]];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];

    // Our standard params.
    [request setPostValue:[dictParams objectForKey:ISC_NAME_DEVICE_TAG] forKey:ISC_NAME_DEVICE_TAG];
    [request setPostValue:[dictParams objectForKey:ISC_NAME_KEY] forKey:ISC_NAME_KEY];
    [request setPostValue:[dictParams objectForKey:ISC_NAME_APP_NAME] forKey:ISC_NAME_APP_NAME];
    if ([strFriend length] < 1)
    {
        // Send in ourselves...
        [request setPostValue:[dictParams objectForKey:ISC_NAME_FACEBOOK] forKey:ISC_NAME_FACEBOOK];
    }
    else
    {
        // Send in our friend...
        [request setPostValue:strFriend forKey:ISC_NAME_FACEBOOK];
    }

    // Our actual data or request.
    if (postData != nil)
    {
        [request setPostValue:postData forKey:strKey];
        [request setDidFinishSelector:@selector(ASIrequestSendPostFinished:)];
        [request setDidFailSelector:@selector(ASIrequestSendPostFailed:)];
    }
    else
    {
        // We just want the existing data.
        [request setPostValue:@"query" forKey:strKey];
        [request setDidFinishSelector:@selector(ASIrequestGetPostFinished:)];
        [request setDidFailSelector:@selector(ASIrequestgetPostFailed:)];
    }

    if (fSynch == NO)
    {
        // And send the request off into the queue.
        if (idTarget == nil)
            [request setDelegate:self];
        else
            [request setDelegate:idTarget];
        [m_queueASI addOperation:request];
        NSLog(@"Done with asynchronous.");
    }
    else
    {
        // Synchronous call -- for when we're suspending, etc.
        [request startSynchronous];
        NSLog(@"Done with synchronous.");
    }
}

- (void)sendISCDataRequestForFriend:(NSString*)strFriend forKey:(NSString*)strKey withDelegate:(id)idTarget
{
    // Pass in nil to our post version.
    return [self sendISCData:nil forFriend:strFriend forKey:strKey withDelegate:idTarget forceSynchronous:NO];
}

- (void)sendISCGetFBFriendFrequest:(NSString*)strFriends withDelegate:(id)idTarget
{
    // Construct our URL.
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", ISC_MAIN_URL, ISC_FBFRIENDS_SNIP]];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];

    // Get standard params we care about.
    NSDictionary *dictParams = [self genericParameters];

    // Our standard params.
    [request setPostValue:[dictParams objectForKey:ISC_NAME_DEVICE_TAG] forKey:ISC_NAME_DEVICE_TAG];
    [request setPostValue:[dictParams objectForKey:ISC_NAME_KEY] forKey:ISC_NAME_KEY];
    [request setPostValue:[dictParams objectForKey:ISC_NAME_APP_NAME] forKey:ISC_NAME_APP_NAME];

    // Our Facebook Friends.
    [request setPostValue:strFriends forKey:ISC_NAME_FACEBOOK_FRIENDS];

    // Specify our non-default selectors.
    [request setDidFinishSelector:@selector(ASIrequestFBFriends:)];

    // And send the request off into the queue.
    if (idTarget == nil)
        [request setDelegate:self];
    else
        [request setDelegate:idTarget];
    [m_queueASI addOperation:request];
}

- (void)sendISCGenericMessage:(NSString *)strRequest
{
    [self localSendISCRequest:strRequest withRetain:YES];
}

#pragma mark -
#pragma mark ISC Local Routines

- (void)requestFinished:(ASIHTTPRequest *)request
{
    // Don't do anything here for now.
    NSLog(@"ASI request finished okay.");
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"ASI Asynch error: %@", error);
}

- (void)ASIrequestSendPostFinished:(ASIHTTPRequest *)request
{
    // Fall through to the default.
    [self requestFinished:request];
}

- (void)ASIrequestSendPostFailed:(ASIHTTPRequest *)request
{
    // Fall through to the default.
    [self requestFailed:request];
}

- (void)ASIrequestGetPostFinished:(ASIHTTPRequest *)request
{
    // Use when fetching text data
    NSString *responseString = [request responseString];

    if ([responseString length] < 1)
    {
        NSLog(@"Asynch request complete; no response.");
        return;
    }

    //    NSLog(@"ASI Asynch Response: %@", responseString);

    int nLength = [responseString length];
//    NSLog(@"  Asynch Response String size = %d, Data = %@", nLength, responseString);
    NSData *dataConverted = [MRUtilities createNSDataFromUTF8EncodedString:responseString];
    nLength = [dataConverted length];
//    NSLog(@"  Converted size = %d, Data = %@", nLength, dataConverted);

    // Use when fetching binary data
    //    NSData *responseData = [request responseData];
}

- (void)ASIrequestGetPostFailed:(ASIHTTPRequest *)request
{
    // Fall through to the default.
    [self requestFailed:request];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == ALERT_TAG_LINK && buttonIndex == 1)
	{
		UIAlertViewURL *alertURL = (UIAlertViewURL*)alertView;
		// Jump somewhere...
		if (alertURL.strURL != nil)
		{
			NSURL *url = [NSURL URLWithString:alertURL.strURL];
			[[UIApplication sharedApplication] openURL:url];
		}
	}
}

- (void)ISCmailReward:(NSString*)strReward
{
	[self mailReward:strReward];
}

- (void)ISCusedReward:(NSString*)strReward
{
	// We match!  Award the credits or whatever.
	[self applyReward:NO];
}

- (void)ISCredeemedRewards:(NSString*)strCount
{
	// This string should be in the format of [number:hash].

	// Split it up into array.
	NSArray *arrElements = [strCount componentsSeparatedByString:@":"];
	if ([arrElements count] != 2)
		return; // Show error here?

	// Get the number as the first element.
	int nValue = [[arrElements objectAtIndex:0] intValue];
	if (nValue < 1)
		return;

	// Our hash has to match.
	NSString *strHash = [self generateValueKey:nValue];
	if ([strHash isEqualToString:[arrElements objectAtIndex:1]] == NO)
	{
		return; // show error?
	}

	// We match!  Award the credits or whatever.
	[self applyReward:YES];
}

- (void)ISCdisplayError:(NSString*)strType withDetails:(NSString*)strDetails
{
	// ZombieSkies -- making everything fail silently for now.
	return;

	if (strType == nil || [strType length] < 1)
		return;

	NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"errors" ofType:@"plist"];
	NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:plistPath];

	// NYI -- get our error information.
	NSDictionary *dictType = [dictionary objectForKey:strType];

	// Create the non-interactive alertview
	NSString *strTitle   = [dictType objectForKey:@"__title__"]; // [NSString stringWithFormat:@"ISC Error - %@", strType];
	if (strTitle == nil)
		strTitle = @"Reward Error";

	id idDelegate = nil;
	BOOL fCanSpend = [[dictType objectForKey:@"Can Spend"] boolValue];
	if (fCanSpend == YES)
	{
		idDelegate = self;
	}

	NSString *strMessage = [dictType objectForKey:strDetails];
	if (strMessage == nil)
	{
		strMessage = @"We're sorry -- something went wrong with your reward transaction.  Try again later, or "
		"contact us at support@inertsoap.com for help.";
	}

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:strTitle
													message:strMessage
												   delegate:idDelegate
										  cancelButtonTitle:@"Okay"
										  otherButtonTitles:nil];
	if (fCanSpend == YES)
	{
//		alert.tag = ALERT_TAG_PURCHASE;
//		[alert addButtonWithTitle:@"Spend 'em!"];
	}

	[alert show];
	(alert);

	(void)0;
//	// Set the RewardsController to ready.
//	RewardsController *rw = [FingerzillaAppDelegate getRewardsController];
//	[rw setBusyMessage:@"" asBusy:NO];
}

- (void)ISCdisplayMessage:(NSString*)strMessage
{
    NSLog(@"ISC Message: %@", strMessage);

	// Explode our string into an array of message details.
	NSArray *arrMessage = [strMessage componentsSeparatedByString:@"::"];

    NSLog(@"Array has %d elements.", [arrMessage count]);

	// To be valid, we must have a certain number of entries.
	if ([arrMessage count] < 9)
	{
		NSLog(@"ISC -- invalid message received.");
		return;
	}

	// Already read by us?
	NSString *strReference = [arrMessage objectAtIndex:0];
	NSString *strSeen = [NSString stringWithFormat:@"ISC_SeenMessage_%@", strReference];
	if ([MRUtilities getContentStatusForKey:strSeen] == YES)
	{
		NSLog(@"ISC -- We've already seen message [%@]", strReference);
		return;
	}

	// Don't show inactive messages.
	NSString *strActive = [arrMessage objectAtIndex:1];
	if ([strActive isEqualToString:@"0"])
	{
		NSLog(@"ISC -- Message [%@] isn't active.", strReference);
		return;
	}

	// Only show debug messages to debug builds.
#ifndef DEBUG
	NSString *strDebug = [arrMessage objectAtIndex:2];
	NSLog(@"Debug is: %@", strDebug);
	if ([strDebug isEqualToString:@"0"] == NO)
	{
		NSLog(@"ISC -- Message [%@] is only for debug builds.", strReference);
		return;
	}
#endif // Non-debug code.

	//	// We may be getting the "Free" version of ourselves, so let's do a specific check
	//	// to make sure.
	//	NSString *strApp = [arrMessage objectAtIndex:3];
	//	if ([strApp isEqualToString:MR_ISC_APP_NAME] == NO)
	//	{
	//		NSLog(@"ISC -- Message [%@] is not really for us, it's for [%@].", strReference, strApp);
	//		return;
	//	}


	// Title and Details.
	NSString *strTitle = [arrMessage objectAtIndex:4];
	NSString *strDetails = [arrMessage objectAtIndex:5];

	// Buttons and URL.
	id idDelegate = self;
	NSString *strActionURL = [arrMessage objectAtIndex:6];
	NSString *strActionTitle = [arrMessage objectAtIndex:7];
	if ([strActionTitle length] < 1 || [strActionURL length] < 1)
	{
		idDelegate = nil;
		strActionTitle = nil;
		strActionURL = nil;
	}
	NSString *strCancelTitle = [arrMessage objectAtIndex:8];
	if (strCancelTitle == nil || [strCancelTitle length] < 1)
		strCancelTitle = @"Okay";
	UIAlertViewURL *alert = [[UIAlertViewURL alloc] initWithTitle:strTitle
														  message:strDetails
														 delegate:idDelegate
												cancelButtonTitle:strCancelTitle
												otherButtonTitles:strActionTitle, nil];
	alert.tag = ALERT_TAG_LINK;
	alert.strURL = strActionURL;
	[alert show];
	(alert);

	// Mark this message as read by us.
	[MRUtilities setContentStatusForKey:strSeen asActive:YES];
}

// This displays a graphical pop-up ad.
// Return YES if we displayed a popup, NO otherwise.
- (BOOL)ISCdisplayPopup:(NSString*)strMessage
{
    NSLog(@"ISC Popup: %@", strMessage);

	// Explode our string into an array of message details.
	NSArray *arrMessage = [strMessage componentsSeparatedByString:@"::"];

    NSLog(@"Popup Array has %d elements.", [arrMessage count]);

	// To be valid, we must have a certain number of entries.
	if ([arrMessage count] < 4)
	{
		NSLog(@"ISC -- invalid popup received.");
		return NO;
	}

	NSString *strReference = [arrMessage objectAtIndex:0];

	// Don't show inactive popups.
	NSString *strActive = [arrMessage objectAtIndex:1];
	if ([strActive isEqualToString:@"0"])
	{
		NSLog(@"ISC -- Popup [%@] isn't active.", strReference);
		return NO;
	}

    // App-checking has already been done by the server.  If we get here, we're for us.

	// Only show debug messages to debug builds.
#ifndef DEBUG
	NSString *strDebug = [arrMessage objectAtIndex:2];
	NSLog(@"Debug is: %@", strDebug);
	if ([strDebug isEqualToString:@"0"] == NO)
	{
		NSLog(@"ISC -- Popup [%@] is only for debug builds.", strReference);
		return NO;
	}
#endif // Non-debug code.

    // Do we have PopupManager in this project?
#ifndef PROJECT_IGNORE_POPUPMANAGER
    PopupManager *popMan = [PopupManager sharedPopupManager];

    // Don't show directly any more.  Instead, add to list of possibilities.
    [popMan addPopupPossibility:strReference];
#endif

//    BOOL fShowed = [popMan displayPopupWithName:strReference];
//    if (fShowed == YES)
//    {
//        NSLog(@"Displayed popup for %@", strReference);
//    }
//    else
//    {
//        NSLog(@"SKIPPED popup for %@", strReference);
//        return NO;
//    }
//
//    return YES;
    return YES;
}

- (void)ISCapplyReward:(NSString*)strReward
{
	// Explode our string into an array of eward details.
	NSArray *arrMessage = [strReward componentsSeparatedByString:@"::"];

	// To be valid, we must have a certain number of entries.
	if ([arrMessage count] < 7)
	{
		NSLog(@"ISC -- invalid REWARD received.");
		return;
	}

	// Already read by us?
	NSString *strReference = [arrMessage objectAtIndex:0];
	NSString *strSeen = [NSString stringWithFormat:@"ISC_SeenReward_%@", strReference];
	if ([MRUtilities getContentStatusForKey:strSeen] == YES)
	{
		NSLog(@"ISC -- We've already been rewarded for [%@]", strReference);
		return;
	}

	// Don't show claimed rewards.
	NSString *strClaimed = [arrMessage objectAtIndex:2];
	if ([strClaimed isEqualToString:@"1"])
	{
		NSLog(@"ISC -- Reward [%@] is marked claimed.", strReference);
		return;
	}

    // Kinda-hack: we'll ignore some messages by their ID, because we
    // no longer want this version to honor them.
    if ([strReference isEqualToString:@"24"])
    {
        // Version 5+ are not granting 1,000 tokens -- instead, we're
        // awarding these at game-install, not via network.
        NSLog(@"ISC -- ignoring old 1,000 tokens for v5+.");
        [MRUtilities setContentStatusForKey:strSeen asActive:YES];
        return;
    }

	// Grant the reward.
	int nValue = [[arrMessage objectAtIndex:6] integerValue];
    [MRCurrencyStore adjustCurrency:MR_CURRENCY_FOR_UNLOCK withDelta:nValue];

	// Title and Details.
	NSString *strTitle = [arrMessage objectAtIndex:3];
	NSString *strDetails = [arrMessage objectAtIndex:4];

	// Show our reward message.
	UIAlertView *alert = [[UIAlertViewURL alloc] initWithTitle:strTitle
                                                       message:strDetails
                                                      delegate:nil
                                             cancelButtonTitle:@"Okay"
                                             otherButtonTitles:nil];
	alert.tag = ALERT_TAG_NONE;
	[alert show];
	(alert);

	// Mark this reward as read by us.
	[MRUtilities setContentStatusForKey:strSeen asActive:YES];
}

#pragma mark -
#pragma mark ASYNC XML Parsing

- (void)connection:(NSURLConnection *) myConnection didReceiveData:(NSData *) myData
{
	if (m_dataISC)
	{
        if (![m_dataISC isKindOfClass: [NSMutableData class]])
		{
            m_dataISC = [m_dataISC mutableCopy];
            (void)0;
        }

        [(NSMutableData *) m_dataISC appendData: myData];
    }
	else
	{
        m_dataISC = [myData mutableCopy];
    }
}

- (void)connection:(NSURLConnection *) myConnection didFailWithError:(NSError *) myError
{
	NSLog(@"ISC -- connection failed.");
	(void)0;
	m_connectionISC = nil;

	// Inform the player.
	[self ISCdisplayError:@"ConnectionFailed" withDetails:@"CannotReach"];

//	// Make sure our screen isn't busy.
//	RewardsController *rwController = [FingerzillaAppDelegate getRewardsController];
//	[rwController setBusyMessage:@"" asBusy:NO];
}

- (int)sendISCQueuedIfIdle
{
    // If we have an active connection, don't do anything.
    if (m_connectionISC != nil)
        return 0;

	// Do we have any queued requests to send?
	int nCount = [m_arrQueuedRequests count];
	if (nCount > 0)
	{
		NSString *strRequest = [[m_arrQueuedRequests objectAtIndex:0] copy];
		[m_arrQueuedRequests removeObjectAtIndex:0];
		[self localSendISCRequest:strRequest withRetain:YES];
        return nCount;
	}
    return 0;
}

- (void)setISCRequestDelegate:(id <ISCRequestDelegate>)idDelegate
{
    m_idISCRequestDelegate = idDelegate;
}

- (void)connectionDidFinishLoading:(NSURLConnection *) myConnection
{
	[self startParsing:m_dataISC];
	(void)0;
	m_connectionISC = nil;

    int nCount = [self sendISCQueuedIfIdle];
    if (nCount > 0)
    {
        NSLog(@"ISC -- %d queued requests, so chaining.", nCount);
    }
}

- (void)startParsing:(NSData *) myData
{
	// Get XML as NSData.
    NSData *xmlData = myData;
    NSXMLParser *parser = ([[NSXMLParser alloc] initWithData:xmlData]);
    [parser setDelegate:self];
    [parser parse];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	m_strCurrentXMLElement = elementName;
//NSLog(@"ISC Parse: Element = %@, nameSpace = %@, qualifiedName = %@", elementName, namespaceURI, qualifiedName);

	// If we're in a network that is redirecting us, giving us real HTML for a login page,
	// stop now.
	if ([elementName isEqualToString:@"html"] || [elementName isEqualToString:@"HTML"])
	{
		if (m_connectionISC != nil)
		{
			[self ISCdisplayError:@"ConnectionBusy" withDetails:@"ProxyServer"];
		}
//		RewardsController *rwController = [FingerzillaAppDelegate getRewardsController];
//		[rwController setBusyMessage:@"" asBusy:NO];
		[self localStopParsing:parser];
	}

	//	if ([elementName isEqualToString:@"CouponFailed"])
	//	{
	//		[[NSNotificationCenter defaultCenter] postNotificationName:ISC_COUPON_FAILED object:nil];
	//	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
//NSLog(@"ISC Found String: %@", string);
	int nLengthString = [string length];

    MRSceneHost *appAss = [MRSceneHost sharedAppDelegate];

	// We asked for a new coupon -- success or failure.
	if([m_strCurrentXMLElement isEqualToString:@"RequestCouponSuccess"] && nLengthString > 4)
	{
//		NSLog(@"Zombie - ISC Coupon Success: %@.", string);
		[self ISCmailReward:string];
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RequestCouponFailed"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Request Coupon Failure: %@", string);
		[self ISCdisplayError:m_strCurrentXMLElement withDetails:string];
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"UseCouponSuccess"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Use Coupon Success: %@", string);
		[self ISCusedReward:string];
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"UseCouponFailed"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Use Coupon Failure: %@", string);
		[self ISCdisplayError:m_strCurrentXMLElement withDetails:string];
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"ClearCouponSuccess"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Clear Coupon Success: %@", string);
		[self ISCdisplayError:m_strCurrentXMLElement withDetails:string];
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RedeemOwnCouponSuccess"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Redeem Coupons Success: %@", string);
		[self ISCredeemedRewards:string];
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RedeemOwnCouponFailed"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Redeem Coupons Failure: %@", string);
		// We're going to silently fail here, rather than be chatty.
		// Means we need to clear RW display ourselves.
//		RewardsController *rwController = [FingerzillaAppDelegate getRewardsController];
//		[rwController setBusyMessage:@"" asBusy:NO];
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RequestFriendsSuccess"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Request Friends Success: %@", string);
        if ([appAss respondsToSelector:@selector(friendsClear)])
            [appAss performSelector:@selector(friendsClear)];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RequestFriendsFailed"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Request Friends Failure: %@", string);
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"FriendEntry"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Friend Entry: %@", string);
		NSArray *arrFriend = [string componentsSeparatedByString:@":"];
		// If someone has put a ":" in their nickname, they only get the first portion.  So be it.
		if ([arrFriend count] >= 2)
		{
            if ([appAss respondsToSelector:@selector(friendsAdd::)])
            {
                [appAss performSelector:@selector(friendsAdd::) withObject:[arrFriend objectAtIndex:0] withObject:arrFriend];
            }
			//NSLog(@"  ISC: added friend %@ (id %@)", [arrFriend objectAtIndex:1], [arrFriend objectAtIndex:0]);
		}
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RequestAppsSuccess"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Request Apps Success: %@", string);
        if ([appAss respondsToSelector:@selector(appsClear)])
            [appAss performSelector:@selector(appsClear)];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RequestAppsFailed"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Request Apps Failure: %@", string);
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"AppEntry"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC App Entry: %@", string);
		if ([string length] >= 2)
		{
            if ([appAss respondsToSelector:@selector(appsAdd:)])
                [appAss performSelector:@selector(appsAdd:) withObject:string];
			//NSLog(@"  ISC: added app %@", string);
		}
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RequestMessagesFailed"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Request Messages Failure: %@", string);
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"MessageEntry"] && nLengthString > 4)
	{
		//NSLog(@"Zombie -- ISC Message Entry: %@", string);
		if ([string length] >= 2)
		{
			// Go show this message right now.
			[self ISCdisplayMessage:string];
			// NYI -- shall we stop parsing after first new message? Would have to go in subfunction.
		}
	}
    else if ([m_strCurrentXMLElement isEqualToString:@"RequestPopupsFailed"])
    {
        [self localStopParsing:parser];
    }
    else if ([m_strCurrentXMLElement isEqualToString:@"PopupsEntry"] && nLengthString > 4)
    {
        // We don't actually show them instantly any more; instead, we'll add them
        // to a list.
        [self ISCdisplayPopup:string];
//        BOOL fShowed = [self ISCdisplayPopup:string];
//        // If we showed something, don't try to show anybody else!
//        if (fShowed == YES)
//            [self localStopParsing:parser];
    }
	else if ([m_strCurrentXMLElement isEqualToString:@"RequestRewardsFailed"] && nLengthString > 4)
	{
        //		NSLog(@"Fingerzilla -- ISC Request Rewards Failure: %@", string);
		[self localStopParsing:parser];
	}
	else if ([m_strCurrentXMLElement isEqualToString:@"RewardEntry"] && nLengthString > 4)
	{
        //		NSLog(@"Fingerzilla -- ISC Reward Entry: %@", string);
		if ([string length] >= 2)
		{
			// Go apply this reward right now.
			[self ISCapplyReward:string];
			// NYI -- shall we stop parsing after first new message? Would have to go in subfunction.
		}
	}
    else if ([m_strCurrentXMLElement isEqualToString:@"FBFriendsSuccess"])// && nLengthString > 4)
    {
#ifdef PROJECT_USE_FBMANAGER
        SEL selGameFriends = @selector(facebookSetGameFriends:);
        if ([m_idFacebookCallbackOb respondsToSelector:selGameFriends])
        {
            [m_idFacebookCallbackOb performSelector:selGameFriends withObject:string];

            // Now fetch their pictures
            NSArray *arrFriends = [string componentsSeparatedByString:@"|"];
            for (NSString *strFriend in arrFriends)
            {
                NSString *strUsername = [strFriend stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSString *strRequest = [NSString stringWithFormat:@"%@/picture", strUsername];
                [[MRSocialService sharedFBManager] requestWithGraphPath:strRequest];
            }
        }
        else
        {
            // Just log it for now.
            NSLog(@"Got matching game friends of %@", string);
        }
#endif
    }
    else
    {
        if (m_idISCRequestDelegate != nil && [m_idISCRequestDelegate respondsToSelector:@selector(ISCDidReceiveElement:withContent:)] == YES)
        {
            [m_idISCRequestDelegate performSelector:@selector(ISCDidReceiveElement:withContent:) withObject:m_strCurrentXMLElement withObject:string];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	//NSLog(@"ISC Ending Element: %@", elementName);
	int nLengthString = [elementName length];
	if ([elementName isEqualToString:@"RequestFriendsSuccess"] && nLengthString > 4)
	{
		// We're done with a friends list ... notify someone if we want.
		//NSLog(@"ISC -- done with friends!");
//		StatsScene *statsScene = (StatsScene*)[CCDirector sharedDirector].runningScene;
//		if ([statsScene isKindOfClass:[StatsScene class]])
//		{
//			[statsScene updateFriends];
//		}
	}
	else if ([elementName isEqualToString:@"RequestAppsSuccess"] && nLengthString > 4)
	{
		// We're done with apps ... go see if we need to reward the player.
		//NSLog(@"ISC -- done with apps!");
		MRSceneHost *appDel = [MRSceneHost sharedAppDelegate];
        if ([appDel respondsToSelector:@selector(appsReward)])
            [appDel performSelector:@selector(appsReward)];
	}

	m_strCurrentXMLElement = nil;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	//NSLog(@"Finished parsing.");
}

#pragma mark -
#pragma mark In-App Purchase
//
// In-App Purchase Store stuff.
//

- (void)initInApp
{
    // Make us a transaction observer.
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];

	m_idPaymentCallbackOb = nil;
	m_prodRequest = nil;
	m_prodResponse = nil;
	m_callBackOb = nil;

    // Hack -- test.
//    SKProductsRequest *request= [[SKProductsRequest alloc] initWithProductIdentifiers: [NSSet setWithObjects: @"Fingerzilla_LP", @"fz_currency_0", nil]];
//    request.delegate = self;
//    [request start];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	for (SKPaymentTransaction *transaction in transactions)
	{
		switch (transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
				[self completeTransaction:transaction];
				break;
			case SKPaymentTransactionStateFailed:
				[self failedTransaction:transaction];
				break;
			case SKPaymentTransactionStateRestored:
				[self restoreTransaction:transaction];
			default:
				break;
		}
		[self notifyPurchaseofTransaction:transaction];
	}
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction
{
	if (transaction.error.code != SKErrorPaymentCancelled)
	{
		// Optionally, display an error here.
		NSLog(@"Failed [%@] for unknown reason [%@].", transaction.payment.productIdentifier, transaction.error);
        if ([m_callBackOb respondsToSelector:@selector(inAppTransactionFailed:)])
        {
            [m_callBackOb performSelector:@selector(inAppTransactionFailed:) withObject:transaction];
        }
	}
	else
	{
		NSLog(@"Failed -- cancelled payment.");
	}
	[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void) restoreTransaction: (SKPaymentTransaction *)transaction
{
	// Fall through so we're synchronized.
	[self completeTransaction:transaction];
}

- (void) completeTransaction: (SKPaymentTransaction *)transaction
{
	//Provide the new content
    NSLog(@"InApp -- completeTransaction!");
    if ([m_callBackOb respondsToSelector:@selector(inAppTransactionComplete:)])
    {
        [m_callBackOb performSelector:@selector(inAppTransactionComplete:) withObject:transaction];
    }
    else
    {
        [MRUtilities setContentStatusForKey:transaction.payment.productIdentifier asActive:YES];
    }

	[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)attemptPaymentWithProductIdentifier:(NSString *)strID callBackOb:(id)idCallback
{
    // Can we even submit payments?
    if ([SKPaymentQueue canMakePayments] == NO)
    {
        NSLog(@"In-App: Cannot Make Payments.");
        return;
    }

    // Go through and find the matching product for this identifier.
    SKProduct *product = [self getProductForID:strID];
    if (product != nil)
    {
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        m_idPaymentCallbackOb = idCallback;
        NSLog(@"Attempting Purchase of [%@]", strID);
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)notifyPurchaseofTransaction:(SKPaymentTransaction *)transaction
{
	// Just tell our Purchase Screen about this, so it can update itself, etc.
	if (m_idPaymentCallbackOb != nil)
		[m_idPaymentCallbackOb performSelector:@selector(showInProgress:) withObject:transaction];
	//		[m_idPaymentCallbackOb showInProgress:transaction];
}

// Purchasing response delegate
#pragma mark -
#pragma mark Purchasing Response Delegate

- (void)createRequest:(NSMutableSet *)setPacks callBackOb:(id)idOb selector:(SEL)selCallBack
{
    NSLog(@"At start of createRequest.");

    // Let's not do this if we have a pending request.
    if (m_prodRequest != nil)
    {
        NSLog(@"inApp: We have a pending product request, so not sending a new request.");
        return;
    }

	m_callBackOb = idOb;
	m_callBackSelector = selCallBack;
	// Tom says: I think this part is caching response from earlier request, to be faster?
	//	if (m_prodRequest != nil)
	//	{
	//		[m_callBackOb performSelector:m_callBackSelector];
	//		return;
	//	}

	// Clear any old response.
	(void)0;
	m_prodResponse = nil;

    (void)0;
    m_prodRequest = nil;

	m_prodRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:setPacks];
	m_prodRequest.delegate = self;
	[m_prodRequest start];


    NSLog(@"At end of createRequest.");
}

- (void)cancelRequest
{
	// Just get rid of our various objects.
	m_callBackOb = nil;
	m_callBackSelector = nil;

    (void)0;
    m_prodRequest = nil;
    (void)0;
    m_prodResponse = nil;
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    (void)0;
    m_prodResponse = nil;

	m_prodResponse = (response);

	[m_callBackOb performSelector:m_callBackSelector];

    // Hack test.
    NSArray *arrItems = response.products;
    for (SKProduct *product in arrItems)
    {
        NSLog(@"--Got product: [%@]", product.productIdentifier);
    }
    arrItems = response.invalidProductIdentifiers;
    for (NSString *strProduct in arrItems)
    {
        NSLog(@"--Failed product: [%@]", strProduct);
    }

    // Clear our request?
    (void)0;
    m_prodRequest = nil;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
	NSLog(@"Store request failed.");

    (void)0;
    m_prodRequest = nil;

//	[request autorelease];
}

- (SKProductsResponse*)getStoreResponse
{
	return m_prodResponse;
}

- (SKProduct *)getProductForID:(NSString*)strID
{
    for (SKProduct *prodValid in m_prodResponse.products)
    {
        NSString *strProdID = prodValid.productIdentifier;
        if ([strID isEqualToString:strProdID])
            return prodValid;
    }

    // Didn't find it!
    return nil;
}

#pragma mark -
#pragma mark Rewards & eMail

- (void)mailReward:(NSString*)strReward
{
	if (strReward == nil || [strReward length] < 1)
		return;

	// Need to get the game controller for this.
	UIViewController *gcGame = [MRSceneHost getGameController];
	if (gcGame == nil)
		return;

	if ([MFMailComposeViewController canSendMail] == NO)
		return;

	MFMailComposeViewController *vcMail = [[MFMailComposeViewController alloc] init];

	NSString *strBody = [NSString stringWithFormat:@"I'm sending you a coupon for a free Crystal Pack for the iPad game Everybody Hates NASA.\n"
						 "If you don't have the game yet, you can get it <a href=\"http://itunes.apple.com/us/app/everybody-hates-nasa/id385791182?mt=8\">here.</a>"
						 "(I'll also get a free Crystal Pack!)"
						 "<br><br>Your coupon code is: %@", strReward];

	[vcMail setSubject:@"Free \"Everybody Hates NASA\" Reward"];
	[vcMail setMessageBody:strBody isHTML:YES];

	[gcGame presentModalViewController:vcMail animated:YES];
	(vcMail);
	vcMail.mailComposeDelegate = gcGame;
}

- (void)applyReward:(BOOL)fWasMine
{
	// Right now we'll just give you some crystals.
	static const int scnNumCrystals = 250;

	// Add it to our total.
	[MRCurrencyStore adjustCurrency:MR_CURRENCY_FOR_UNLOCK withDelta:scnNumCrystals];

	// Display a message.
	[self ISCdisplayError:@"UseCouponSuccess" withDetails:@"UsedCode"];

	// Update our friends list.
	[self sendISCGetFriendRequest];

	//	NSString *strMessage = nil;
	//	if (nValue == 1)
	//		strMessage = @"Congratulations!\n\nYour friend has used your Reward, and you have earned a credit!";
	//	else
	//		strMessage = [NSString stringWithFormat:@"Congratulations!\n\nYour friends have used your Rewards, and you have earned %d credits!",
	//					  nValue];
	//
	//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Free Credits!"
	//													message:strMessage
	//												   delegate:self
	//										  cancelButtonTitle:@"Okay"
	//										  otherButtonTitles:@"Spend 'em!", nil];
	//	alert.tag = ALERT_TAG_PURCHASE;
	//	[alert show];
	//	[alert autorelease];
	//
	//	// Set the RewardsController to ready.
	//	[rwController setBusyMessage:@"" asBusy:NO];

}

#pragma mark -
#pragma mark Game Center

- (void) GCinit
{
	// Store our GC state for fast checking.
	[self GCisAvailableSlow];

	// We're not authenticated yet.
	m_fLocalPlayerAuthenticated = NO;

	m_arrLeaderboardNames = nil;
	m_arrLeaderboardCategories = nil;

	m_arrDistanceScores  = nil;
	m_dictDistancePlayers = nil;
	m_fDistancesLoaded   = NO;

	m_arrLeaderboardRankRequests = [[NSMutableArray alloc] initWithCapacity:16];
    m_arrLeaderboardRequestsPending = ([NSMutableArray arrayWithCapacity:5]);
	m_leaderboardRequestForDistance = nil;

	// Set up a notification for when the player changes while we're backgrounded.
	if ([self GCisAvailable] == YES)
	{
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver: self
			   selector:@selector(GClocalAauthenticationChanged)
				   name:GKPlayerAuthenticationDidChangeNotificationName
				 object:nil];
	}

    NSString *path = [MRBundleResources pathForResource:@"OFGameCenter.plist"];
	m_dictOFtoGC = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] mutableCopy];
}
- (void) GClocalAauthenticationChanged
{
	if ([self GCisAvailable] == NO)
		return;

    if ([GKLocalPlayer localPlayer].isAuthenticated)
	{
        // Insert code here to handle a successful authentication.
		m_fLocalPlayerAuthenticated = YES;
	}
	else
	{
		// Insert code here to clean up any outstanding Game Center-related classes.
		m_fLocalPlayerAuthenticated = NO;
	}
}

// We'll only do the full check once, since it won't change per-run.
- (BOOL) GCisAvailableSlow
{
    // Check for presence of GKLocalPlayer API.
    Class gcClass = (NSClassFromString(@"GKLocalPlayer"));

    // The device must be running running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);

	m_fIsGCAvailable = (gcClass && osVersionSupported);
    return m_fIsGCAvailable;
}

- (BOOL)GCisAvailable
{
	return m_fIsGCAvailable;
}

- (BOOL) GCisAuthenticated
{
	return m_fLocalPlayerAuthenticated;
}

- (void) GCauthenticateLocalPlayer
{
	if ([self GCisAvailable] == NO)
		return;

	// Any time we call this, reset our authenticated status.
	m_fLocalPlayerAuthenticated = NO;

    [[GKLocalPlayer localPlayer] authenticateWithCompletionHandler:^(NSError *error) {
		if (error == nil)
		{
			// Insert code here to handle a successful authentication.
			NSLog(@"GameCenter -- authenticated player!");
			m_fLocalPlayerAuthenticated = YES;
			// Make sure we've copied in the alias/nickname.
			self.nickname = [GKLocalPlayer localPlayer].alias;
			// Look up our leaderboard information now.
			[self GCloadLeaderboardCategories];
//			[self GCloadNextDistanceBatch];
		}
		else
		{
			// Your application can process the error parameter to report the error to the player.
			NSLog(@"GameCenter -- FAILED to authenticate with error %@", error);
			m_fLocalPlayerAuthenticated = NO;
		}
	}];
}

- (void) GCreportScore:(Float64)flScore forCategory:(NSString*)strCategory
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

    GKScore *scoreReporter = ([[GKScore alloc] initWithCategory:strCategory]);
    scoreReporter.value = flScore;

    [scoreReporter reportScoreWithCompletionHandler:^(NSError *error)
	{
		if (error != nil)
		{
            // handle the reporting error
			NSLog(@"GameCenter -- unable to report score! Score will be updated next time we complete a level.");
        }
		else
		{
			[self GCloadRank:strCategory];
			NSLog(@"GameCenter -- successfully reported score!");
		}
    }];
}

- (void) GCshowLeaderboard
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

    GKLeaderboardViewController *leaderboardController = [[GKLeaderboardViewController alloc] init];
    if (leaderboardController != nil)
    {
		UIViewController *gcGame = [MRSceneHost getGameController];
        leaderboardController.leaderboardDelegate = gcGame;
        [gcGame presentModalViewController: leaderboardController animated: YES];
    }
}

- (void) GCshowLeaderboardWithBoard:(NSString*)strLeaderboard
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

    GKLeaderboardViewController *leaderboardController = [[GKLeaderboardViewController alloc] init];
    if (leaderboardController != nil)
    {
		UIViewController *gcGame = [MRSceneHost getGameController];
        leaderboardController.leaderboardDelegate = gcGame;
		leaderboardController.category = strLeaderboard;
        [gcGame presentModalViewController: leaderboardController animated: YES];
    }
}

- (void) GCreportAchievementIdentifier:(NSString*)strAchievement percentComplete:(float)flPercent
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

    GKAchievement *achievement = ([[GKAchievement alloc] initWithIdentifier: strAchievement]);
    if (achievement)
    {
		achievement.percentComplete = flPercent;
        // Completion banner doesn't exist in 4.3.  Thus this stupidity:
        NSString *key = @"showsCompletionBanner";
        NSString *setterStr = [NSString stringWithFormat:@"set%@%@:",
                               [[key substringToIndex:1] capitalizedString],
                               [key substringFromIndex:1]];

        if ([achievement respondsToSelector:NSSelectorFromString(setterStr)])
        {
//            NSLog(@"found the setter!");
            achievement.showsCompletionBanner = YES;
        }
		[achievement reportAchievementWithCompletionHandler:^(NSError *error)
		 {
			 if (error != nil)
			 {
                 NSLog(@"reportAchievement Error: [%@] failed with %@", strAchievement, [error localizedDescription]);
				 // Retain the achievement object and try again later (not shown).
			 }
             else
             {
                 NSLog(@"reportAchievement for [%@] successful!", strAchievement);
             }
		 }];
    }
}

- (void) GCshowAchievements
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

    GKAchievementViewController *achievements = [[GKAchievementViewController alloc] init];
    if (achievements != nil)
    {
		UIViewController *gcGame = [MRSceneHost getGameController];
        achievements.achievementDelegate = gcGame;
        [gcGame presentModalViewController: achievements animated: YES];
    }
    (void)0;
}

- (NSString*) GCgetAlias
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return nil;

	GKLocalPlayer *lp = [GKLocalPlayer localPlayer];
	return lp.alias;
}

- (NSString*) GCgetLeaderboardCurrentForType:(NSString*)strStyle
{
	// Get the current set and mission.
    MRPersistentCounters *misc = [MRPersistentCounters sharedMiscManager];
	int nSet = misc.nSet;
	int nMission = misc.nMission;

	// Hacky .. These both need a +1...
	nSet += 1;
	nMission += 1;

	MRUtilities *utilsMan = [MRUtilities sharedUtilityManager];
	if (utilsMan.eGameplayMode == EGM_MULTI)
	{
		// Our leaderboard is {game}.set{N}_campaign.{style}
		NSString *strLeaderboard = [NSString stringWithFormat:@"%@.set%d_campaign.%@", MR_GAME_NAME, nSet, strStyle];
		return strLeaderboard;
	}
	else
	{
		// Our leaderboard is {game}.set{N}_mission{M}.{style}
		NSString *strLeaderboard = [NSString stringWithFormat:@"%@.set%d_mission%d.%@", MR_GAME_NAME, nSet, nMission, strStyle];
		return strLeaderboard;
	}
}

- (void) GCloadLeaderboardCategories
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

	[GKLeaderboard loadCategoriesWithCompletionHandler:^(NSArray *categories, NSArray *titles, NSError *error) {
        if (error != nil)
        {
            // handle the error
			NSLog(@"GameCenter -- Unable to load leaderboards");
			return;
        }
        // use the category and title information
		// Clear any old data in our arrays...
		(void)0;
		m_arrLeaderboardNames = nil;
		(void)0;
		m_arrLeaderboardCategories = nil;

		// Copy in the data for local storage (could we keep a ref to it? Don't know).
		m_arrLeaderboardNames = ([titles copy]);
		m_arrLeaderboardCategories = ([categories copy]);
//		[self GCloadRanks];
	}];

}

- (const int *)getRanks
{
	return m_nRanks;
}

- (void)attemptAchievement:(NSString *)strAch
{
    [self attemptAchievement:strAch withValue:1 withRequirement:1 allowPartial:NO];
}

- (void)attemptAchievement:(NSString *)strAch withValue:(int)nValue withRequirement:(int)nReq allowPartial:(BOOL)fAllowPartial
{
    float flPercent = 1.0f;
    if (fAllowPartial == YES)
    {
        flPercent = nValue / (float)nReq;
    }
    else
    {
        if (nValue < nReq)
            return;
    }
    NSDictionary *dictAchievements = [m_dictOFtoGC objectForKey:@"Achievements"];
    NSString *strGCAch = [dictAchievements objectForKey:strAch];
    [self GCreportAchievementIdentifier:strGCAch percentComplete:flPercent];
}

- (void)setHighScore:(int)nLifetime forLeaderboard:(NSString *)strLeaderboard
{
    NSDictionary *dictLeaderboards = [m_dictOFtoGC objectForKey:@"Leaderboards"];
    NSString *strGCLeaderboard = [dictLeaderboards objectForKey:strLeaderboard];
    if (strGCLeaderboard != nil)
        [self GCreportScore:nLifetime forCategory:strGCLeaderboard];
    else
    {
        NSLog(@"Loeaderboards: %@", dictLeaderboards);
        NSLog(@"Warning: Leaderboard %@ is not listed in OFGameCenter.plist and has no GameCenter counterpart.", strLeaderboard);
    }
}


- (void)localGCSendRankRequest:(NSString *)strLeaderboard
{
	NSArray *arrLocalPlayer = [NSArray arrayWithObject:[GKLocalPlayer localPlayer].playerID];

    if (m_arrLeaderboardRequestsPending == nil)
        m_arrLeaderboardRequestsPending = ([NSMutableArray arrayWithCapacity:5]);

	GKLeaderboard *leaderboardRequestForRank = ([[GKLeaderboard alloc] initWithPlayerIDs:arrLocalPlayer]);
	if (leaderboardRequestForRank != nil)
	{
		leaderboardRequestForRank.category = strLeaderboard;
		leaderboardRequestForRank.playerScope = GKLeaderboardPlayerScopeGlobal;
		leaderboardRequestForRank.timeScope = GKLeaderboardTimeScopeAllTime;
        [m_arrLeaderboardRequestsPending addObject:leaderboardRequestForRank];
		[leaderboardRequestForRank loadScoresWithCompletionHandler: ^(NSArray *scores, NSError *error)
		 {
			 if (error != nil)
			 {
				 // For now, we don't care if we can't get a batch of distance scores.
				 NSLog(@"Error %@ on request for leaderboard %@.", error, strLeaderboard);
			 }
			 if (scores != nil && [scores count] > 0)
			 {
#ifdef DEBUG
				 NSLog(@"GC -- got %d new rank entries.", [scores count]);
#endif
				 GKScore *scoreOb = [scores objectAtIndex:0];
				 int nIndex = 0;
				 for (NSString *strLeaderboard in m_arrLeaderboardCategories)
				 {
					 if ([strLeaderboard isEqualToString:scoreOb.category] == YES)
						 break;
					 nIndex++;
				 }
				 m_nRanks[nIndex] = scoreOb.rank;
				 NSString *strRankPref = [NSString stringWithFormat:@"RANK|%@", strLeaderboard];
				 [MRUtilities setContentIntForKey:strRankPref withInt:scoreOb.rank];

			 }
			 else
			 {
				 int nIndex = [m_arrLeaderboardCategories indexOfObject:strLeaderboard];
				 if (nIndex >= 0)
				 {
					 m_nRanks[nIndex] = 0;
				 }
				 NSString *strRankPref = [NSString stringWithFormat:@"RANK|%@", strLeaderboard];
				 [MRUtilities setContentIntForKey:strRankPref withInt:0];
			 }

			 // We're done with leaderboard request.
#ifdef DEBUG
			 NSLog(@"GC -- clearing old RANK request.");
#endif
//			 [m_leaderboardRequestForRank release];
//			 m_leaderboardRequestForRank = nil;

             [m_arrLeaderboardRequestsPending removeObject:leaderboardRequestForRank];

			 // Do we have a queued request?
			 if ([m_arrLeaderboardRankRequests count] > 0)
			 {
				 NSString *strLeaderboard = [m_arrLeaderboardRankRequests objectAtIndex:0];
//				 NSLog(@"GC -- sending queued Rank request or [%@] (%d pending).", strLeaderboard, [m_arrLeaderboardRankRequests count]);
				 [self localGCSendRankRequest:strLeaderboard];
				 [m_arrLeaderboardRankRequests removeObjectAtIndex:0];
			 }

		 }];
	}
}

- (void)GCloadRank:(NSString *)strLeaderboard
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

	// If we already have one pending, add to the queue to request later.
	if ([m_arrLeaderboardRequestsPending count] == 0)
	{
#ifdef DEBUG
		NSLog(@"GC -- queuing rank request, outstanding.");
#endif
		[m_arrLeaderboardRankRequests addObject:strLeaderboard];
	}
	else
	{
#ifdef DEBUG
		NSLog(@"GC -- sending rank request.");
#endif
		[self localGCSendRankRequest:strLeaderboard];
	}
}

- (void)GCloadRanks
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

	int nIndex = 0;
	for (NSString *strLeaderboard in m_arrLeaderboardCategories)
	{
		NSString *strRankPref = [NSString stringWithFormat:@"RANK|%@", strLeaderboard];
		m_nRanks[nIndex] =  [MRUtilities getContentIntForKey:strRankPref];
		nIndex++;

		[self GCloadRank:strLeaderboard];
	}
}


- (void)GCClearOldDistancesData
{
	(void)0;
	m_arrDistanceScores = nil;
	(void)0;
	m_dictDistancePlayers = nil;
	m_fDistancesLoaded = NO;
}

- (void)GCloadNextDistanceBatch
{
	if ([self GCisAvailable] == NO || [self GCisAuthenticated] == NO)
		return;

	m_fDistancesLoaded = NO;

	// If we have an outstanding leaderboard request, don't do anything?
	if (m_leaderboardRequestForDistance != nil)
	{
		NSLog(@"GClNDB -- leaderboard request pending!");
		return;
	}
	NSLog(@"GC -- asking for next distance batch.");

	// Get our distance board...
	NSString *strLeaderboard = [self GCgetLeaderboardCurrentForType:@"distance"];

	m_leaderboardRequestForDistance = [[GKLeaderboard alloc] init];
    if (m_leaderboardRequestForDistance != nil)
    {
		m_leaderboardRequestForDistance.category = strLeaderboard;
		m_leaderboardRequestForDistance.playerScope = GKLeaderboardPlayerScopeGlobal;
        m_leaderboardRequestForDistance.timeScope = GKLeaderboardTimeScopeAllTime;
		// NYI -- determine which range we want.
        m_leaderboardRequestForDistance.range = NSMakeRange(1,100);
        [m_leaderboardRequestForDistance loadScoresWithCompletionHandler: ^(NSArray *scores, NSError *error) {
            if (error != nil)
            {
				// For now, we don't care if we can't get a batch of distance scores.
            }
            if (scores != nil)
            {
				NSLog(@"GameCenter -- got %d distance scores!", [scores count]);
				// Get rid of any old data.
				[self GCClearOldDistancesData];

				// If we got any valid scores, copy them into our local mutable array.
				if ([scores count] > 0)
				{
					m_arrDistanceScores = ([NSMutableArray arrayWithArray:scores]);

					// Now we also need to get the player information before we can consider ourselves fully loaded.
					NSMutableArray *arrIDs = [NSMutableArray arrayWithCapacity:[m_arrDistanceScores count]];
					for (GKScore *score in scores)
					{
						[arrIDs addObject:score.playerID];
					}
					[GKPlayer loadPlayersForIdentifiers:arrIDs withCompletionHandler:^(NSArray *players, NSError *error) {
						if (error != nil)
						{
							// Didn't work.  Remove any old data.
							[self GCClearOldDistancesData];
						}
						if (players != nil)
						{
//							NSLog(@"GameCenter -- got %d matching distance players!", [players count]);
							// Store these in a copied dictionary as well...
							(void)0;
							m_dictDistancePlayers = nil;
							m_dictDistancePlayers = ([NSMutableDictionary dictionaryWithCapacity:[players count]]);
							for (GKPlayer *playerNew in players)
							{
//								NSLog(@"  Trying to add player [%@]", playerNew);
								if ([playerNew.playerID isEqualToString:@"G: ANONYMOUS"] == NO)
								{
//									NSLog(@"Player is %@.", playerNew.playerID);
									[m_dictDistancePlayers setObject:playerNew forKey:playerNew.playerID];
								}
							}
//							NSLog(@"GC -- ended with %d players.", [m_dictDistancePlayers count]);

							// ...And mark that we're finally ready to report.
							m_fDistancesLoaded = YES;
						}
					}];
				}
            }
			// Get rid of the old leaderboard request now.
			NSLog(@"GClNDB -- clearing old leaderboard request!");
			(void)0;
			m_leaderboardRequestForDistance = nil;
		}];
	}

}

+ (id) createNSDataFromUTF8EncodedString:(NSString *) string
{
	NSMutableData *mutableData = nil;

	if( string )
	{
		unsigned long lentext = 0;
		const unsigned char *ch = 0;
		NSData *base16Data = nil;
		const unsigned char *base16Bytes = nil;

		// Convert the string to UTF8 data.
		base16Data = [string dataUsingEncoding:NSUTF8StringEncoding];
		base16Bytes = [base16Data bytes];
		mutableData = [NSMutableData dataWithCapacity:[base16Data length]];
		lentext = [base16Data length];

		ch = base16Bytes;
		while( YES )
		{
			if ( ch - base16Bytes >= lentext )
                break;

            // We may be done with the final '>'
            if (*ch == '>')
                break;

			unsigned char cByte = 0;

			for (int i = 0; i < 2; i++)
			{
				unsigned char cNibble = 0;
				cByte = cByte << 4;
				while (*ch == ' ' || *ch == '<' || *ch == '>')
					ch++;
                // We may have gotten to the end again.
                if ( ch - base16Bytes < lentext)
                {
                    if ( ( *ch >= 'A' ) && ( *ch <= 'F' ) )
                        cNibble = *ch - 'A' + 10;
                    else if ( ( *ch >= 'a' ) && ( *ch <= 'f' ) )
                        cNibble = *ch - 'a' + 10;
                    else if ( ( *ch >= '0' ) && ( *ch <= '9' ) )
                        cNibble = *ch - '0';

                    cByte += cNibble;
                    // And increment our character pointer.
                    ch++;
                }
			}

			[mutableData appendBytes:&cByte length:1];

		}
	}

	//	self = [self initWithData:mutableData];
	return ([[NSData allocWithZone:nil] initWithData:mutableData]);
}

#pragma mark -
#pragma mark Facebook.

- (void)initFacebook
{
#ifdef PROJECT_USE_FBMANAGER
    // New hack ... have we requested Facebook?
    if ([MRUtilities getContentStatusForKey:MR_PREF_REQUESTED_FACEBOOK] == YES)
    {
        MRSocialService *fbMan = [MRSocialService sharedFBManager];

        [fbMan initFacebookWithAppId:MR_FACEBOOK_APP_ID];
        fbMan.idDelegate = self;
        //            [fbMan requestWithGraphPath:@"me/friends"];
    }
#endif
}

- (BOOL)facebookRequestedAndRequired
{
    if ([MRUtilities getContentStatusForKey:MR_PREF_REQUESTED_FACEBOOK] == YES)
        return m_fRequireFacebook;
    return NO;
}

- (void)facebookRequestDidLoad:(NSDictionary *)dictResults forGraphPath:(NSString *)strPath
{
#ifdef PROJECT_USE_FBMANAGER
//	NSLog(@"Results %@ for path %@", dictResults, strPath);
    MRSocialService *fbMan = [MRSocialService sharedFBManager];
    NSString *strID = [fbMan getMyId];
    NSLog(@"Facebook id is %@", strID);
    // Did we change?
    if ([m_strFacebookID isEqualToString:strID] == NO)
    {
        (void)0;
        if (strID == nil)
            return;
        m_strFacebookID = [[NSString alloc] initWithFormat:@"%@", strID];
        SEL selChanged = @selector(facebookHasChanged:);
        if ([m_idFacebookCallbackOb respondsToSelector:selChanged])
        {
            [m_idFacebookCallbackOb performSelector:selChanged withObject:m_strFacebookID];
        }
        else
        {
            // Send any queued messages, and then a ping.
            [self sendISCQueuedIfIdle];
            [self sendISCPing];
        }
        // If we weren't already asking for friends, update our friends list.
        if ([strPath isEqualToString:PATH_ID])
        {
            [fbMan requestFriendsWithForcedRefresh:YES];
        }
    }

    // Were we a friends request?
    if ([strPath isEqualToString:PATH_FRIENDS])
    {
        // Tom hack ... what are friends?
        NSArray *arrFriends = [fbMan getFacebookFriends];
        NSString *strFriendsList = nil;
        for (NSDictionary *dictFriend in arrFriends)
        {
            // We should have "id" and "name" from Facebook.
            NSString *strID = [dictFriend objectForKey:@"id"];
//            NSString *strName = [dictFriend objectForKey:@"name"];
//            NSLog(@"  Friend: %@ (%@)", strName, strID);
            if (strFriendsList == nil)
                strFriendsList = [NSString stringWithString:strID];
            else
                strFriendsList = [strFriendsList stringByAppendingFormat:@"|%@", strID];
        }
        SEL selFriends = @selector(facebookGotFriends:);
        if ([m_idFacebookCallbackOb respondsToSelector:selFriends])
        {
            [m_idFacebookCallbackOb performSelector:selFriends withObject:strFriendsList];
        }

    }
    NSArray *aParts = [strPath componentsSeparatedByString:@"/"];
    if ([[aParts lastObject] isEqualToString:@"picture"] == YES)
    {
        NSString *strID = [aParts objectAtIndex:[aParts count] - 2];
        NSData *dataResults = (NSData *)dictResults;
        UIImage *image = [UIImage imageWithData:dataResults];
        CGRect rectBounding;
        rectBounding.size = image.size;
        rectBounding.size.height /= 1;
        rectBounding.size.width /= 1;
        NSError *error=nil;
        MRTexture *texture=[[MRTexture alloc] initWithContext:[MRSceneRuntime sharedRuntime].context image:image.CGImage error:&error];
        if (texture) {
            MRSpriteFrame *frame=[[MRSpriteFrame alloc] initWithTexture:texture pixelRect:(CGRect){CGPointZero,texture.pixelSize} originalSize:rectBounding.size trimOffset:CGPointZero pixelsPerPoint:image.scale rotated:NO];
            [[MRSceneRuntime sharedRuntime].resources setFrame:frame named:strID];
        }
    }
#endif
}

@end // UtilityManager

#pragma mark -
#pragma mark AlertViewURL

@implementation UIAlertViewURL

@synthesize strURL = m_strURL;

@end	// AlertJump
#endif
