#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  NSDictionary+DeepCopy.m
//  Gnomes
//
//  Created by Michael Scandizzo on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSDictionary+DeepCopy.h"

@implementation NSDictionary (DeepCopy)

+ (id)dictionaryDeepCopiedFromDictionary:(NSDictionary *)dict
{
	NSMutableDictionary *dictCopy = ([[NSMutableDictionary alloc] initWithCapacity:[dict count]]);
	NSArray *aKeys = [dict allKeys];


	for (id key in aKeys)
	{
		id obValue = [dict valueForKey:key];
		if ([obValue isKindOfClass:[NSDictionary class]] == YES)
		{
			obValue = [NSDictionary dictionaryDeepCopiedFromDictionary:obValue];
		}
		[dictCopy setObject:obValue forKey:key];
	}
	(void)0;

	return dictCopy;
}


@end

#endif
