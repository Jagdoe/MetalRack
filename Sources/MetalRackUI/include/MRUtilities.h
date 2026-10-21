//
//  UtilityManager.h
//  Zombie
//
//  Created by Stretchy Tom on 8/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRUIKit.h"
#import <Foundation/Foundation.h>
#import "MRSceneConfiguration.h"
//#import "MRSceneHost.h"

#ifdef PROJECT_USE_FBMANAGER
#import "MRSocialService.h"
#endif

#import <StoreKit/StoreKit.h>

#define LEADERBOARDS_MAX	(14)

// Text
#define DEFAULT_FONT_SYSTEM         @"Helvetica-Bold"
#define DEFAULT_FONT_GEN1_SYSTEM	@"Arial-BoldMT"
#ifndef DEFAULT_FONT
    #define DEFAULT_FONT		@"cooper"
#endif
#define DEFAULT_FONT_BIG    @"cooper-big"
#define ALT_FONT			@"MarkerFelt-Wide"

@class MRSceneHost;
@class MRLayer;
@class MRDefinitionSprite;
@class Body;
@class GKScore;
@class GKLeaderboard;
@class NSOperationQueue;

typedef enum
{
	EGM_ANY = 0,
	EGM_SINGLE,		// Single-mission mode.
	EGM_MULTI,		// Multi-mission mode.

	// Keep this last.
	EGM_NUM_TYPES
} EGameplayMode;

typedef enum
{
	EKS_NONE = 0,
	EKS_SCORE,
	EKS_COUNT,
	EKS_CURRENCY,
	EKS_TECH,

	// Keep this last.
	NUM_EKS_TYPES
} EKeyStyle;

typedef enum
{
	ELS_LOCKED_HIDDEN = 0,		// Not available, no title.
	ELS_LOCKED_SHOWN,			// Not available, but shown. ("Locked")
	ELS_UNLOCKED,				// An uncompleted but available level. ("New!")
	ELS_COMPLETED_0,			// Completed, but not very well.
	ELS_COMPLETED_1,			// Completed a bit better.
	ELS_COMPLETED_2,			// Completed gooder.

	// Keep this last.
	ELS_NUM_TYPES
} ELevelState;

typedef struct
{
	NSString *strPlayerID;
	NSString *strPlayerAlias;
	float	 flPlayerDistance;
} TDistanceInfo;

#pragma mark -
#pragma mark MRUtilities


#define PREFS_KEY_UNLOCKED	@"unlocked"

@protocol ISCRequestDelegate <NSObject>

- (void)ISCDidReceiveElement:(NSString *)strElement withContent:(NSString *)strContent;

@end

#ifdef PROJECT_USE_FBMANAGER
@interface MRUtilities : NSObject <NSXMLParserDelegate, SKProductsRequestDelegate, SKPaymentTransactionObserver, FBManagerDelegate>
#else
@interface MRUtilities : NSObject <NSXMLParserDelegate, SKProductsRequestDelegate, SKPaymentTransactionObserver>
#endif
{
	// General stuff.
	NSString		*m_strNickname;
    NSString        *m_strFacebookID;
	MRSceneHost	*m_appDelegate;
	EGameplayMode	m_eGameplayMode;
	EGameplayMode	m_eGameplayForJumps;
	NSString		*m_strDefaultFont;

    // Colors.
    NSMutableDictionary		*m_dictColors;

    // Shape-Groups stuff.
    NSDictionary    *m_dictGroupsCombined;

	// InertSoap Connection stuff
	NSURLConnection		*m_connectionISC;
	NSData				*m_dataISC;
	NSString			*m_strCurrentXMLElement;
	NSMutableDictionary *m_dictISCParams;
	NSMutableArray		*m_arrQueuedRequests;

    // ASI HTTP stuff.
    NSOperationQueue    *m_queueASI;

	// In-App Purchase: Product puchase transaction
	BOOL					m_fUseInApp;
	id						m_idPaymentCallbackOb;
	// In-App Purchase: Product add-on request information
	SKProductsRequest		*m_prodRequest;
	SKProductsResponse		*m_prodResponse;
	id						m_callBackOb;
	SEL						m_callBackSelector;

	// Game Center stuff
	BOOL				m_fIsGCAvailable;
	BOOL				m_fLocalPlayerAuthenticated;
	NSArray				*m_arrLeaderboardCategories;
	NSArray				*m_arrLeaderboardNames;
	BOOL				m_fDistancesLoaded;
	NSMutableArray		*m_arrDistanceScores;
	NSMutableDictionary	*m_dictDistancePlayers;
	int					m_nRanks[LEADERBOARDS_MAX];
//	GKLeaderboard		*m_leaderboardRequestForRank;
    NSMutableArray      *m_arrLeaderboardRequestsPending;
	NSMutableArray		*m_arrLeaderboardRankRequests;
	GKLeaderboard		*m_leaderboardRequestForDistance;

    NSMutableDictionary *m_dictOFtoGC;

	// Facebook stuff.
    BOOL                m_fUseFacebook;
    BOOL                m_fRequireFacebook;
    id                  m_idFacebookCallbackOb;

    // App specific ISC data
    id <ISCRequestDelegate>     m_idISCRequestDelegate;
}

