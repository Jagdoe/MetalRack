#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DLayerLine.m
//  Zombie
//
//  Created by Tom the Great on 5/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRLineLayer.h"
#import "2DMath.h"
#import "MRDefinitionSprite.h"

#define ZPLANE_TICKS		(10)

#define LINE_TRAVEL_SPEED	(16.0f / (float)(MR_FRAMES_PER_SECOND))
#define ADJUST_AMOUNT		(0.5f)
#define ADJUST_MAX			(20.0f)

// Macros.

@implementation MRLineLayer

@synthesize flTravelSpeed = m_flTravelSpeed;

+ (id)createWithLineFromPoint:(CGPoint)start toPoint:(CGPoint)end useCurve:(BOOL)fUseCurve
{
	// Create a default layer.
	MRLineLayer *layer = ([[MRLineLayer alloc] init]);
	if (layer == nil)
	{
		NSLog(@"Error: Unable to create C2DLayerLine.");
		return nil;
	}

	// Now generate the line.
	[layer drawDottedLineFromPoint:start toPoint:end useCurve:fUseCurve];

	// Make us wiggle. Or spasm.  Whatever.
	if (fUseCurve == YES)
	{
		//[layer schedule: @selector(updateLine:) interval:0.1f];
		[layer scheduleUpdate];
	}

	return layer;
}

+ (id)createWithLineFromNode:(MRNode*)nodeStart toNode:(MRNode*)nodeEnd useCurve:(BOOL)fUseCurve
{
	// We need to have two valid nodes.
	if (nodeStart == nil || nodeEnd == nil)
	{
		NSLog(@"Error: LineFromNode needs valid start and end nodes.");
		return nil;
	}

	// Create a default layer.
	MRLineLayer *layer = ([[MRLineLayer alloc] init]);
	if (layer == nil)
	{
		NSLog(@"Error: Unable to create C2DLayerLine.");
		return nil;
	}

	// Set our start and end, and draw the line once.
	[layer setLineCurve:fUseCurve];
	[layer setLineStart:nodeStart withEnd:nodeEnd];

	// We always want to update so that we can adjust our start/end points.
	[layer scheduleUpdate];

	//NSLog(@"Line -- generated %@", layer);
	return layer;
}

- (id)init
{
	self = [super init];
	if (self != nil)
	{
		// We have no ticks yet.
		m_nTickCount = 0;
		memset(m_sprTicks, (int)nil, sizeof(MRDefinitionSprite*) * MAX_LINE_TICKS);
		m_strDot = @"dot.png"; // Should always have a dot.png in SoapRack projects.
		m_fUseCurve = NO;
        m_flDistortionAngleMin = 15.0f;
        m_flDistortionAngleDelta = 30.0f;
		m_colorLine = LINE_COLOR_DEFAULT;
		m_opacity = 255;
		m_flAngle1 = 0.0f;
		m_flAngle1Original = 0.0f;
		m_flAngle2 = 0.0f;
		m_flAngle2Original = 0.0f;
        m_flTravelSpeed = LINE_TRAVEL_SPEED;
        [self setWiggleMax:ADJUST_MAX];

		m_flAdjustAnglePercent = 1.0f;
		m_flAdjustMovementPercent = 0.0f;
		m_fReverse1Animate = NO;
		m_fReverse2Animate = NO;
		m_fHasCreatedOnce = NO;
		m_nodeStart = nil;
		m_nodeEnd = nil;
		m_fForceRefresh = NO;
		m_fUsesNodePoints = NO;
	}

	return (self);
}

-(void) update:(MRTime)timeDelta
{
	// Use this for per-frame update, per:
	//		[self scheduleUpdate];  // available since v0.99.3
	//NSLog(@"Line Updating.");
	// For now, fall through to standard update.
	[self updateLine:timeDelta];
}

