#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  FBManager.m
//  Gnomes
//
//  Created by Michael Scandizzo on 1/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MRSocialService.h"

@implementation MRSocialService

@synthesize idDelegate = m_idDelegate;

// ********************************************************************************
#pragma mark Facebook
// ********************************************************************************

static MRSocialService *sgFBManager = nil;

+ (id)sharedFBManager
{
	if (sgFBManager == nil)
	{
		sgFBManager = [[MRSocialService alloc] init];
	}
	return sgFBManager;
}

- (id)initFacebookWithAppId:(NSString *)strAppId
{
	self = [super init];
	if (self != nil)
	{
		m_facebook = [[Facebook alloc] initWithAppId:strAppId andDelegate:self];
		m_idDelegate = nil;
		m_dictRequestType = [[NSMutableDictionary alloc] initWithCapacity:1];
		m_dictResultsCache = [[NSMutableDictionary alloc] initWithCapacity:1];

		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults objectForKey:@"FBAccessTokenKey"]
			&& [defaults objectForKey:@"FBExpirationDateKey"])
		{
			m_facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
			m_facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
		}
	}
	return self;
}

- (void)startSession
{
	if ([m_facebook isSessionValid] == NO)
    {
        NSArray *aPermissions = ([NSArray arrayWithObjects:@"offline_access", nil]);
		[m_facebook authorize:aPermissions];
	}
	else
	{
		[self getMyId];
	}
}

- (void)requestWithGraphPath:(NSString *)strGraphPath
{
	m_strPendingGraphPath = nil;
    if ([m_facebook isSessionValid] == NO)
    {
        NSArray *aPermissions = ([NSArray arrayWithObjects:@"offline_access", nil]);
		[m_facebook authorize:aPermissions];
		m_strPendingGraphPath = strGraphPath;
    }
    else
    {
        //get the logged-in user's friends
        FBRequest *lastRequest = [m_facebook requestWithGraphPath:strGraphPath andDelegate:self];
		NSString *strRequest = [NSString stringWithFormat:@"%d", (int)lastRequest];
		[m_dictRequestType setObject:strGraphPath forKey:strRequest];
        NSLog(@"Adding Facebook graph path request: %@", strRequest);
    }
}

- (NSDictionary *)getResultsForGraphPath:(NSString *)strGraphPath
{
	return [m_dictResultsCache objectForKey:strGraphPath];
}

// Just get whatever cached friends data we already have.
- (NSArray *)getFacebookFriends
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"Facebook Friends"];
}

- (void)requestFriendsWithForcedRefresh:(BOOL)fForced
{
	NSDictionary *dictResults = [self getResultsForGraphPath:PATH_FRIENDS];
	if (fForced == YES || dictResults == nil)
	{
		[self requestWithGraphPath:PATH_FRIENDS];
	}
}

- (NSString *)getShortNameForName:(NSString *)strLongName
{
    NSString *strName = nil;
    // Split the name up, and shorten the second and on if they're too long.
    NSArray *arrNames = [strLongName componentsSeparatedByString:@" "];
    int nCount = [arrNames count];
    if (nCount >= 2)
    {
        strName = [NSString stringWithFormat:@"%@ ", [arrNames objectAtIndex:0]];
        for (int nIndex = 1; nIndex < nCount; ++nIndex)
        {
            NSString *strSubName = [arrNames objectAtIndex:nIndex];
            if ([strSubName length] >= 4)
            {
                strSubName = [NSString stringWithFormat:@"%@. ", [strSubName substringToIndex:1]];
            }
            strName = [strName stringByAppendingString:strSubName];
        }
    }
    return strName;
}