@property (nonatomic, setter=setGameplayMode:)	EGameplayMode eGameplayMode;		// with m_eGameplayMode
@property (readonly)				EGameplayMode eGameplayForJumps;	// with m_eGameplayForjumps

@property (nonatomic, copy) NSString *strFacebookID;
@property (nonatomic, copy, setter=setNickname:) NSString *nickname;		// Paired with m_strNickname in .m
@property (nonatomic, readonly, copy)	NSArray *arrLeaderboardNames;		// Paired with m_arrLeaderboardNames
@property (nonatomic, readonly, copy)	NSArray *arrLeaderboardCategories;	// Paired with m_arrLeaderboardCategories
@property (readonly)				BOOL fUseInApp;							// Paired with m_

+ (void)prepare;
+ (MRUtilities *)sharedUtilityManager;
+ (MRUtilities *)sharedUtilityManagerWithOptions:(NSDictionary*)dictOptions;

- (id)initWithOptions:(NSDictionary*)dictOptions;

#pragma mark -
#pragma mark General
+ (NSString*)getTimeForSeconds:(int)nTimeInSeconds;
+ (NSString*)getFormattedNumber:(float)flValue;
+ (NSString *)getFormattedTime:(float)flSeconds;
+ (NSString*)getTruncatedString:(NSString*)strLabel forWidth:(float)flWidth withFont:(NSString*)strFont withSize:(float)flFontSize addElipses:(BOOL)fAddDots;
+ (NSString*)getFortuneCookieQuoteForCategory:(NSString*)strCategory;
+ (MRSystemText*)createTextRegion:(NSString *)strText size:(CGSize)sizeRegion fontSize:(float)flFontSize;

#pragma mark -
#pragma mark Prefs
// Boolean prefs.
+ (BOOL)getContentStatusForKey:(NSString*)strKey;
+ (void)setContentStatusForKey:(NSString*)strKey asActive:(BOOL)fActive;
+ (BOOL)doesContentStatusExistForKey:(NSString*)strKey;

// Integer prefs.
+ (int)getContentIntForKey:(NSString*)strKey;
+ (void)setContentIntForKey:(NSString*)strKey withInt:(int)nValue;
+ (int)adjustContentIntForKey:(NSString*)strKey withDelta:(int)nDelta;
+ (BOOL)doesContentIntExistForKey:(NSString*)strKey;

// Float prefs.
+ (float)getContentFloatForKey:(NSString*)strKey;
+ (float)adjustContentFloatForKey:(NSString*)strKey withDelta:(float)flValue;
+ (void)setContentFloatForKey:(NSString*)strKey withFloat:(float)flValue;
+ (BOOL)doesContentFloatExistForKey:(NSString*)strKey;

// Double prefs.
+ (double)getContentDoubleForKey:(NSString*)strKey;
+ (double)adjustContentDoubleForKey:(NSString*)strKey withDelta:(double)dbValue;
+ (void)setContentDoubleForKey:(NSString*)strKey withDouble:(double)dbValue;
+ (BOOL)doesContentDoubleExistForKey:(NSString*)strKey;

// String prefs.
+ (NSString *)getContentStringForKey:(NSString*)strKey;
+ (void)setContentStringForKey:(NSString*)strKey withString:(NSString *)strValue;
+ (BOOL)doesContentExistForKey:(NSString*)strKey;

// Array prefs.
+ (NSMutableArray *)getContentArrayForKey:(NSString*)strKey;
+ (void)setContentArrayForKey:(NSString*)strKey withArray:(NSArray*)arrValue;

// Dictionary prefs.
+ (NSDictionary *)getContentDictionaryForKey:(NSString*)strKey;
+ (void)setContentDictionaryForKey:(NSString*)strKey withDictionary:(NSDictionary*)dictValue;

