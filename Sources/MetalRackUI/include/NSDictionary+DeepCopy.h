//
//  NSDictionary+DeepCopy.h
//  Gnomes
//
//  Created by Michael Scandizzo on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (DeepCopy)

+ (id)dictionaryDeepCopiedFromDictionary:(NSDictionary *)dict;

@end
