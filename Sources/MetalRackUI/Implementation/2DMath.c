#include <TargetConditionals.h>
#if TARGET_OS_IOS
/*
 *  2DMath.c
 *  Zombie
 *
 *  Created by Michael Scandizzo on 3/2/10.
 *  Copyright 2010 Apple Inc. All rights reserved.
 *
 */

#import "2DMath.h"
#include "math.h"
#import <QuartzCore/QuartzCore.h>

//****************************************************************************************************

#if !defined(MAX)
#define MAX(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })
#endif

#if !defined(MIN)
#define MIN(A,B)	({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a > __b ? __b : __a; })
#endif

//----------------------------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------------------------
CGFloat angleBetweenPoints(CGPoint first, CGPoint second)
{
	CGFloat height = second.y - first.y;
	CGFloat width = first.x - second.x;
	CGFloat rads = atan(height/width);

	//return rads;
	return rads * (180.0f / M_PI);
	//degs = degrees(atan((top - bottom)/(right - left)))
}

//----------------------------------------------------------------------------------------------------
// AngleBetweenLines
//
//   Uses definition of dot product to calculate angle.
//   Cross product used to determine sign.
//----------------------------------------------------------------------------------------------------
CGFloat angleBetweenLines(CGPoint line1Start, CGPoint line1End, CGPoint line2Start, CGPoint line2End)
{

	CGFloat a = line1End.x - line1Start.x;
	CGFloat b = line1End.y - line1Start.y;
	CGFloat c = line2End.x - line2Start.x;
	CGFloat d = line2End.y - line2Start.y;

//	NSLog(@"Values <%f, %f> and  <%f,  %f>", a, b, c, d);

	float flValue = ((a*c) + (b*d)) / ((sqrt(a*a + b*b)) * (sqrt(c*c + d*d)));
	if (flValue < -1.0f)
		flValue = 1.0f;
	if (flValue > 1.0f)
		flValue = 1.0f;
	CGFloat rads = acos(flValue);

	float flSign = -1.0f;
	if (a*d - b*c >= FLT_EPSILON)
		flSign = 1.0f;


	return flSign * (rads * 180 / M_PI);
}

//----------------------------------------------------------------------------------------------------
// AngleBetweenVectors
//
//   Uses definition of dot product to calculate angle.
//   Cross product used to determine sign.
//----------------------------------------------------------------------------------------------------
CGFloat angleBetweenVectors(CGPoint vAlpha, CGPoint vBeta)
{
	CGFloat a = vAlpha.x;
	CGFloat b = vAlpha.y;
	CGFloat c = vBeta.x;
	CGFloat d = vBeta.y;

	CGFloat rads = acos(((a*c) + (b*d)) / ((sqrt(a*a + b*b)) * (sqrt(c*c + d*d))));
	if (isnan(rads) == YES)
		rads = 1.0f;

	float flSign = -1.0f;
	if (a*d - b*c >= FLT_EPSILON)
		flSign = 1.0f;


	return flSign * (rads * 180 / M_PI);

}

//----------------------------------------------------------------------------------------------------
//  Dot Product of two CGPoints
//
//		Dot product results in a scalar value
//----------------------------------------------------------------------------------------------------

CGFloat dot(CGPoint pA, CGPoint pB)
{
	return ((pA.x * pB.x) + (pA.y * pB.y));
}

//----------------------------------------------------------------------------------------------------
//  Cross Product of two CGPoints
//
//		Cross product of 2D vectors results in a Z value only
//----------------------------------------------------------------------------------------------------

CGFloat cross(CGPoint pA, CGPoint pB)
{
	return ((pA.x * pB.y) - (pA.y * pB.x));
}

//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

CGFloat length(CGPoint pA)
{
	return sqrt(dot(pA, pA));
}


//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

CGPoint normalize(CGPoint pA)
{
	CGFloat flLength = length(pA);
	return CGPointMake(pA.x / flLength, pA.y / flLength);
}

//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

CGPoint scale(CGPoint pA, float flScalar)
{
	return CGPointMake(pA.x * flScalar, pA.y * flScalar);
}

//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

CGPoint add(CGPoint pA, CGPoint pB)
{
	return CGPointMake(pA.x + pB.x, pA.y + pB.y);
}

//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

CGPoint subtract(CGPoint pA, CGPoint pB)
{
	return CGPointMake(pA.x - pB.x, pA.y - pB.y);
}

//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

CGPoint rotateVectorByAngle(CGPoint vAlpha, CGFloat flAngle)
{
	CGFloat flRad = flAngle * M_PI / 180;

	CGAffineTransform transform = CGAffineTransformMakeRotation(flRad);
	return CGPointApplyAffineTransform(vAlpha, transform);
}

//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

BOOL circleIntersectCircle(CGPoint pCenterA, CGFloat flRadiusA, CGPoint pCenterB, CGFloat flRadiusB)
{
	CGPoint pDiff = subtract(pCenterB, pCenterA);
	CGFloat flLength = length(pDiff);
	if (flLength  < (flRadiusA + flRadiusB))
	{
		return YES;
	}
	return NO;
}

//----------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------

