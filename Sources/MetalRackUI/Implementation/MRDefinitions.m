#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  DefsManager.m
//  Zombie
//
//  Created by Michael Scandizzo on 6/15/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRDefinitions.h"
#import "MRUIKit.h"
#import "NSMutableDictionary+Union.h"
#import "MRFileCache.h"

#define ENTRY_NAME				@"name"
#define ENTRY_NAME_PLURAL		@"name plural"
#define ENTRY_BASE_TYPE			@"base type"
#define ENTRY_LEVEL_ADD			@"level add"
#define ENTRY_MESSAGE_KILLED	@"message killed player"	// Message for when this item kills the player.
#define ENTRY_OBJECT_GROUP      @"objectGroup"

@implementation MRDefinitions

static MRDefinitions     *m_sSingleton = nil;

+ (id)sharedDefsManager
{
    if (m_sSingleton == nil)
    {
        m_sSingleton = [[MRDefinitions alloc] init];
    }
    return m_sSingleton;
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		m_dictLookup = nil;
		m_dictFlatLookup = nil;
        m_dictHashLookup = nil;
        m_dictGroupLookup = nil;
        m_aCollections = nil;
        m_aAddons = nil;
	}
	return self;
}

-(void)localParseSingleDefinition:(NSMutableDictionary *)dictEntry named:(NSString *)strEntry className:(NSString *)strClassName
{
	[dictEntry setValue:strClassName forKey:@"className"];
	[dictEntry setValue:strEntry forKey:@"typeName"];

	// Also add to our grouped dictionary.
	NSString *strGroup = [dictEntry objectForKey:ENTRY_OBJECT_GROUP];
	if (strGroup != nil)
	{
		// See if we already have an array of this name.
		NSMutableArray *arrayGroup = [m_dictGroupLookup objectForKey:strGroup];
		if (arrayGroup == nil)
		{
			//                        NSLog(@"First time for type [%@]!", strGroup);
			arrayGroup = [[NSMutableArray alloc] initWithCapacity:1];
			[m_dictGroupLookup setValue:arrayGroup forKey:strGroup];
		}
		[arrayGroup addObject:dictEntry];
		//                    NSLog(@"  Adding [%@] to group [%@].", strEntry, strGroup);
	}
}

- (void)recursiveParse:(NSMutableDictionary *)dictSource named:(NSString *)strClassName
{
	// We're parsing in only CLASS entries here.
    NSArray *aKeys = [dictSource allKeys];
	for (NSString *strEntry in aKeys)
	{
		NSString *strSubstring = [strEntry substringToIndex:1];
		NSMutableDictionary *dictEntry = [dictSource objectForKey:strEntry];

		if ([strEntry isEqualToString:@"@instance"])
		{
			// @instance is a sub-dictionary containing all instance definitions
			[self recursiveParse:dictEntry named:strClassName];

            // Don't store a duplicate for the @instance objects.
            [dictSource removeObjectForKey:strEntry];
		}
		else if ([strSubstring isEqualToString:[strSubstring uppercaseString]] == YES)
		{
//            NSLog(@"DefsMan: Adding Class [%@]", strEntry);
			if ([dictEntry isKindOfClass:[NSDictionary class]] == YES)
			{
				// Add our instance children
				NSDictionary *dictInstances = [dictEntry objectForKey:@"@instance"];
				NSMutableDictionary *dictCompleteEntry = [NSMutableDictionary dictionaryWithDictionary:dictEntry];
				[dictCompleteEntry addEntriesFromDictionary:dictInstances];
				dictEntry = dictCompleteEntry;

				[self recursiveParse:dictEntry named:strEntry];
			}
			[m_dictLookup setObject:dictEntry forKey:strEntry];

		}
		else
		{
			if ([dictEntry isKindOfClass:[NSMutableDictionary class]] == YES)
			{
				[self localParseSingleDefinition:dictEntry named:strEntry className:strClassName];
			}
			// Non-class entries also get added to the flat lookup.
			//			NSLog(@"Flat: Adding [%@] as %d (%x)", strEntry, strEntry.hash, strEntry.hash);
			//			NSLog(@"%@,%d", strEntry, strEntry.hash);
			[m_dictFlatLookup setObject:dictEntry forKey:strEntry];
//            [dictSource setObject:dictEntry forKey:strEntry];
		}
	}
}