// Remove a pref.
+ (void)removePrefForKey:(NSString*)strKey;

+ (NSString*)getSubvalueKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue;
+ (int)getContentSubvalueForKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue;
+ (void)setContentSubvalueForKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue withValue:(int)nValue;
+ (int)adjustContentSubvalueForKey:(NSString*)strKey withSubvalue:(NSString*)strSubvalue withDelta:(int)nDelta;

+ (int)getLimitedKeyCountForKey:(NSString*)strKey;
+ (int)decrementLimitedKey:(NSString*)strKey;

// Tech-specific.
+ (NSString*)getKeyForTech:(NSString*)strTech;
+ (ELevelState)getTechState:(NSString*)strTech;

// Other keys.
+ (NSString*)getKeyForSet:(int)nSet withStyle:(EKeyStyle)eKey;
+ (NSString*)getKeyForMission:(int)nMission withStyle:(EKeyStyle)eKey;
+ (NSString*)getKeyForLifetimeWithStyle:(EKeyStyle)eKey;
+ (NSString*)getKeyForCurrentWithStyle:(EKeyStyle)eKey;
+ (NSString*)getKeyForLevelWithStyle:(EKeyStyle)eKey;

#pragma mark -
#pragma mark Graphics
// Graphics entries.
- (id)createMapNodePointer:(MRDefinitionSprite *)sprNode inLayer:(MRLayer*)layer atPoint:(CGPoint)pIntersect;
- (id)createMapNodePointer:(MRDefinitionSprite *)sprNode inLayer:(MRLayer*)layer;
- (void)updateMapNodePointer:(MRDefinitionSprite*)sprNode forBody:(MRDefinitionSprite*)bodyItem;
- (void)fadeInForNode:(MRDefinitionSprite*)sprNode;
- (void)fadeOutForNode:(MRDefinitionSprite*)sprNode;

- (CGPoint)findScreenEdgeforRay:(CGPoint)vCenterToNode withPoint:(CGPoint)pCenter;
- (void)createBoltFromPointA:(CGPoint)ptA toPointB:(CGPoint)ptB withDepth:(int)nDepth intoContainer:(MRSprite*)sprContainer;
- (void)createBoltFromPointA:(CGPoint)ptA toPointB:(CGPoint)ptB intoLayer:(MRLayer*)layContainer;
- (void)createBoltsFromParams:(NSMutableDictionary*)dictParams;

#pragma mark -
#pragma mark Hardware
- (NSString *) getModel;
- (BOOL) modelIsIpad;
- (NSString *) getPlatform;
- (NSString *) getPlatformString;
- (BOOL) getPlatformIsFirstGen;
- (BOOL) getPlatformIsSecondGen;
- (BOOL) getPlatformIsThirdGen;
- (void)setDefaultFont:(NSString*)strFont;
- (NSString *)getDefaultSystemFont;
- (NSString *)getDefaultFont;
- (NSString *)getDefaultFontCachedFast;
+ (float)getDeviceScaleAdjustment;
+ (BOOL)isIPad1;
+ (BOOL)isIPad;

#pragma mark -
#pragma mark Colors
- (void)initColors;
+ (MRColor3B)getColor:(NSString*)strColor;
+ (MRRenderColor)getColorAs4B:(NSString*)strColor;
+ (MRColor3B)getColor:(NSString*)strColor;
+ (MRRenderColor)getColorAs4B:(NSString*)strColor;
+ (NSArray *)getColorSet:(NSString *)strColorSet;
+ (MRColor3B)getColorInSet:(NSString *)strColorSet atIndex:(int)nIndex;

#pragma mark -
#pragma mark Shape-Groups
- (NSString*)groupsGetMasterPath;
- (NSDictionary*)groupsGetMasterDictionary;

- (NSString*)groupsGetDynamicPath;
- (NSMutableDictionary*)groupsGetDynamicDictionary;

- (NSDictionary*)groupsGetCombinedDictionary;
- (void)groupsReloadCombinedDictionary;

#pragma mark -
#pragma mark Network
// Network related.
- (void)initNetwork;
- (BOOL)isInternetReachable;
- (BOOL)isNetworkAvailable;
- (NSString *)getDeviceTag;

