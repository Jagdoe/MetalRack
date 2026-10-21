//
//  CurrencyManager.h
//  Gnomes
//
//  Created by Tom Ricket on 12/28/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MRCurrencyStore : NSObject

+ (MRCurrencyStore *)sharedCurrencyManager;
+ (float)getCurrency:(NSString*)strCurrency;
+ (float)getCurrencyForLifetime:(NSString*)strCurrency;
+ (float)getCurrencyForLevel:(NSString*)strCurrency;
+ (float)adjustCurrency:(NSString*)strCurrency withDelta:(float)flDelta;
+ (NSString*)getCurrencyName:(NSString*)strCurrency;
+ (NSString*)getCurrencyAvailableString;
+ (BOOL)canAffordCost:(float)flCost forCurrency:(NSString*)strCurrency;
+ (BOOL)canAffordCost:(NSDictionary*)defCosts;
+ (BOOL)applyCost:(NSDictionary*)defCosts;
+ (NSString*)getCostString:(NSDictionary*)defCosts;
+ (void)clearLevelCurrencies;
+ (int)getCurrencyCountForLevel;

@end