- (void)localProcessInheritanceFor:(NSString *)strEntry withDef:(NSDictionary *)dictDef
{
    if ([dictDef isKindOfClass:[NSDictionary class]] == NO)
        return;
    NSString *strInherits = [dictDef objectForKey:@"inherits"];
    if (strInherits == nil)
        return;
    NSDictionary *dictInheritsDef = [self getDefByName:strInherits];
    if (dictInheritsDef == nil)
        return;

    if ([dictInheritsDef objectForKey:@"inherits"] != nil)
    {
        [self localProcessInheritanceFor:strInherits withDef:dictInheritsDef];
        dictInheritsDef = [self getDefByName:strInherits];
    }

    NSMutableDictionary *dictCombinedDef = [NSMutableDictionary dictionaryWithDictionary:dictDef];

    [dictCombinedDef unionEntriesFromDictionary:dictInheritsDef];

    // Prevent us from doing this twice
    [dictCombinedDef removeObjectForKey:@"inherits"];

    // Replace our entry in the flat lookup
    [m_dictFlatLookup setValue:dictCombinedDef forKey:strEntry];

    // Replace us in the group lookup
    NSString *strGroup = [dictCombinedDef objectForKey:ENTRY_OBJECT_GROUP];
    if (strGroup != nil)
    {
        NSMutableArray *arrayGroup = [m_dictGroupLookup objectForKey:strGroup];
        [arrayGroup removeObject:dictDef];
        [arrayGroup addObject:dictCombinedDef];
    }
}

- (void)localProcessInheritance
{
	NSArray *aKeys = [m_dictFlatLookup allKeys];
	for (NSString *strEntry in aKeys)
	{
		NSDictionary *dictDef = [self getDefByName:strEntry];

        [self localProcessInheritanceFor:strEntry withDef:dictDef];
	}
}

- (void)replaceLookup
{
    [self recursiveReplaceLookup:m_dictLookup];
}

- (void)recursiveReplaceLookup:(NSMutableDictionary *)dictSource
{
	// We're parsing in only CLASS entries here.
    NSArray *aEntries = [dictSource allKeys];
	for (NSString *strEntry in aEntries)
	{
		NSString *strSubstring = [strEntry substringToIndex:1];
		NSMutableDictionary *dictEntry = [dictSource objectForKey:strEntry];

		// Parse a class
        if ([strSubstring isEqualToString:[strSubstring uppercaseString]] == YES)
		{
			if ([dictEntry isKindOfClass:[NSDictionary class]] == YES)
			{
				[self recursiveReplaceLookup:dictEntry];
			}
		}
		else
		{
			if ([dictEntry isKindOfClass:[NSMutableDictionary class]] == YES)
			{
                NSDictionary *dictFlatLookup = [self getDefByName:strEntry];
                [dictSource setValue:dictFlatLookup forKey:strEntry];
			}
		}
	}
}


- (void)loadDefinitions:(NSString*)plist
{

	if (m_dictLookup != nil)
		(void)0;
	if (m_dictFlatLookup != nil)
		(void)0;
	if (m_dictGroupLookup != nil)
        (void)0;

	NSString *path = [MRBundleResources pathForResource:plist];
	NSMutableDictionary *dictionary = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] mutableCopy];

	m_dictLookup = [[NSMutableDictionary alloc] init];
	m_dictFlatLookup = [[NSMutableDictionary alloc] init];
	m_dictGroupLookup = [[NSMutableDictionary alloc] init];

	[self recursiveParse:dictionary named:@"Root"];
	(void)0;

    [self localProcessInheritance];
    [self replaceLookup];

    // Get our collections, if we have them.
    NSString *strCollections = @"collections.plist";
	NSString *pathCollections = [MRBundleResources pathForResource:strCollections];
	if (pathCollections != nil)
	{
        m_aCollections = ([NSArray arrayWithContentsOfFile:pathCollections]);
	}

    // Get our add-ons, if we have them.
    NSString *strAddons = @"addons.plist";
    NSString *pathAddons = [MRBundleResources pathForResource:strAddons];
    if (pathAddons != nil)
    {
        m_aAddons = ([NSArray arrayWithContentsOfFile:pathAddons]);
    }
}

