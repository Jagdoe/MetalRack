/*
 *  2DMath.h
 *  Zombie
 *
 *  Created by Michael Scandizzo on 3/2/10.
 *  Copyright 2010 Apple Inc. All rights reserved.
 *
 */

#import <CoreGraphics/CGGeometry.h>
#import <objc/objc.h>				// for BOOL


CGFloat angleBetweenPoints(CGPoint first, CGPoint second) ;

CGFloat angleBetweenLines(CGPoint line1Start, CGPoint line1End, CGPoint line2Start, CGPoint line2End);
CGFloat angleBetweenVectors(CGPoint vAlpha, CGPoint vBeta);


CGFloat dot(CGPoint pA, CGPoint pB);
CGFloat cross(CGPoint pA, CGPoint pB);
CGFloat length(CGPoint pA);
CGPoint normalize(CGPoint pA);
CGPoint scale(CGPoint pA, float flScalar);
CGPoint add(CGPoint pA, CGPoint pB);
CGPoint subtract(CGPoint pA, CGPoint pB);

CGPoint rotateVectorByAngle(CGPoint vAlpha, CGFloat flAngle);


BOOL circleIntersectCircle(CGPoint pCenterA, CGFloat flRadiusA, CGPoint pCenterB, CGFloat flRadiusB);
BOOL rayCircleIntersect(CGPoint pRayOrigin, CGPoint vRay, CGPoint pCircleCenter, CGFloat flCircleRadius);
BOOL pointAngleIntersect(CGPoint pPoint, CGPoint pOrigin, CGPoint vRayAlpha, CGPoint vRayBeta);
BOOL pointInsideTriangle(CGPoint pPoint, CGPoint pA, CGPoint pB, CGPoint pC);

CGRect rectAddRect(CGRect rectA, CGRect rectB);
