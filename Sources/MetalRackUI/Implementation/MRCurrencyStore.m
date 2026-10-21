#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  CurrencyManager.m
//  Gnomes
//
//  Created by Tom Ricket on 12/28/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MRCurrencyStore.h"
#import "MRUtilities.h"
#import "MRDefinitions.h"

static MRCurrencyStore *sgCurrencyManager = nil;
static BOOL sfInitted = NO;

#define ENTRY_CURRENCY		@"Currency"
#define ENTRY_CLICKABLE		@"Clickable"
#define ENTRY_NAME			@"name"

@implementation MRCurrencyStore

+ (MRCurrencyStore *)sharedCurrencyManager
{
	if (sgCurrencyManager == nil)
    {
		sgCurrencyManager = [[MRCurrencyStore alloc] init];
        sfInitted = YES;
    }

	return sgCurrencyManager;
}

+ (float)getCurrency:(NSString*)strCurrency
{
	NSString *strKey = [NSString stringWithFormat:@"%@:%@",
						[MRUtilities getKeyForCurrentWithStyle:EKS_CURRENCY], strCurrency];
	return [MRUtilities getContentFloatForKey:strKey];
}

+ (float)getCurrencyForLifetime:(NSString*)strCurrency
{
	NSString *strKey = [NSString stringWithFormat:@"%@:%@",
						[MRUtilities getKeyForLifetimeWithStyle:EKS_CURRENCY], strCurrency];
	return [MRUtilities getContentFloatForKey:strKey];
}

+ (float)getCurrencyForLevel:(NSString*)strCurrency
{
	NSString *strKey = [NSString stringWithFormat:@"%@:%@",
						[MRUtilities getKeyForLevelWithStyle:EKS_CURRENCY], strCurrency];
	return [MRUtilities getContentFloatForKey:strKey];
}

+ (float)adjustCurrency:(NSString*)strCurrency withDelta:(float)flDelta
{
	float flCurrency = [self getCurrency:strCurrency];
	flCurrency += flDelta;

	// If a positive number, adjust our lifetime and level Currency as well.
	if (flDelta > FLT_EPSILON)
	{
		// Lifetime...
		NSString *strKey = [NSString stringWithFormat:@"%@:%@",
							[MRUtilities getKeyForLifetimeWithStyle:EKS_CURRENCY], strCurrency];
		float flLifetime = [MRUtilities getContentFloatForKey:strKey];
		flLifetime += flDelta;
		[MRUtilities setContentFloatForKey:strKey withFloat:flLifetime];

		// Level...
		strKey = [NSString stringWithFormat:@"%@:%@",
                  [MRUtilities getKeyForLevelWithStyle:EKS_CURRENCY], strCurrency];
		float flLevel = [MRUtilities getContentFloatForKey:strKey];
		flLevel += flDelta;
		[MRUtilities setContentFloatForKey:strKey withFloat:flLevel];
	}

	// Warning -- this could pave the way for a cheat if we allow to adjust by -10, but only have 8.
	// Decide where to guard against this...
	if (flCurrency < FLT_EPSILON)
		flCurrency = 0.0f;
	NSLog(@"Currency [%@] set to $%.2f", strCurrency, flCurrency);

	NSString *strKey = [NSString stringWithFormat:@"%@:%@",
						[MRUtilities getKeyForCurrentWithStyle:EKS_CURRENCY], strCurrency];
	[MRUtilities setContentFloatForKey:strKey withFloat:flCurrency];
	return flCurrency;
}

+ (NSString*)getCurrencyName:(NSString*)strCurrency
{
	MRDefinitions *defsMan = [MRDefinitions sharedDefsManager];
	NSDictionary *defCurrency = nil;
	if ([defsMan doesExistByClass:ENTRY_CURRENCY Type:strCurrency] == YES)
		defCurrency = [defsMan getDefByClass:ENTRY_CURRENCY Type:strCurrency];
	else
	{
		// Try as a generic clickable.
		defCurrency = [defsMan getDefByClass:ENTRY_CLICKABLE Type:strCurrency];
		if (defCurrency == nil)
			return @"Unknown Items";
	}
	NSString *strName = [defCurrency objectForKey:ENTRY_NAME];
	return strName;
}

