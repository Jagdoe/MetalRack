//
//  DefsManager.h
//  Zombie
//
//  Created by Michael Scandizzo on 6/15/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRSceneConfiguration.h"

#pragma mark -
#pragma mark MRDefinitions

@interface MRDefinitions : NSObject
{
	NSMutableDictionary	*m_dictLookup;
	NSMutableDictionary *m_dictFlatLookup;
    NSMutableDictionary *m_dictHashLookup;
    NSMutableDictionary *m_dictGroupLookup;
    NSMutableDictionary *m_classAliases;

    // Collections.
    NSArray     *m_aCollections;

    // AddOns.
    NSArray     *m_aAddons;

}

+ (MRDefinitions *)sharedDefsManager;
- (void)registerClass:(Class)type forDefinitionName:(NSString *)name;


- (id)init;
- (void)loadDefinitions:(NSString*)plist;
- (void)dealloc;

- (NSDictionary *)getDefByName:(NSString *)strName;
- (NSDictionary *)getDefByClass:(NSString *)strClass Type:(NSString *)strType;
- (BOOL)doesExistByClass:(NSString *)strClass Type:(NSString *)strType;

- (NSArray *)getDefsOfClass:(NSString *)strClass;
- (NSArray *)getDefsOfClass:(NSString *)strClass addSubclasses:(BOOL)fAddSubclasses;
- (Class)getClassByName:(NSString *)strName;
- (Class)getClassByDef:(NSDictionary *)dictDef;
- (NSString *)getNameByDef:(NSDictionary *)dictDef;

// Utility convenience functions.
- (NSString*)getDefTitle:(NSDictionary*)dictDef usePlural:(BOOL)fUsePlural;
- (NSString*)getDefTitleByName:(NSString *)strName usePlural:(BOOL)fUsePlural;
- (NSString*)getDefTitleByClass:(NSString *)strClass Type:(NSString *)strType usePlural:(BOOL)fUsePlural;
- (NSString*)getDefDeathMessageByName:(NSString *)strName;

// Some things are in array entries (lists of Shields, etc.)
// These will vary by set.
- (NSMutableArray *)getArrayOfAllSets;
- (NSDictionary*)getDictionaryForSet:(int)nSet;
- (NSString*)getBaseNameForSet:(int)nSet withMission:(int)nMission;
- (NSString*)getNameForSet:(int)nSet withMission:(int)nMission;
- (NSDictionary*)getDefinitionForSet:(int)nSet withMission:(int)nMission;
- (NSArray *)getArrayByClass:(NSString *)strClass forSet:(int)nSet;

#pragma mark -
#pragma mark Value Retrieval.
- (int)getIntFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(int)nDefault;
- (BOOL)getBoolFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(BOOL)fDefault;
- (float)getFloatFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(float)flDefault;
- (NSString*)getStringFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(NSString*)strDefault;

#pragma mark -
#pragma mark Object Groups.
// Get by object group.
- (int)getNumObjectGroups;
- (NSArray *)getArrayOfDefsByGroupName:(NSString*)strGroup;
- (NSArray *)getArrayOfNamesByGroupName:(NSString*)strGroup;
- (NSArray *)getArrayOfDefsByGroupIndex:(int)nIndex;
- (NSArray *)getArrayOfNamesByGroupIndex:(int)nIndex;

// Hash Indexing
- (void)hashClass:(NSString *)strClass;
- (NSDictionary *)getDefByHash:(NSUInteger)nHash;

// Alternates
- (NSDictionary *)getRandomAltDef:(NSDictionary *)dictOriginal;
- (NSDictionary *)getFallbackDef:(NSDictionary *)dictOriginal;

#pragma mark -
#pragma mark Collections
- (NSDictionary*)getDefForCollectionID:(NSString*)strID;
- (NSArray*)getCollectionDefinitions;
- (NSString*)getTitleForComponent:(NSString*)strComponent inCollectionDef:(NSDictionary*)defCollection;

#pragma mark -
#pragma mark Add-Ons
- (NSArray*)getAddonDefinitions;
- (NSDictionary*)getDefForAddOnID:(NSString*)strID;
- (NSString*)getTitleForAddOnID:(NSString*)strID;
- (NSString*)getTitleForAddOn:(NSDictionary*)dictAddon;


@end
