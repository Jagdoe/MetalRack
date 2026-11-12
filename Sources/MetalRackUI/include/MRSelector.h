//
//  SelectorObject.h
//  Fingerzilla
//
//  Created by Michael Scandizzo on 10/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MRSelector : NSObject
{
    id      m_idTarget;
    SEL     m_selector;
}

- (id)initWithSelector:(SEL)selector withTarget:(id)idTarget;
- (void)callMethod;
- (void)callMethodWithObject:(id)idObject1;
- (void)callMethodWithObject:(id)idObject1 withObject:(id)idObject2;

@end

// Dynamic callbacks have a void result and zero, one or two object arguments.
// NSInvocation uses the actual method signature rather than ARC guessing the
// ownership of an unknown performSelector return value.
FOUNDATION_EXPORT void MRInvokeCallback(id target, SEL selector, NSUInteger count, id first, id second);