- (void)updateLineStraight
{
	// If we're not curved, just re-created us each time.
	//NSLog(@"Line -- updating for %@", self);

	// If our start and end points haven't moved, and we already have a line, then for god's sake
	// don't do the full re-create! :)
	if (m_nTickCount > 0 && m_fForceRefresh == NO)
	{
		if (MRPointFuzzyEqual(m_nodeStart.position, m_pointStart, 0.1f) == YES &&
			MRPointFuzzyEqual(m_nodeEnd.position,   m_pointEnd,   0.1f) == YES)
		{
			return;
		}
	}

	// Remove all our old ticks.
	for (int i = 0; i < m_nTickCount; ++i)
	{
		[self removeChild:m_sprTicks[i] cleanup:YES];
		m_sprTicks[i] = nil;
	}
	m_nTickCount = 0;
	m_fHasCreatedOnce = NO;

	// If we're node-based, update anchors as needed.
	if (m_fUsesNodePoints == YES)
	{
		// If we're node-based, and either of our start or end nodes is gone, don't re-draw us.
		if (m_nodeEnd == nil || m_nodeStart == nil)
			return;

		// Get our new start and end.
		m_pointStart = m_nodeStart.position;
		m_pointEnd   = m_nodeEnd.position;
	}

	// Now generate the line.
	[self drawDottedLineFromPoint:m_pointStart toPoint:m_pointEnd useCurve:m_fUseCurve];

	// And we're done.
}

- (void)updateLine:(MRTime)timeDelta
{
	// Use this for schedule not-per-frame update, per:
	//[self schedule: @selector(localUpdateLine:) interval:0.5f];
	//NSLog(@"  Wiggling line.");
	//return;

	// If we're a straight line, do the different routine.
	if (m_fUseCurve == NO)
	{
		[self updateLineStraight];
		return;
	}

	float flAngle1Min = m_flAngle1Original - m_flAdjust1Max;
	float flAngle1Max = m_flAngle1Original + m_flAdjust1Max;
	float flAmount1Remaining = MIN(flAngle1Max - m_flAngle1, m_flAngle1 - flAngle1Min);
	float flPercent1Remaining = MAX(0.0f, flAmount1Remaining / m_flAdjust1Max);
	flPercent1Remaining = MIN(100.0f, flPercent1Remaining);
	float flAmount1Perform = (ADJUST_AMOUNT * flPercent1Remaining) + (ADJUST_AMOUNT / 8.0f);
	if (m_flAngle1 < flAngle1Min || m_flAngle1 > flAngle1Max)
	{
		// Flip us!
		//NSLog(@"Flipping line 1 for %x!", self);
		m_fReverse1Animate = !m_fReverse1Animate;
	}
	if (m_fReverse1Animate == NO)
		m_flAngle1 += flAmount1Perform;
	else
		m_flAngle1 -= flAmount1Perform;
	CGPoint posDelta = subtract(m_pointEnd, m_pointStart);
	CGPoint posDelta1 = rotateVectorByAngle(posDelta, m_flAngle1);
	m_pointControl1 = add(m_pointStart, scale(posDelta1, 0.33f));

	// Now the same for node 2.
	float flAngle2Min = m_flAngle2Original - m_flAdjust2Max;
	float flAngle2Max = m_flAngle2Original + m_flAdjust2Max;
	float flAmount2Remaining = MIN(flAngle2Max - m_flAngle2, m_flAngle2 - flAngle2Min);
	float flPercent2Remaining = MAX(0.0f, flAmount2Remaining / m_flAdjust2Max);
	flPercent2Remaining = MIN(100.0f, flPercent2Remaining);
	float flAmount2Perform = (ADJUST_AMOUNT * flPercent2Remaining) + (ADJUST_AMOUNT / 8.0f);
	if (m_flAngle2 < flAngle2Min || m_flAngle2 > flAngle2Max)
	{
		// Flip us!
		//NSLog(@"Flipping line 2 for %x!", self);
		m_fReverse2Animate = !m_fReverse2Animate;
	}
	if (m_fReverse2Animate == NO)
		m_flAngle2 += flAmount2Perform;
	else
		m_flAngle2 -= flAmount2Perform;
	CGPoint posDelta2 = rotateVectorByAngle(posDelta, m_flAngle2);
	m_pointControl2 = add(m_pointStart, scale(posDelta2, 0.67f));

	// Adjust our "movement" a bit.
	m_flAdjustMovementPercent += (m_flTravelSpeed * timeDelta);
	if (m_flAdjustMovementPercent >= 1.0f)
		m_flAdjustMovementPercent -= 1.0f;
	[self drawDottedLineFromPoint:m_pointStart toPoint:m_pointEnd useCurve:m_fUseCurve];
}

