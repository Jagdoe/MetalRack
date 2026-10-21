//
//  GridPointObject.h
//  Gnomes
//
//  Created by Tom Ricket on 2/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

//********************************************************************************
#pragma mark -
#pragma mark TGridPoint
//
//	like CGPoint, but with ints
//********************************************************************************

#define INVALID_POS     (-1)

typedef struct
{
    int nX;
    int nY;
} TGridPoint;
const extern TGridPoint GridPointInvalid;

static inline BOOL GridPointIsInvalid(TGridPoint tPos)
{
//    return (tPos.nX == GridPointInvalid.nX || tPos.nY == GridPointInvalid.nY);
    return (tPos.nX < 0 || tPos.nY < 0);
}

static inline TGridPoint GridPointMake(int x, int y)
{
    TGridPoint p; p.nX = x; p.nY = y; return p;
}

static inline NSString* GridPointToString(TGridPoint tPoint)
{
    return [NSString stringWithFormat:@"{%d, %d}", tPoint.nX, tPoint.nY];
}

static inline TGridPoint GridPointFromString(NSString *strPoint)
{
    CGPoint ptTemp = CGPointFromString(strPoint);
    TGridPoint tPos; tPos.nX = (int)ptTemp.x; tPos.nY = (int)ptTemp.y; return tPos;
}

static inline BOOL GridPointsAreEqual(TGridPoint ptA, TGridPoint ptB)
{
    if (ptA.nX == ptB.nX && ptA.nY == ptB.nY)
        return YES;
    return NO;
}
//********************************************************************************
#pragma mark -
#pragma mark TGridRect
//
// like CGRect, but ints with TopLeft and Bottom Right
//********************************************************************************

typedef struct
{
    TGridPoint  posTL;
    TGridPoint  posBR;
} TGridRect;

static inline TGridRect GridRectFromPoints(TGridPoint pTL, TGridPoint pBR)
{
    TGridRect r;
    r.posTL = pTL;
    r.posBR = pBR;
    return r;
}

static inline TGridRect GridRectFromValues(int nL, int nT, int nR, int nB)
{
    TGridRect r;
    r.posTL = GridPointMake(nL, nT);
    r.posBR = GridPointMake(nR, nB);
    return r;
}

static inline NSString* GridRectToString(TGridRect tRect)
{
    return [NSString stringWithFormat:@"[%@ - %@]",
            GridPointToString(tRect.posTL), GridPointToString(tRect.posBR)];
}

@interface MRGridPoint : NSObject
{
    TGridPoint m_point;
}

@property (nonatomic, assign)	int nX;
@property (nonatomic, assign)	int nY;

+ (MRGridPoint *)gridPointObjectWithPoint:(TGridPoint)point;
+ (MRGridPoint *)gridPointObjectWithObject:(MRGridPoint*)obSource;
+ (MRGridPoint *)gridPointObjectWithX:(int)nX withY:(int)nY;
- (MRGridPoint *)initWithGridPoint:(TGridPoint)point;
- (MRGridPoint *)initWithObject:(MRGridPoint*)obSource;
- (TGridPoint)gridPointValue;
- (NSString*)description;

@end
