#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  GridPointObject.m
//  Gnomes
//
//  Created by Tom Ricket on 2/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MRGridPoint.h"

@implementation MRGridPoint

@synthesize nX;
@synthesize nY;

const TGridPoint GridPointInvalid = {INVALID_POS, INVALID_POS};

+ (MRGridPoint *)gridPointObjectWithPoint:(TGridPoint)point
{
    MRGridPoint *obPoint = ([[MRGridPoint alloc] initWithGridPoint:point]);
    return obPoint;
}

+ (MRGridPoint *)gridPointObjectWithObject:(MRGridPoint*)obSource
{
    MRGridPoint *obPoint = ([[MRGridPoint alloc] initWithObject:obSource]);
    return obPoint;
}

+ (MRGridPoint *)gridPointObjectWithX:(int)nX withY:(int)nY
{
    TGridPoint gpoint = GridPointMake(nX, nY);
    return [self gridPointObjectWithPoint:gpoint];
}

- (void)setNX:(int)nNewX
{
	m_point.nX = nNewX;
}

- (void)setNY:(int)nNewY
{
	m_point.nY = nNewY;
}

- (int)nX
{
	return m_point.nX;
}

- (int)nY
{
	return m_point.nY;
}

- (MRGridPoint *)initWithGridPoint:(TGridPoint)point
{
    self = [super init];
    if (self != nil)
    {
        m_point = point;
    }
    return self;
}

- (MRGridPoint *)initWithObject:(MRGridPoint*)obSource
{
    self = [super init];
    if (self != nil)
    {
        if (obSource != nil)
            m_point = [obSource gridPointValue];
    }
    return self;
}

- (TGridPoint)gridPointValue
{
    return m_point;
}

- (NSString*)description
{
    return GridPointToString(m_point);
}

- (BOOL)isEqual:(id)anObject
{
	if ([anObject isKindOfClass:[MRGridPoint class]] == NO)
		return NO;
	MRGridPoint *gpOther = (MRGridPoint *)anObject;
	TGridPoint pOther = [gpOther gridPointValue];
    return GridPointsAreEqual(m_point, pOther);
}

- (NSUInteger)hash
{
	return (m_point.nY * 64000 + m_point.nX);
}

@end


#endif
