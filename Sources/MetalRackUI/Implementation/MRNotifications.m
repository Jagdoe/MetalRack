#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  NotificationManager.m
//  Gnomes
//
//  Created by Tom Ricket on 12/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MRNotifications.h"

static MRNotifications *sgNotificationManager = nil;

@implementation MRNotifications

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        m_nNumNotifications = 0;
    }

    return self;
}

+ (MRNotifications*)sharedNotificationManager
{
    if (sgNotificationManager == nil)
    {
        sgNotificationManager = [[MRNotifications alloc] init];
    }
    return sgNotificationManager;
}

- (BOOL)notificationAdd:(TNotification)tNotification
{
	return [self notificationAddWithTitle:tNotification.strTitle
						  withButtonTitle:tNotification.strButtonTitle
					   withButtonSelector:tNotification.selButtonSelector
								 withText:tNotification.strDescription
								 withIcon:tNotification.strImage
							 withSelector:tNotification.selNotify
						withSelectorTitle:tNotification.strSelectorTitle
								withColor:tNotification.strColorOverride];
}

- (BOOL)notificationAddWithTitle:(NSString*)strTitle withButtonTitle:(NSString*)strButtonTitle withButtonSelector:(SEL)selOkay withText:(NSString*)strText withIcon:(NSString*)strIcon withSelector:(SEL)selector withSelectorTitle:(NSString*)strSelectorTitle withColor:(NSString*)strColor
{

	if (m_nNumNotifications >= MAX_NOTIFICATIONS)
		return NO;

	// Erm ... COPY us all in.
	TNotification *pNotify = &(m_tNotifications[m_nNumNotifications]);

	pNotify->strTitle = nil;
	if (strTitle != nil)
		pNotify->strTitle = [[NSString alloc] initWithString:strTitle];

	pNotify->strButtonTitle = nil;
	if (strButtonTitle != nil)
		pNotify->strButtonTitle = [[NSString alloc] initWithString:strButtonTitle];

	pNotify->strDescription = nil;
	if (strText != nil)
		pNotify->strDescription = [[NSString alloc] initWithString:strText];

	pNotify->strImage = nil;
	if (strIcon != nil)
		pNotify->strImage = [[NSString alloc] initWithString:strIcon];

	pNotify->selButtonSelector = selOkay;
	pNotify->selNotify = selector;

	pNotify->strSelectorTitle = nil;
	if (strSelectorTitle != nil)
		pNotify->strSelectorTitle = [[NSString alloc] initWithString:strSelectorTitle];

	pNotify->strColorOverride = nil;
	if (strColor != nil)
		pNotify->strColorOverride = [[NSString alloc] initWithString:strColor];

	// Up our count.
	m_nNumNotifications += 1;

	return YES;
}

- (BOOL)notificationRemoveLastInto:(TNotification*)pNotify;
{
	// Do we have any notifications?
	if (m_nNumNotifications < 1)
		return NO;
	if (pNotify == nil)
		return NO;

	// Decrement our count BEFORE trying to get the data :)
	m_nNumNotifications -= 1;

	// COPY us all out.
	TNotification *pSource = &(m_tNotifications[m_nNumNotifications]);

	pNotify->strTitle = nil;
	if (pSource->strTitle != nil)
		pNotify->strTitle = [NSString stringWithString:pSource->strTitle];
	(void)0;
	pSource->strTitle = nil;

	pNotify->strButtonTitle = nil;
	if (pSource->strButtonTitle != nil)
		pNotify->strButtonTitle = [NSString stringWithString:pSource->strButtonTitle];
	(void)0;
	pSource->strButtonTitle = nil;

	pNotify->strDescription = nil;
	if (pSource->strDescription != nil)
		pNotify->strDescription = [NSString stringWithString:pSource->strDescription];
	(void)0;
	pSource->strDescription = nil;

	pNotify->strImage = nil;
	if (pSource->strImage != nil)
		pNotify->strImage = [NSString stringWithString:pSource->strImage];
	(void)0;
	pSource->strImage = nil;

	pNotify->strColorOverride = nil;
	if (pSource->strColorOverride != nil)
		pNotify->strColorOverride = [NSString stringWithString:pSource->strColorOverride];
	(void)0;
	pSource->strColorOverride = nil;

	pNotify->selButtonSelector = pSource->selButtonSelector;
	pSource->selButtonSelector = nil;

	pNotify->selNotify = pSource->selNotify;
	pSource->selNotify = nil;

	pNotify->strSelectorTitle = nil;
	if (pSource->strSelectorTitle != nil)
		pNotify->strSelectorTitle = [NSString stringWithString:pSource->strSelectorTitle];
	(void)0;
	pSource->strSelectorTitle = nil;

	// And we're done.
	return YES;
}

- (int)notificationGetUsedCount
{
	return m_nNumNotifications;
}

- (int)notificationGetFreeCount
{
	return (MAX_NOTIFICATIONS - m_nNumNotifications);
}

@end

#endif