- (void)drawDottedLineFromPoint:(CGPoint)start toPoint:(CGPoint)end useCurve:(BOOL)fUseCurve
{
	MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:m_strDot];

	// Common values, whether straight or curved.
	float flDotWidth = frame.originalSize.width;
	float flSpacing = flDotWidth * 1.5f;
	CGPoint posDelta = subtract(end, start);
	CGPoint vRight = CGPointMake(1.0, 0.0f);

	m_pointStart = start;
	m_pointEnd	 = end;
	m_fUseCurve  = fUseCurve;

	int nPointsToUse = length(posDelta) / flSpacing;
	nPointsToUse = MIN(MAX_LINE_TICKS, nPointsToUse);

	if (m_fForceRefresh == YES)
	{
		// Remove all our old ticks.
		for (int i = 0; i < m_nTickCount; ++i)
		{
			[self removeChild:m_sprTicks[i] cleanup:YES];
			m_sprTicks[i] = nil;
		}
		m_nTickCount = 0;
		m_fHasCreatedOnce = NO;
	}

	// Bezier test.
	if (fUseCurve == YES)
	{
		CGPoint pointSteps[MAX_LINE_TICKS];
		int     nPointCount = 0;

		// Create our nodes if we haven't yet.
		if (m_fHasCreatedOnce == NO)
		{
			m_flAngle1 = m_flDistortionAngleMin + (MRRandomUnit() * m_flDistortionAngleDelta);
			// Decide which way to start.
			if (random() % 2 == 0)
				m_flAngle1 *= -1;
			m_flAngle1Original = m_flAngle1;
			// Point 1 is 1/3 along the path, with some slight noise.
			CGPoint posDelta1 = rotateVectorByAngle(posDelta, m_flAngle1);
			m_pointControl1 = add(start, scale(posDelta1, 0.33f));

			// Now decide if we want an S shape (-1) or C shape (+1)
			m_flAngle2 = m_flAngle1;
			if (random() % 2 == 0)
				m_flAngle2 *= -1;
			m_flAngle2Original = m_flAngle2;
			CGPoint posDelta2 = rotateVectorByAngle(posDelta, m_flAngle2);
			m_pointControl2 = add(start, scale(posDelta2, 0.67f));
		}

		CGPoint posPrevious = start;
		MRBezierConfig tBezier;
		tBezier.controlPoint_1 = m_pointControl1;
		tBezier.controlPoint_2 = m_pointControl2;
		tBezier.endPosition    = end;
		float flDuration = 1.0f;
		MRBezierTo *bezier = [MRBezierTo actionWithDuration:flDuration bezier:tBezier];
		MRDefinitionSprite *sprSource = [MRDefinitionSprite spriteWithFrame:frame];
		[sprSource setPosition:start];
		[bezier startWithTarget:sprSource];

		// This version uses a fixed number of points, to avoid jitter.
		MRTime timeDelta = flDuration / nPointsToUse;
		for (int i = 0; i < nPointsToUse; ++i)
		{
			float flMult = i + (m_flAdjustMovementPercent);
			MRTime timeSegment = (timeDelta * flMult);
			[bezier update:timeSegment];
			CGPoint posNew = sprSource.position;
			// Store this point.
			pointSteps[nPointCount] = posNew;
			++nPointCount;
			posPrevious = posNew;
		}

		// Now go through and actually place all the ticks.
		for (int i = 0; i < MAX_LINE_TICKS; ++i)
		{
			if (i < nPointCount)
			{
				// Get the angle between the previous and next ticks that border us.
				int nIndexPrev = MAX(0, i - 1);
				int nIndexNext = MIN(MAX_LINE_TICKS-1, i + 1);
				CGPoint vAngle = subtract(pointSteps[nIndexNext], pointSteps[nIndexPrev]);
				float flAngle  = angleBetweenVectors(vAngle, vRight);
				// Create, rotate, and place the tick.
				MRDefinitionSprite *sprNew = m_sprTicks[i];
				if (sprNew == nil)
				{
					sprNew = [MRDefinitionSprite spriteWithFrame:frame];
					m_sprTicks[i] = sprNew;
					[self addChild:sprNew z:ZPLANE_TICKS];
				}
				[sprNew setPosition:pointSteps[i]];
				if (nIndexNext < nPointCount)
				{
					sprNew.rotation = flAngle;
				}
				else
				{
					// Just use the angle to the final endpoint.
					vAngle = subtract(m_pointEnd, pointSteps[nIndexPrev]);
					flAngle = angleBetweenVectors(vAngle, vRight);
					sprNew.rotation = flAngle;
				}
//				NSLog(@"  Dot %d angle is: %.0fdeg", i, flAngle);
				[sprNew setColor:m_colorLine];
				[sprNew setOpacity:m_opacity];
			}
			else
			{
				// Turn off any unused ticks.
				if (m_sprTicks[i] != nil)
					[m_sprTicks[i] setOpacity:0];
			}
		}
		m_nTickCount = nPointCount;
		[sprSource cleanup];
	}
	else
	{
		// Straight line.
		float flDistance = length(posDelta);

		CGFloat flAngle = angleBetweenVectors(posDelta, vRight);
		posDelta = normalize(posDelta);
		CGPoint vOffset = scale(posDelta, 1.5 * flDotWidth);
		CGPoint vPosition = start;
		int nPointCount = 0;
		while (flDistance > 0.0 && nPointCount < MAX_LINE_TICKS)
		{
			MRDefinitionSprite *sprNew = m_sprTicks[nPointCount];
			if (sprNew == nil)
			{
				sprNew = [MRDefinitionSprite spriteWithFrame:frame];
				m_sprTicks[nPointCount] = sprNew;
				[self addChild:sprNew z:ZPLANE_TICKS];
			}
			[sprNew setPosition:vPosition];
			sprNew.rotation = flAngle;
			[sprNew setColor:m_colorLine];
			[sprNew setOpacity:m_opacity];

			flDistance -= flSpacing;
			vPosition = add(vPosition, vOffset);
			++nPointCount;
		}
		for (int i = nPointCount; i < MAX_LINE_TICKS; ++i)
		{
			// Turn off excess ticks.
			if (m_sprTicks[i] != nil)
				[m_sprTicks[i] setOpacity:0];
		}
		m_nTickCount = nPointCount;
	}

	m_fHasCreatedOnce = YES;
	m_fForceRefresh = NO;
}