// InertSoap Connection stuff.
- (NSMutableDictionary *)genericParameters;
- (void)startParsing:(NSData *) myData;
- (void)sendISCCreateCouponRequest;
- (void)sendISCClaimCouponRequest:(NSString*)strCoupon;
- (void)sendISCRedeemCouponsRequest;
- (void)sendISCClearCouponsRequest;
- (void)sendISCGetFriendRequest;
- (void)sendISCGetAppsRequest;
- (void)sendISCGetMessagesRequest;
- (void)sendISCGetPopupRequest;
- (void)sendISCGetRewardsRequest;
- (void)sendISCPing;
- (void)sendISCPingWithExtra:(NSString*)strExtra;
- (void)sendISCData:(NSData*)postData forFriend:(NSString*)strFriend forKey:(NSString*)strKey withDelegate:(id)idTarget forceSynchronous:(BOOL)fSynch;
- (void)sendISCDataRequestForFriend:(NSString*)strFriend forKey:(NSString*)strKey withDelegate:(id)idTarget;
- (void)sendISCGetFBFriendFrequest:(NSString*)strFriends withDelegate:(id)idTarget;
- (int)sendISCQueuedIfIdle;
- (void)sendISCGenericMessage:(NSString *)strRequest;
- (void)setISCRequestDelegate:(id <ISCRequestDelegate>)idDelegate;

// ISC non-web stuff
- (void)ISCmailReward:(NSString*)strReward;
- (void)ISCusedReward:(NSString*)strReward;
- (void)ISCredeemedRewards:(NSString*)strCount;
- (void)ISCdisplayError:(NSString*)strType withDetails:(NSString*)strDetails;
- (void)ISCdisplayMessage:(NSString*)strMessage;
- (BOOL)ISCdisplayPopup:(NSString*)strMessage;
- (void)ISCapplyReward:(NSString*)strReward;

#pragma mark -
#pragma mark In-App Purchase
// In-App Purchase Stuff.
- (void)initInApp;
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;
- (void)failedTransaction: (SKPaymentTransaction *)transaction;
- (void)restoreTransaction: (SKPaymentTransaction *)transaction;
- (void)completeTransaction: (SKPaymentTransaction *)transaction;
- (void)attemptPaymentWithProductIdentifier:(NSString *)strID callBackOb:(id)idCallback;
- (void)notifyPurchaseofTransaction:(SKPaymentTransaction *)transaction;

#pragma mark -
#pragma mark Purchasing Response Delegate
// Product releated queries and delegate
- (void)createRequest:(NSMutableSet *)setPacks callBackOb:(id)idOb selector:(SEL)selCallBack;
- (void)cancelRequest;
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response;
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error;
- (SKProductsResponse*)getStoreResponse;
- (SKProduct *)getProductForID:(NSString*)strID;

// Rewards & eMail
#pragma mark -
#pragma mark Rewards & eMail
- (void)mailReward:(NSString*)strReward;
- (void)applyReward:(BOOL)fWasMine;

#pragma mark -
#pragma mark Game Center
- (void) GCinit;
- (BOOL) GCisAvailableSlow;
- (BOOL) GCisAvailable;
- (BOOL) GCisAuthenticated;
- (void) GCauthenticateLocalPlayer;
- (BOOL) GCisAuthenticated;
- (void) GCreportScore:(Float64)flScore forCategory:(NSString*)strCategory;
- (void) GCshowLeaderboard;
- (void) GCshowLeaderboardWithBoard:(NSString*)strLeaderboard;
- (void) GCreportAchievementIdentifier:(NSString*)strAchievement percentComplete:(float)flPercent;
- (void) GCshowAchievements;
- (NSString*) GCgetAlias;
- (NSString*) GCgetLeaderboardCurrentForType:(NSString*)strStyle;
- (void) GCloadLeaderboardCategories;
- (const int *)getRanks;
- (void)attemptAchievement:(NSString *)strAch;
- (void)attemptAchievement:(NSString *)strAch withValue:(int)nValue withRequirement:(int)nReq allowPartial:(BOOL)fAllowPartial;
- (void)setHighScore:(int)nLifetime forLeaderboard:(NSString *)strLeaderboard;
- (void)GCloadRank:(NSString *)strLeaderboard;
- (void)GCloadRanks;
- (void)GCClearOldDistancesData;
- (void)GCloadNextDistanceBatch;

// General utility
+ (id) createNSDataFromUTF8EncodedString:(NSString *) string;

- (BOOL)facebookRequestedAndRequired;
- (void)initFacebook;
- (void)setFacebookCallbackDelegate:(id)idDelegate;

#ifdef ZOMBIE
- (TDistanceInfo*)GCgetNextDistanceFrom:(float)flDistance;
#endif

#pragma mark -
#pragma mark General Definitions

