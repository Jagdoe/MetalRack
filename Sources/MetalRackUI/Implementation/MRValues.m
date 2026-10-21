#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  ISMisc.m
//  Gnomes
//
//  Created by Tom Ricket on 12/28/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MRValues.h"
#import "MRUtilities.h"

#pragma mark -
#pragma mark MRColorValue
@implementation MRColorValue

static NSRange sgtRange03 = {0, 3};	// first three bytes

+ (id)colorWithColor3B:(MRColor3B)color
{
	MRColorValue *iscolor = ([[MRColorValue alloc] init]);
	[iscolor setColor3B:color];
	return iscolor;
}

+ (id)colorWithRed:(uint8_t)byRed withGreen:(uint8_t)byGreen withBlue:(uint8_t)byBlue
{
	MRColor3B color = {byRed, byGreen, byBlue};
	return [self colorWithColor3B:color];
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		m_dataColor = [[NSMutableData alloc] initWithLength:3];
	}
	return self;
}

- (void)dealloc
{
	(void)0;
	m_dataColor = nil;

	(void)0;
}

- (void)setColor3B:(MRColor3B)color
{
	[m_dataColor replaceBytesInRange:sgtRange03 withBytes:&color];
}

- (void)setColorWithRed:(uint8_t)byRed withGreen:(uint8_t)byGreen withBlue:(uint8_t)byBlue
{
	MRColor3B color = {byRed, byGreen, byBlue};
	[self setColor3B:color];
}

- (MRColor3B)getColor3B
{
	MRColor3B color;
	[m_dataColor getBytes:&color length:3];
	return color;
}

- (MRRenderColor)getColor4B
{
	MRRenderColor color;
	[m_dataColor getBytes:&color length:3];
	color.a = 255;
	return color;
}

@end // ISColor


#pragma mark -
#pragma mark MRPersistentCounters

static MRPersistentCounters *sgMisc = nil;

@implementation MRPersistentCounters

@synthesize nSet = m_nSet;
@synthesize nMission = m_nMission;

+ (MRPersistentCounters*)sharedMiscManager
{
    if (sgMisc == nil)
    {
        sgMisc = [[MRPersistentCounters alloc] init];
    }
    return sgMisc;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        m_nSet = 0;
        m_nMission = 0;
    }

    return self;
}

#pragma mark -
#pragma mark Score & Level.

+ (int)getScoreForLifetime
{
	NSString *strKey = [MRUtilities getKeyForLifetimeWithStyle:EKS_SCORE];
	return [MRUtilities getContentIntForKey:strKey];
}

+ (int)setScoreForLifetime:(int)nScore
{
	// Don't allow subzero for now.
	nScore = MAX(0, nScore);

	NSString *strKey = [MRUtilities getKeyForLifetimeWithStyle:EKS_SCORE];
	[MRUtilities setContentIntForKey:strKey withInt:nScore];
	return nScore;
}

+ (int)incrementScoreForLifetime:(int)nDelta
{
	// Get the old score.
	int nScore = [self getScoreForLifetime];

	nScore += nDelta;
	nScore = MAX(0, nScore);

	return [self setScoreForLifetime:nScore];
}

@end // MiscManager

#endif