- (NSString *)getFacebookNameForID:(NSString*)strID andShorten:(BOOL)fShorten
{
    // Trim any gunk from the ID.
    strID = [strID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Can we find this Facebook friend?
    NSArray *arrFriends = [self getFacebookFriends];
    for (NSDictionary *dictFriend in arrFriends)
    {
        if ([strID isEqualToString:[dictFriend objectForKey:@"id"]])
        {
            NSString *strName = [dictFriend objectForKey:@"name"];
            if (fShorten == YES)
            {
                strName = [self getShortNameForName:strName];
            }
            return strName;
        }
    }

    // Couldn't find it!
    return nil;
}

- (NSString*)getMyId
{
	NSString *strMyId = nil;
	NSDictionary *dictResults = [self getResultsForGraphPath:PATH_ID];
	if (dictResults == nil)
	{
		[self requestWithGraphPath:PATH_ID];
	}
	else
	{
		strMyId = [dictResults objectForKey:@"id"];
		NSLog(@"MyId: %@", strMyId);
	}
	return strMyId;
}

// MUST be called by Applications MRSceneHost application:handleOpenURL:
- (BOOL)handleOpenURL:(NSURL *)url
{
    return [m_facebook handleOpenURL:url];
}

// ********************************************************************************
#pragma mark FBSessionDelegate
// ********************************************************************************

/**
 * Called when the user successfully logged in.
 */
- (void)fbDidLogin
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[m_facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[m_facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];

//    //get the logged-in user's friends
//    [m_facebook requestWithGraphPath:@"me/friends" andDelegate:self];
	if (m_strPendingGraphPath != nil)
		[self performSelector:@selector(requestWithGraphPath:) withObject:m_strPendingGraphPath];
    // Now get our friends.
	[self requestFriendsWithForcedRefresh:YES];
}

/**
 * Called when the user dismissed the dialog without logging in.
 */
- (void)fbDidNotLogin:(BOOL)cancelled
{
	NSLog(@"Facebook login failed");
}

/**
 * Called after the access token was extended. If your application has any
 * references to the previous access token (for example, if your application
 * stores the previous access token in persistent storage), your application
 * should overwrite the old access token with the new one in this method.
 * See extendAccessToken for more details.
 */
- (void)fbDidExtendToken:(NSString*)accessToken
               expiresAt:(NSDate*)expiresAt
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:accessToken forKey:@"FBAccessTokenKey"];
    [defaults setObject:expiresAt forKey:@"FBExpirationDateKey"];
    [defaults synchronize];

	if (m_strPendingGraphPath != nil)
		[self performSelector:@selector(requestWithGraphPath:) withObject:m_strPendingGraphPath];
}

/**
 * Called when the user logged out.
 */
- (void)fbDidLogout
{
	NSLog(@"Facebook logged out");
}

/**
 * Called when the current session has expired. This might happen when:
 *  - the access token expired
 *  - the app has been disabled
 *  - the user revoked the app's permissions
 *  - the user changed his or her password
 */
- (void)fbSessionInvalidated
{
}

// ********************************************************************************
#pragma mark FBRequestDelegate
// ********************************************************************************

- (void)request:(FBRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"Facebook request failed.");
}

- (void)request:(FBRequest *)request didLoad:(id)result;
{
	NSString *strRequest = [NSString stringWithFormat:@"%d", (int)request];
	NSString *strGraphPath = [m_dictRequestType objectForKey:strRequest];
    if ([result isKindOfClass:[NSData class]] == YES)
    {
        NSLog(@"This is data!");
        [m_dictResultsCache setValue:result forKey:strGraphPath];
    }
    else
    {
        NSDictionary *dictFacebookResults = (NSDictionary *)result;

        [m_dictResultsCache setValue:dictFacebookResults forKey:strGraphPath];
        if ([strGraphPath isEqualToString:PATH_FRIENDS])
        {
            NSArray *aFacebookResults = [dictFacebookResults objectForKey:@"data"];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:aFacebookResults forKey:@"Facebook Friends"];
        }
    }
	if (m_idDelegate != nil)
	{
		[m_idDelegate performSelector:@selector(facebookRequestDidLoad:forGraphPath:) withObject:result withObject:strGraphPath];
	}
    if (strGraphPath != nil)
		[m_dictRequestType removeObjectForKey:strRequest];

}

@end

#endif
