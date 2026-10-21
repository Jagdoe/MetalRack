#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  SelectorObject.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 10/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MRSelector.h"

@implementation MRSelector

- (id)initWithSelector:(SEL)selector withTarget:(id)idTarget
{
    self = [super init];
    if (self != nil)
    {
        m_idTarget = idTarget;
        m_selector = selector;
    }
    return self;
}

- (void)callMethod
{
    [m_idTarget performSelector:m_selector];
}

- (void)callMethodWithObject:(id)idObject1
{
    [m_idTarget performSelector:m_selector withObject:idObject1];
}

- (void)callMethodWithObject:(id)idObject1 withObject:(id)idObject2
{
    [m_idTarget performSelector:m_selector withObject:idObject1 withObject:idObject2];
}

@end

#endif