#define OPTIONS_USE_GAME_CENTER		@"use game center"
#define OPTIONS_USE_IN_APP			@"use in-app"
#define OPTIONS_USE_FACEBOOK        @"use facebook"
#define OPTIONS_REQUIRE_FACEBOOK    @"require facebook"
#define OPTIONS_CALLBACK_FACEBOOK   @"callback facebook"

#pragma mark -
#pragma mark ISC Definitions

#define ISC_NAME_DEVICE_TAG			@"DeviceTag"
#define ISC_NAME_DEVICE_TYPE		@"DeviceType"
#define ISC_NAME_DEVICE_OS_VERSION	@"DeviceOS"
#define ISC_NAME_DEVICE_HARDWARE	@"DeviceHardware"
#define ISC_NAME_APP_NAME			@"AppName"
#define ISC_NAME_APP_VERSION		@"AppVersion"
#define ISC_NAME_LIBRARY_VERSION	@"ConnectVersion"
#define ISC_NAME_KEY				@"ConnectKey"
#define ISC_NAME_COUPON				@"Coupon"
#define ISC_NAME_SCORE				@"Score"
#define ISC_NAME_NICKNAME			@"Nickname"
#define ISC_NAME_PURCHASED          @"Purchased"
#define ISC_NAME_COLLECTION         @"Collection"
#define ISC_NAME_MULTIPLAYER        @"Multiplayer"
#define ISC_NAME_COUNT              @"Count"
#define ISC_NAME_FACEBOOK           @"Facebook"
#define ISC_NAME_FACEBOOK_FRIENDS   @"FacebookFriends"
//#define ISC_TIME_STAMP			@"Timestamp"

#define ISC_LIBRARY_VERSION		(1.0)

//#define MR_ISC_APP_NAME			// Define this in the project-specific area, please!
#define ISC_MAIN_URL			@"http://inertsoap.com/"
#define ISC_COUPONREQ_SNIP		@"chatter/request_coupon.php"
#define ISC_COUPONUSE_SNIP		@"chatter/use_coupon.php"
#define ISC_COUPONREDEEM_SNIP	@"chatter/redeem_coupons.php"
#define ISC_COUPONCLEAR_SNIP	@"chatter/clear_coupons.php"
#define ISC_FRIENDREQ_SNIP		@"chatter/request_friends.php"
#define ISC_APPSREQ_SNIP		@"chatter/request_apps.php"
#define ISC_MESSAGEREQ_SNIP		@"chatter/request_messages.php"
#define ISC_POPUPSREQ_SNIP		@"chatter/request_popups.php"
#define ISC_REWARDSREQ_SNIP		@"chatter/request_rewards.php"
#define ISC_PING_SNIP			@"chatter/pingme.php"
#define ISC_POSTDATA_SNIP       @"chatter/send_app_data.php"
#define ISC_FBFRIENDS_SNIP      @"chatter/request_facebook_friends.php"

#define ISC_COUPON_FAILED		@"ISCCouponFailed"
#define ISC_COUPON_SUCCESS		@"ISCcouponSuccess"

#define ISC_SECRET				@"ISCBubblesWillFail"

#define ISC_FACEBOOK_INVALID    @"facebook:invalid"

#pragma mark -
#pragma mark Hardware Definitions

#define IPHONE_1G_NAMESTRING	@"iPhone 1G"
#define IPHONE_3G_NAMESTRING	@"iPhone 3G"
#define IPHONE_3GS_NAMESTRING	@"iPhone 3GS"
#define IPOD_1G_NAMESTRING		@"iPod touch 1G"
#define IPOD_2G_NAMESTRING		@"iPod touch 2G"

#pragma mark -
#pragma mark General Definitions.
#define ALERT_TAG_NONE          (0)
#define ALERT_TAG_LINK          (1000)
#define ALERT_TAG_BASIC_PACK    (2000)
#define ALERT_TAG_ASK_FB        (3000)

#define SPRITE_TAG_LIGHTNING    (10000)

@end

#pragma mark -
#pragma mark AlertViewURL

@interface UIAlertViewURL : UIAlertView
{
	NSString	*m_strURL;
}

@property (copy) NSString *strURL;

@end	// AlertViewURL

// Various defs.
#define PREFS_KEY_KILLS		@"destroy"
#define PREFS_KEY_LIFETIME	@"lifetime"	// Lifetime of game.
#define PREFS_KEY_CURRENT	@"current"	// Current remaining (persistent)
#define PREFS_KEY_LEVEL		@"level"	// Current level only (resets)
#define PREFS_KEY_UNLOCKED	@"unlocked"
