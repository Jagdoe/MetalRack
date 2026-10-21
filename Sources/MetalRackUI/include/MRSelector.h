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