- (NSMutableArray *)getArrayOfAllSets
{
	int i = 0;
	NSMutableArray *aAllSets = ([[NSMutableArray alloc] initWithCapacity:4]);
	while (1)
	{
		NSDictionary *dictSet = [self getDictionaryForSet:i];
		if (dictSet == nil)
			break;
		i++;
		[aAllSets addObject:dictSet];
	}
	return aAllSets;
}

- (void)registerClass:(Class)type forDefinitionName:(NSString *)name { if(!m_classAliases)m_classAliases=[NSMutableDictionary new];m_classAliases[name]=type; }

- (Class)getClassByDef:(NSDictionary *)dictDef
{
	NSString *strClass = [dictDef objectForKey:@"className"];
	if (strClass != nil)
		return m_classAliases[strClass] ?: NSClassFromString(strClass);
	return nil;
}

- (NSString *)getNameByDef:(NSDictionary *)dictDef
{
	NSString *strName = [dictDef objectForKey:@"typeName"];
	return strName;
}

- (Class)getClassByName:(NSString *)strName
{
	NSDictionary *dictDef = [m_dictFlatLookup objectForKey:strName];
	return [self getClassByDef:dictDef];
}

- (NSDictionary *)getDefByName:(NSString *)strName
{
	NSDictionary *dictDef = [m_dictFlatLookup objectForKey:strName];
	return dictDef;
}

- (NSDictionary *)getDefByClass:(NSString *)strClass Type:(NSString *)strType
{
    // If type is nil, that means just return the class.
    if ([strClass length] < 1)
        return nil;

    NSDictionary *dictClass = nil;
	NSDictionary *dictDef = nil;

	dictClass = [m_dictLookup objectForKey:strClass];

    if (strType == nil)
        return dictClass;

    // By this point, we know we're looking for an actual instance of the class.
    dictDef = [dictClass objectForKey:strType];

	if (dictDef == nil)
	{
        // Also check the "@instance" level.
        dictClass = [dictClass objectForKey:@"@instance"];
        dictDef = [dictClass objectForKey:strType];
        if (dictDef == nil)
        {
            NSLog(@"Error: No definition for %@ : %@!  Use doesExistByClass if just querying.", strClass, strType);
        }
	}

	return dictDef;
}

- (BOOL)doesExistByClass:(NSString *)strClass Type:(NSString *)strType
{
	NSDictionary *dictDef = [m_dictLookup objectForKey:strClass];
	id idType = [dictDef objectForKey:strType];
	if (idType == nil)
    {
        // Also check "@instance" level.
        dictDef = [dictDef objectForKey:@"@instance"];
        idType = [dictDef objectForKey:strType];
        if (idType == nil)
            return NO;
    }
	return YES;
}

- (void)recursiveAddDefs:(NSDictionary*)dictDef toArray:(NSMutableArray*)arrDefs
{
	if (dictDef == nil)
		return;

	for (NSString *strEntry in dictDef)
	{
		NSString *strSubstring = [strEntry substringToIndex:1];
		if ([strSubstring isEqualToString:[strSubstring uppercaseString]] == YES)
		{
			// We're a sub-class, so add all its items.
			NSDictionary *dictEntry = [dictDef objectForKey:strEntry];
			[m_dictLookup setValue:dictEntry forKey:strEntry];
			if ([dictEntry isKindOfClass:[NSDictionary class]] == YES)
			{
				[self recursiveAddDefs:dictEntry toArray:arrDefs];
			}
		}
		else
		{
			// We're a valid entry.  Add it.
			[arrDefs addObject:strEntry];
		}
	}
}

- (NSArray *)getDefsOfClass:(NSString *)strClass
{
    return [self getDefsOfClass:strClass addSubclasses:NO];
}

// Return a flattened string list of all the instances of this class.
- (NSArray *)getDefsOfClass:(NSString *)strClass addSubclasses:(BOOL)fAddSubclasses
{
	NSDictionary *dictDef = [m_dictLookup objectForKey:strClass];
	if (dictDef == nil)
		return nil;

	NSMutableArray *arrDefs = [NSMutableArray arrayWithCapacity:8];
    if (fAddSubclasses == YES)
    {
        [self recursiveAddDefs:dictDef toArray:arrDefs];
    }
    else
    {
        // Just add the top-level, non-class entries.
        for (NSString *strEntry in dictDef)
        {
            NSString *strSubstring = [strEntry substringToIndex:1];
            if ([strSubstring isEqualToString:[strSubstring uppercaseString]] == NO)
            {
                // We're a valid entry.  Add it.
                [arrDefs addObject:strEntry];
            }
            else if ([strEntry isEqualToString:@"@instance"])
            {
                // Treat @instance like our main one...
                NSDictionary *dictInstance = [dictDef objectForKey:strEntry];
                for (NSString *strEntryInstance in dictInstance)
                {
                    strSubstring = [strEntryInstance substringToIndex:1];
                    if ([strSubstring isEqualToString:[strSubstring uppercaseString]] == NO)
                    {
                        [arrDefs addObject:strEntryInstance];
                    }
                }
            }
        }
    }
	return arrDefs;
}