BOOL rayCircleIntersect(CGPoint pRayOrigin, CGPoint vRay, CGPoint pCircleCenter, CGFloat flCircleRadius)
{
	vRay = normalize(vRay);
	CGPoint vDirectHit = subtract(pCircleCenter, pRayOrigin);
	CGFloat s = dot(vDirectHit, vRay); // Projection of ray onto direct hit
	CGFloat lsqrd = dot(vDirectHit, vDirectHit); // Length of direct hit
	CGFloat rsqrd = flCircleRadius * flCircleRadius;

	// If our origin is outsize the circle and our projection is negative, our target is behind us
	if (s < 0 && lsqrd > rsqrd)
		return NO;

	CGFloat msqrd = lsqrd - (s * s); // M is distance vRay missed pCircleCenter (by Pythagorian Thereom)
	if (msqrd > rsqrd) // We missed by more than radius
		return NO;

	return YES;
}

//----------------------------------------------------------------------------------------------------
//  pointAngleIntersect
//
//  Note: only works for angles less than 180 degrees.
//
//		Test if point pPoint lines within the 2D "cone" bounded by vRayAlpha and vRayBeta with
//  origin at pOrigin.
//----------------------------------------------------------------------------------------------------

BOOL pointAngleIntersect(CGPoint pPoint, CGPoint pOrigin, CGPoint vRayAlpha, CGPoint vRayBeta)
{
	CGPoint vRayTest = subtract(pPoint, pOrigin);

	// If our test ray's dot product is negative, we are 90 degrees from vRayAlpha or vRayBeta
	// For angles less than 180 degrees, this means we are facing away from our cone
	if (dot(vRayAlpha, vRayTest) <= 0 || dot(vRayBeta, vRayTest))
		return NO;

	CGFloat flNormalAlpha	= cross(vRayAlpha, vRayTest);
	CGFloat flNormalBeta	= cross(vRayBeta, vRayTest);

	// If the cross products have opposite signs, the vRayTest is between them
	if (signbit(flNormalAlpha) != signbit(flNormalBeta))
		return YES;

	return NO;
}

//----------------------------------------------------------------------------------------------------
//  pointInsideTriangle
//
//  function SameSide(p1,p2, a,b)
//  cp1 = CrossProduct(b-a, p1-a)
//  cp2 = CrossProduct(b-a, p2-a)
//  if DotProduct(cp1, cp2) >= 0 then return true
//    else return false
//
//  function PointInTriangle(p, a,b,c)
//  if SameSide(p,a, b,c) and SameSide(p,b, a,c)
//    and SameSide(p,c, a,b) then return true
//  else return false
//
//
//----------------------------------------------------------------------------------------------------

BOOL pointInsideTriangle(CGPoint pPoint, CGPoint pA, CGPoint pB, CGPoint pC)
{
	CGPoint vPA = subtract(pA, pPoint);
	CGPoint vPB = subtract(pB, pPoint);

	CGPoint vAB = subtract(pB, pA);
	CGPoint vBA = subtract(pA, pB);
	CGPoint vCA = subtract(pA, pC);
	CGPoint vAC = subtract(pC, pA);
	CGPoint vBC = subtract(pC, pB);

	if ((cross(vAB, vPA) * cross(vAB, vCA)) >= 0 &&
		(cross(vAC, vPA) * cross(vAC, vBA)) >= 0 &&
		(cross(vBC, vPB) * cross(vBC, vAB)) >= 0)
		return YES;
	return NO;
}

//----------------------------------------------------------------------------------------------------
//	rectAddRect
//----------------------------------------------------------------------------------------------------

CGRect rectAddRect(CGRect rectA, CGRect rectB)
{
	CGRect rectNew;
//	if (rectA.origin.x < rectB.origin.x)
//	{
//		rectNew.origin.x = rectA.origin.x;
//		float flDiff = rectB.origin.x - rectA.origin.x;
//		float flOverlap = flDiff + rectB.size.width;
//		rectNew.size.width = MAX(flOverlap, rectA.size.width);
//	}
//	else
//	{
//		rectNew.origin.x = rectB.origin.x;
//		float flDiff = rectA.origin.x - rectB.origin.x;
//		float flOverlap = flDiff + rectA.size.width;
//		rectNew.size.width = MAX(flOverlap, rectB.size.width);
//	}
//
//	if (rectA.origin.y < rectB.origin.y)
//	{
//		rectNew.origin.y = rectA.origin.y;
//		float flDiff = rectB.origin.y - rectA.origin.y;
//		float flOverlap = flDiff + rectB.size.height;
//		rectNew.size.height = MAX(flOverlap, rectA.size.height);
//	}
//	else
//	{
//		rectNew.origin.y = rectB.origin.y;
//		float flDiff = rectA.origin.y - rectB.origin.y;
//		float flOverlap = flDiff + rectA.size.height;
//		rectNew.size.height = MAX(flOverlap, rectB.size.height);
//	}

	float flMinOriginX = MIN(rectA.origin.x, rectB.origin.x);
	float flMinOriginY = MIN(rectA.origin.y, rectB.origin.y);
	float flMaxEndX = MAX(rectA.origin.x + rectA.size.width, rectB.origin.x + rectB.size.width);
	float flMaxEndY = MAX(rectA.origin.y + rectA.size.height, rectB.origin.y + rectB.size.height);
	float flSizeX = flMaxEndX - flMinOriginX;
	float flSizeY = flMaxEndY - flMinOriginY;
	rectNew = CGRectMake(flMinOriginX, flMinOriginY, flSizeX, flSizeY);
	return rectNew;
}

#endif
