//
//  NSMutableDictionary+Union.h
//  Gnomes
//
//  Created by Michael Scandizzo on 4/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableDictionary (Union)

- (void)unionEntriesFromDictionary:(NSDictionary *)dictOther;

@end
