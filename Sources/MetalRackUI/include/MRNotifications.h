//
//  NotificationManager.h
//  Gnomes
//
//  Created by Tom Ricket on 12/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct
{
	NSString *strTitle;
	NSString *strButtonTitle;
	SEL		 selButtonSelector;
	NSString *strDescription;
	NSString *strImage;
	SEL		 selNotify;
	NSString *strSelectorTitle;
	NSString *strColorOverride;
} TNotification;
#define MAX_NOTIFICATIONS	(8)

@interface MRNotifications : NSObject
{
    int						m_nNumNotifications;
    TNotification			m_tNotifications[MAX_NOTIFICATIONS];
}

+ (MRNotifications*)sharedNotificationManager;

- (BOOL)notificationAdd:(TNotification)tNotification;
- (BOOL)notificationAddWithTitle:(NSString*)strTitle withButtonTitle:(NSString*)strButtonTitle withButtonSelector:(SEL)selOkay withText:(NSString*)strText withIcon:(NSString*)strIcon withSelector:(SEL)selector withSelectorTitle:(NSString*)strSelectorTitle withColor:(NSString*)strColor;
- (BOOL)notificationRemoveLastInto:(TNotification*)pNotify;
- (int)notificationGetUsedCount;
- (int)notificationGetFreeCount;

@end