- (void)setLineCurve:(BOOL)fCurve
{
	m_fUseCurve = fCurve;
}

- (void)setLineColor:(MRColor3B)color
{
	for (int i = 0; i < MAX_LINE_TICKS; ++i)
	{
		if (m_sprTicks[i] != nil)
		{
			[m_sprTicks[i] setColor:color];
		}
	}
	m_colorLine = color;
}

- (void)setLineOpacity:(uint8_t)opacity
{
	for (int i = 0; i < MAX_LINE_TICKS; ++i)
	{
		if (m_sprTicks[i] != nil)
		{
			[m_sprTicks[i] setOpacity:opacity];
		}
	}
	m_opacity = opacity;
}

- (void)setLineStart:(MRNode*)nodeStart withEnd:(MRNode*)nodeEnd
{
	m_nodeStart  = nodeStart;
	m_pointStart = nodeStart.position;
	m_nodeEnd	 = nodeEnd;
	m_pointEnd	 = nodeEnd.position;

	// Mark that we're using nodes, not just points.
	m_fUsesNodePoints = YES;

	// And do one update.
	[self updateLineStraight];
}

- (void)setLineTicks:(NSString*)strTicks
{
	if (strTicks != nil)
	{
		// Leaking strings?
		m_strDot = [NSString stringWithString:strTicks];
		m_fForceRefresh = YES;
		[self update:1];
	}
}

// The most we can wiggle back and forth from our path.
- (void)setWiggleMax:(float)flWiggle
{
    // We'll allow from 50% to 100% of this amount of "swing" left/right.
    m_flAdjust1Max = (flWiggle / 2.0f) + (MRRandomUnit() * (flWiggle / 2.0));
    m_flAdjust2Max = (flWiggle / 2.0f) + (MRRandomUnit() * (flWiggle / 2.0));

    // And we need to regenerate the line.
    m_fHasCreatedOnce = NO;
}

// 0 makes straight lines; default is 15, 30 (thus, 15deg to 45 deg range).
- (void)setDistortionAngleMin:(float)flAngleMin withDelta:(float)flAngleDelta
{
    m_flDistortionAngleMin = flAngleMin;
    m_flDistortionAngleDelta = flAngleDelta;

    // And we need to regenerate the line.
    m_fHasCreatedOnce = NO;
}

- (void)cleanup
{
	// Unschedule any update that's going.
	[self unscheduleUpdate];

	[super cleanup];
}

@end

#endif