- (NSString*)getDefTitle:(NSDictionary*)dictDef usePlural:(BOOL)fUsePlural
{
	NSString *strTitle = nil;
	if (fUsePlural == YES)
		strTitle = [dictDef objectForKey:ENTRY_NAME_PLURAL];
	if (fUsePlural == NO || strTitle == nil)
    {
		strTitle = [dictDef objectForKey:ENTRY_NAME];
        if (fUsePlural == YES)
            strTitle = [strTitle stringByAppendingString:@"s"];
    }

	if (strTitle == nil || [strTitle length] < 1)
		return @"Unknown Item";
	return strTitle;
}

- (NSString*)getDefTitleByName:(NSString *)strName usePlural:(BOOL)fUsePlural
{
	NSDictionary *dictDef = [self getDefByName:strName];
    return [self getDefTitle:dictDef usePlural:fUsePlural];
}

- (NSString*)getDefTitleByClass:(NSString *)strClass Type:(NSString *)strType usePlural:(BOOL)fUsePlural
{
	NSDictionary *dictDef = [self getDefByClass:strClass Type:strType];
    return [self getDefTitle:dictDef usePlural:fUsePlural];
}

- (NSString*)getDefDeathMessageByName:(NSString *)strName
{
	// This message is when the item kills the player, not when the item itself is killed.

	NSDictionary *dictDef = [self getDefByName:strName];

	// Allow array of messages.
	NSString *strMessage = nil;
	NSObject *obMessage = [dictDef objectForKey:ENTRY_MESSAGE_KILLED];
	if ([obMessage isKindOfClass:[NSArray class]] == YES)
	{
		NSArray *aMessages = (NSArray *)obMessage;
		int numEntries = [aMessages count];
		int nRandIndex = random() % numEntries;
		strMessage = [aMessages objectAtIndex:nRandIndex];
	}
	else
	{
		strMessage = (NSString *)obMessage;
	}

	if (strMessage == nil || [strMessage length] < 1)
		return @"Ach, zombies!";
	return strMessage;
}

-(NSDictionary*)getDictionaryForSet:(int)nSet
{
	// Read this in from our SET file.
	// Get the SET definition.
	NSString *strSet = [NSString stringWithFormat:@"set%d.plist", (nSet + 1)];

    // First try this from the FileCache (so dynamic can override bundle).
    MRFileCache *fcMain = [MRFileCache sharedFileCache];
    NSString *strPath = nil;
    if ([fcMain contains:strSet])
    {
        strPath = [fcMain getFullPath:strSet];
    }
    else
    {
        // Get the file from the bundle.
        strPath = [MRBundleResources pathForResource:strSet];
    }

	if (strPath == nil)
	{
		NSLog(@"ERROR: Set file %d is missing from bundle.", nSet);
		return nil;
	}
	NSDictionary *dictSet = ([[NSDictionary alloc] initWithContentsOfFile:strPath]);
	// Why does this fail if dictSet has come back nil?
//	if (dictSet != nil)
//	{
//		[strSet release];
//		[path release];
//	}
	return dictSet;
}

- (NSString*)getBaseNameForSet:(int)nSet withMission:(int)nMission
{
	return [NSString stringWithFormat:@"set%d_mission%d", (nSet+1), (nMission+1)];
}

- (NSString*)getNameForSet:(int)nSet withMission:(int)nMission
{
    NSString *strName = [self getBaseNameForSet:nSet withMission:nMission];
    strName = [strName stringByAppendingString:@".plist"];
	return strName;
}

