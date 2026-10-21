//
//  FBManager.h
//  Gnomes
//
//  Created by Michael Scandizzo on 1/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Facebook.h"

#define PATH_ID         @"me"
#define PATH_FRIENDS    @"me/friends"

@protocol FBManagerDelegate <NSObject>

- (void)facebookRequestDidLoad:(NSDictionary *)dictResults forGraphPath:(NSString *)strPath;

@end

@interface MRSocialService : NSObject <FBRequestDelegate, FBSessionDelegate>
{
	Facebook				*m_facebook;
	NSString				*m_strPendingGraphPath;
	NSMutableDictionary		*m_dictRequestType;
	__weak id <FBManagerDelegate>	m_idDelegate;
	NSMutableDictionary		*m_dictResultsCache;
}

@property (weak) id <FBManagerDelegate> idDelegate;

+ (id)sharedFBManager;

- (id)initFacebookWithAppId:(NSString *)strAppId;
- (void)startSession;
- (void)requestWithGraphPath:(NSString *)strGraphPath;
- (NSDictionary *)getResultsForGraphPath:(NSString *)strGraphPath;
- (BOOL)handleOpenURL:(NSURL *)url;

- (NSArray *)getFacebookFriends;
- (void)requestFriendsWithForcedRefresh:(BOOL)fForced;
- (NSString *)getShortNameForName:(NSString *)strLongName;
- (NSString *)getFacebookNameForID:(NSString*)strID andShorten:(BOOL)fShorten;
- (NSString*)getMyId;

@end
