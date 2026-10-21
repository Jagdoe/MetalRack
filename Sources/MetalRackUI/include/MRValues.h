//
//  ISMisc.h
//  Gnomes
//
//  Created by Tom Ricket on 12/28/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MRUIKit.h"

#pragma mark -
#pragma mark MRColorValue

@interface MRColorValue : NSObject
{
	NSMutableData	*m_dataColor;
}

+ (id)colorWithColor3B:(MRColor3B)color;
+ (id)colorWithRed:(uint8_t)byRed withGreen:(uint8_t)byGreen withBlue:(uint8_t)byBlue;
- (id)init;
- (void)setColor3B:(MRColor3B)color;
- (void)setColorWithRed:(uint8_t)byRed withGreen:(uint8_t)byGreen withBlue:(uint8_t)byBlue;
- (MRColor3B)getColor3B;
- (MRRenderColor)getColor4B;

@end // ISColor

#pragma mark -
#pragma mark MRPersistentCounters

@interface MRPersistentCounters : NSObject
{
    // Mission and set.
    int     m_nSet;
    int     m_nMission;

}

@property   int     nSet;
@property   int     nMission;

+ (MRPersistentCounters*)sharedMiscManager;
- (id)init;

+ (int)getScoreForLifetime;
+ (int)setScoreForLifetime:(int)nScore;
+ (int)incrementScoreForLifetime:(int)nDelta;

@end