- (NSDictionary*)getDefinitionForSet:(int)nSet withMission:(int)nMission
{
	NSString *strMission = [self getNameForSet:nSet withMission:nMission];

    // First try the FileCache (dynamic) version.
    MRFileCache *fcMain = [MRFileCache sharedFileCache];
    NSString *strPath = nil;
    if ([fcMain contains:strMission])
    {
        strPath = [fcMain getFullPath:strMission];
    }
    else
    {
        // Use the static (Bundle) version.
        strPath = [MRBundleResources pathForResource:strMission];
    }

	if (strPath == nil)
	{
		NSLog(@"ERROR: Mission file %@ is missing from bundle or FileCache.", strMission);
		return nil;
	}
	NSDictionary *defMission = ([[NSDictionary alloc] initWithContentsOfFile:strPath]);
	return defMission;
}

- (NSArray *)getArrayByClass:(NSString *)strClass forSet:(int)nSet
{
	// First pass -- not cached.  Merge this in properly later.

	// Get the set list.
	NSDictionary *dictSet = [self getDictionaryForSet:nSet];
	if (dictSet == nil)
		return nil;

	// Try to find the appropriate array.
	NSArray *arrSet = [dictSet objectForKey:strClass];
	return arrSet;
}

#pragma mark -
#pragma mark Value Retrieval.
//
// These methods get a variable type from a definition,
// returning a default if it doesn't exist.
//
- (int)getIntFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(int)nDefault
{
    id idValue = [dictDef objectForKey:strKey];
    if (idValue == nil)
        return nDefault;
    return [idValue intValue];
}

- (BOOL)getBoolFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(BOOL)fDefault
{
    id idValue = [dictDef objectForKey:strKey];
    if (idValue == nil)
        return fDefault;
    return [idValue boolValue];
}

- (float)getFloatFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(float)flDefault
{
    id idValue = [dictDef objectForKey:strKey];
    if (idValue == nil)
        return flDefault;
    return [idValue floatValue];
}

- (NSString*)getStringFromDef:(NSDictionary*)dictDef forKey:(NSString*)strKey withDefault:(NSString*)strDefault
{
    id idValue = [dictDef objectForKey:strKey];
    if (idValue == nil)
        return strDefault;
    return idValue;
}

#pragma mark -
#pragma mark Object Groups.
// Get by object group.
- (int)getNumObjectGroups
{
    return [m_dictGroupLookup count];
}

- (NSArray *)getArrayOfDefsByGroupName:(NSString*)strGroup
{
    return [m_dictGroupLookup objectForKey:strGroup];
}

- (NSArray *)getArrayOfNamesByGroupName:(NSString*)strGroup
{
    NSMutableArray *arrDefs = [m_dictGroupLookup objectForKey:strGroup];
    int nItems = [arrDefs count];
    NSMutableArray *arrNames = [NSMutableArray arrayWithCapacity:nItems];
    for (NSDictionary *defItem in arrDefs)
    {
        NSString *strName = [defItem objectForKey:@"typeName"];
//        NSLog(@"Adding type [%@] to group [%@]", strName, strGroup);
        [arrNames addObject:strName];
    }
    return arrNames;
}

- (NSArray *)getArrayOfDefsByGroupIndex:(int)nIndex
{
    int nCurrent = 0;
    for (NSString *strGroup in m_dictGroupLookup)
    {
        if (nCurrent == nIndex)
            return [self getArrayOfDefsByGroupName:strGroup];
        ++nCurrent;
    }
    // Didn't find it!
    return nil;
}

- (NSArray *)getArrayOfNamesByGroupIndex:(int)nIndex
{
    NSArray *arrDefs = [self getArrayOfDefsByGroupIndex:nIndex];
    int nItems = [arrDefs count];
    NSMutableArray *arrNames = [NSMutableArray arrayWithCapacity:nItems];
    for (NSDictionary *defItem in arrDefs)
    {
        [arrNames addObject:[defItem objectForKey:@"typeName"]];
    }
    return arrNames;
}

#pragma mark -
#pragma mark Hash Indexing

