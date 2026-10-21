#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  CGPointOb.m
//  Soap Rack
//
//  Created by Tom Ricket on 11/10/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

// Note: This cannot be "CGPointObject" or it conflicts with a CCParallax item.

#import "MRPointValue.h"

@implementation MRPointValue

@synthesize ptPoint = m_ptPoint;

+(MRPointValue*) CGPointObWithPoint:(CGPoint)ptPoint
{
    MRPointValue *obNew = [MRPointValue alloc];
    [obNew initWithPoint:ptPoint];
    (obNew);
    return obNew;
}

-(id)initWithPoint:(CGPoint)ptPoint
{
    self = [super init];
    if (self != nil)
    {
        m_ptPoint = ptPoint;
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ([aDecoder containsValueForKey:@"x"] == YES)
        m_ptPoint.x = [aDecoder decodeIntForKey:@"x"];

    if ([aDecoder containsValueForKey:@"y"] == YES)
        m_ptPoint.x = [aDecoder decodeIntForKey:@"y"];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInteger:m_ptPoint.x forKey:@"x"];
    [aCoder encodeInteger:m_ptPoint.y forKey:@"y"];
}


@end

#endif