+ (NSString*)getCurrencyAvailableString
{
	NSString *strCurrencies = @"";
	MRDefinitions *defsMan = [MRDefinitions sharedDefsManager];

	NSArray *arrCurrencies = [defsMan getDefsOfClass:ENTRY_CURRENCY];
	int nFoundItems = 0;
	for (NSString *strCurrency in arrCurrencies)
	{
		int nCurrent  = [self getCurrency:strCurrency];
		if (nCurrent > 0)
		{
            //			NSDictionary *defCurrency = [defsMan getDefByClass:ENTRY_CURRENCY Type:strCurrency];
            //			NSString *strName = [defCurrency objectForKey:ENTRY_NAME];
			NSString *strName = [self getCurrencyName:strCurrency];
			if (nFoundItems < 1)
				strCurrencies = [NSString stringWithFormat:@"%d %@", nCurrent, strName];
			else
				strCurrencies = [NSString stringWithFormat:@"%@, %d %@", strCurrencies, nCurrent, strName];
			++nFoundItems;
		}
	}

	return strCurrencies;
}

+ (BOOL)canAffordCost:(float)flCost forCurrency:(NSString*)strCurrency
{
	// How much do we have?
	float flCurrent = [self getCurrency:strCurrency];
	// If we don't have enough, we can't afford it.
	if (flCost > flCurrent)
		return NO;

	// Otherwise, we can afford this portion.
	return YES;
}

+ (BOOL)canAffordCost:(NSDictionary*)defCosts
{
	// If there are no entries, we can afford it.
	if ([defCosts count] < 1)
		return YES;

	// Go through the required entries...
	for (NSString *strItem in defCosts)
	{
		// What is the required cost of this currency?
		float flCost = [[defCosts objectForKey:strItem] floatValue];
		// If we don't have enough, bail out early.
		if ([self canAffordCost:flCost forCurrency:strItem] == NO)
			return NO;
	}

	// If we got here, we passed all the tests!
	return YES;
}

+ (BOOL)applyCost:(NSDictionary*)defCosts
{
	// It's slow, but we're going to do a full check
	// before applying any costs, so that we're atomic-ish.
	if ([self canAffordCost:defCosts] == NO)
		return NO;

	// Go through the required entries...
	for (NSString *strItem in defCosts)
	{
		// What is the required cost of this currency?
		int nCost = [[defCosts objectForKey:strItem] integerValue];

		[self adjustCurrency:strItem withDelta:(-nCost)];
	}

	// If we got here, we passed all the tests!
	return YES;

}

+ (NSString*)getCostString:(NSDictionary*)defCosts
{
	NSMutableString *strCosts = [NSMutableString stringWithString:@"Cost: "];
	{
		int nNumCosts = [defCosts count];
		if (nNumCosts > 0)
		{
			MRDefinitions *defsMan = [MRDefinitions sharedDefsManager];
			int nItem = 1;
			for (NSString *strItem in defCosts)
			{
				// Get the title and value for this...
				NSDictionary *defCostItem = [defsMan getDefByClass:ENTRY_CURRENCY Type:strItem];
				NSString *strName = [defCostItem objectForKey:ENTRY_NAME];
				int nCost = [[defCosts objectForKey:strItem] integerValue];
				NSString *strCostItem = [NSString stringWithFormat:@"%d %@", nCost, strName];
				[strCosts appendString:strCostItem];
				if (nItem < nNumCosts)
					[strCosts appendString:@", "];
				++nItem;
			}
		}
		else
		{
			[strCosts appendString:@"Free"];
		}
	}

	return strCosts;
}

+ (void)clearLevelCurrencies
{
	// Get all our possible currencies.
	NSArray *arrCurrencies = [[MRDefinitions sharedDefsManager] getDefsOfClass:@"Currency"];

	// Set the "level" values all to zero.
	for (NSString *strCurrency in arrCurrencies)
	{
		NSString *strKey = [NSString stringWithFormat:@"%@:%@",
							[MRUtilities getKeyForLevelWithStyle:EKS_CURRENCY], strCurrency];
		[MRUtilities setContentIntForKey:strKey withInt:0];
	}
}

+ (int)getCurrencyCountForLevel
{
	MRDefinitions *defsMan = [MRDefinitions sharedDefsManager];
	NSArray *arrCurrencies = [defsMan getDefsOfClass:@"Currency"];
	int nGainedCount = 0;
	for (NSString *strCurrency in arrCurrencies)
	{
		int nGained = [self getCurrencyForLevel:strCurrency];
		if (nGained > 0)
		{
			++nGainedCount;
		}
	}
	return nGainedCount;
}

@end

#endif