- (void)hashClass:(NSString *)strClass
{
    if (m_dictHashLookup == nil)
    {
        m_dictHashLookup = ([NSMutableDictionary dictionaryWithCapacity:10]);
    }

    NSArray *aClassEntries = [self getDefsOfClass:strClass addSubclasses:YES];
    if (aClassEntries == nil || [aClassEntries count] == 0)
        return;

    for (NSString *strEntry in aClassEntries)
    {
        NSDictionary *dictEntry = [self getDefByName:strEntry];
        NSUInteger nHash = [strEntry hash];
        NSValue *valueHash = [NSNumber numberWithUnsignedInt:nHash];
//        NSLog(@"Hash: %@,%@", strEntry, valueHash);
        [m_dictHashLookup setObject:dictEntry forKey:valueHash];
    }
}

- (NSDictionary *)getDefByHash:(NSUInteger)nHash
{
    if (m_dictHashLookup == nil)
        return nil;

    NSValue *valueHash = [NSNumber numberWithUnsignedInt:nHash];
    NSDictionary *dictDef = [m_dictHashLookup objectForKey:valueHash];
    return dictDef;
}

- (NSDictionary *)getRandomAltDef:(NSDictionary *)dictOriginal
{
    NSArray *aAlts = [dictOriginal objectForKey:@"alts"];
    if (aAlts == nil)
        return dictOriginal;
    // Hack temp.
//    for (int i = 0; i < [aAlts count]; ++i)
//    {
//        NSString *strAlt = [aAlts objectAtIndex:i];
//        if ([strAlt rangeOfString:@"(Alt)"].location != NSNotFound)
//            return [self getDefByName:strAlt];
//    }
    int nCount = [aAlts count] + 1;
    int nIndex = random() % nCount;
    if (nIndex == 0)
    {
        return dictOriginal;
    }
    else
    {
        NSString *strAlt = [aAlts objectAtIndex:(nIndex - 1)];
        return [self getDefByName:strAlt];
    }
}

- (NSDictionary *)getFallbackDef:(NSDictionary *)dictOriginal
{
    NSString *strFallback = [dictOriginal objectForKey:@"fallback"];
    if (strFallback == nil)
        return dictOriginal;
    return [self getDefByName:strFallback];
}

#pragma mark -
#pragma mark Collections

- (NSDictionary*)getDefForCollectionID:(NSString*)strID
{
    if (strID == nil)
        return nil;

    if (m_aCollections == nil)
        return nil;

    // Go through our main dictionary.
    for (NSDictionary *dictAddOn in m_aCollections)
    {
        NSString *strItemID = [dictAddOn objectForKey:@"id"];
        if ([strID isEqualToString:strItemID])
            return dictAddOn;
    }

    // Couldn't find it.
    return nil;
}

- (NSArray*)getCollectionDefinitions
{
    return m_aCollections;
}

- (NSString*)getTitleForComponent:(NSString*)strComponent inCollectionDef:(NSDictionary*)defCollection
{
    if (strComponent == nil || defCollection == nil)
        return nil;

    NSArray *arrComponents = [defCollection objectForKey:@"components"];
    if (arrComponents == nil)
        return nil;

    for (NSDictionary *dictComponent in arrComponents)
    {
        if ([strComponent isEqualToString:[dictComponent objectForKey:@"id"]])
            return [dictComponent objectForKey:@"title"];
    }

    // Didn't find it.
    return nil;
}

#pragma mark -
#pragma mark Add-Ons

- (NSArray*)getAddonDefinitions
{
    return m_aAddons;
}

- (NSDictionary*)getDefForAddOnID:(NSString*)strID
{
    if (strID == nil)
        return nil;

    // Go through our main dictionary.
    for (NSDictionary *dictAddOn in m_aAddons)
    {
        NSString *strItemID = [dictAddOn objectForKey:@"id"];
        if ([strID isEqualToString:strItemID])
            return dictAddOn;
    }

    // Couldn't find it.
    return nil;
}

- (NSString*)getTitleForAddOnID:(NSString*)strID
{
    NSDictionary *dictAddon = [self getDefForAddOnID:strID];
    return [self getTitleForAddOn:dictAddon];
}

- (NSString*)getTitleForAddOn:(NSDictionary*)dictAddon
{
    if (dictAddon == nil)
        return nil;
    return [dictAddon objectForKey:@"title"];
}

- (void)dealloc
{
	if (m_dictLookup != nil)
		(void)0;
	if (m_dictFlatLookup != nil)
		(void)0;
    if (m_dictHashLookup != nil)
        (void)0;

    (void)0;
    m_aCollections = nil;

    (void)0;
    m_aAddons = nil;

	(void)0;
}

@end // DefsManager
#endif
