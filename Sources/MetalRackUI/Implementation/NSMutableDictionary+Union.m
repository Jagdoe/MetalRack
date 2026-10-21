#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  NSMutableDictionary+Union.m
//  Gnomes
//
//  Created by Michael Scandizzo on 4/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSMutableDictionary+Union.h"

@implementation NSMutableDictionary (Union)

- (void)unionEntriesFromDictionary:(NSDictionary *)dictOther
{
    // If we have "do not inherit" boolean, don't do anything further.
    if ([[dictOther objectForKey:@"do not inherit"] boolValue] == YES)
    {
        NSLog(@"Skipping union for sub-dictionary.");
        return;
    }

    // Otherwise, go through all our sub-entries.
	for (NSString *strEntry in dictOther)
	{
		id obNewValue = [dictOther objectForKey:strEntry];
		id obOldValue = [self objectForKey:strEntry];

		if (obOldValue == nil)
		{
            if ([obNewValue isKindOfClass:[NSString class]] == YES)
            {
                if ([obNewValue isEqualToString:@"do not inherit"] == YES)
                {
//                    NSLog(@"Bye!");
                    continue;
                }
            }
			[self setValue:obNewValue forKey:strEntry];
		}
		else
		{
			// If our entries are two different kinds, we have undefined behavior.
			// For now, keep the original data.
			if ([obNewValue class] != [obOldValue class])
				continue;

			if ([obOldValue isKindOfClass:[NSDictionary class]] == YES)
			{
				obOldValue = [obOldValue mutableCopy];
				[obOldValue unionEntriesFromDictionary:obNewValue];
				[self setValue:obOldValue forKey:strEntry];
			}
			else if ([obOldValue isKindOfClass:[NSArray class]] == YES)
			{
                // Ignore NEW arrays who have a first entry of "do not inherit" ...
                NSArray *arrNew = (NSArray*)obNewValue;
                if ([arrNew count] > 0)
                {
                    id obFirst = [arrNew objectAtIndex:0];
//                    NSLog(@"Class of %@ is %@.", obFirst, [obFirst class]);
                    if ([obFirst isKindOfClass:[NSString class]] == YES)
                    {
                        NSString *strFirst = (NSString*)obFirst;
                        if ([strFirst isEqualToString:@"do not inherit"] == YES)
                        {
//                            NSLog(@"Tom was here.");
                            continue;
                        }
                    }
                }
				NSMutableArray *aOldValue = [obOldValue mutableCopy];
				[aOldValue addObjectsFromArray:obNewValue];
				[self setValue:aOldValue forKey:strEntry];
			}
			else if ([obOldValue isKindOfClass:[NSSet class]] == YES)
			{
				NSMutableSet *setOldValue = [obOldValue mutableCopy];
				[setOldValue unionSet:obNewValue];
				[self setValue:setOldValue forKey:strEntry];
			}
			// Any other type is currently undefined as well
		}
	}
}

@end

#endif
