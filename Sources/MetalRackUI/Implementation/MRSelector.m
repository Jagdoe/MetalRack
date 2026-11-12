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

void MRInvokeCallback(id target, SEL selector, NSUInteger count, id first, id second) {
    if(!target)return;
    NSMethodSignature *signature=[target methodSignatureForSelector:selector];
    NSCAssert(signature && signature.numberOfArguments==count+2,@"Invalid callback signature %@",NSStringFromSelector(selector));
    NSInvocation *invocation=[NSInvocation invocationWithMethodSignature:signature];
    invocation.selector=selector;
    if(count>0)[invocation setArgument:&first atIndex:2];
    if(count>1)[invocation setArgument:&second atIndex:3];
    [invocation invokeWithTarget:target];
}

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
    MRInvokeCallback(m_idTarget, m_selector, 0, nil, nil);
}

- (void)callMethodWithObject:(id)idObject1
{
    MRInvokeCallback(m_idTarget, m_selector, 1, idObject1, nil);
}

- (void)callMethodWithObject:(id)idObject1 withObject:(id)idObject2
{
    MRInvokeCallback(m_idTarget, m_selector, 2, idObject1, idObject2);
}

@end

#endif
