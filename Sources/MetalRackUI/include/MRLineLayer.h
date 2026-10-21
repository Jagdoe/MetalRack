//
//  C2DLayerLine.h
//  Zombie
//
//  Created by Tom the Great on 5/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRSceneConfiguration.h"

#define MAX_LINE_TICKS		(100)

#define LINE_COLOR_DEFAULT	MRRGB(99, 160, 222)

@class MRButton;
@class MRDefinitionSprite;

@interface MRLineLayer : MRLayer
{
	MRDefinitionSprite	*m_sprTicks[MAX_LINE_TICKS];
	int			m_nTickCount;
	MRColor3B	m_colorLine;
	uint8_t		m_opacity;
	CGPoint		m_pointStart;
	CGPoint		m_pointEnd;
	MRNode		*m_nodeStart;
	MRNode		*m_nodeEnd;
	CGPoint		m_pointControl1;
	CGPoint		m_pointControl2;
    float       m_flDistortionAngleMin;
    float       m_flDistortionAngleDelta;
	float		m_flAngle1;
	float		m_flAngle2;
	float		m_flAngle1Original;
	float		m_flAngle2Original;
	float		m_flAdjust1Max;
	float		m_flAdjust2Max;
	float		m_flAdjustAnglePercent;
	float		m_flAdjustMovementPercent;
    float       m_flTravelSpeed;
	NSString	*m_strDot;
	BOOL		m_fUseCurve;
	BOOL		m_fHasCreatedOnce;
	BOOL		m_fReverse1Animate;
	BOOL		m_fReverse2Animate;
	BOOL		m_fForceRefresh;
	BOOL		m_fUsesNodePoints;
}

@property float   flTravelSpeed;

+ (id)createWithLineFromPoint:(CGPoint)start toPoint:(CGPoint)end useCurve:(BOOL)fUseCurve;
+ (id)createWithLineFromNode:(MRNode*)nodeStart toNode:(MRNode*)nodeEnd useCurve:(BOOL)fUseCurve;

- (void)updateLine:(MRTime)timeDelta;
- (void)drawDottedLineFromPoint:(CGPoint)start toPoint:(CGPoint)end useCurve:(BOOL)fUseCurve;
- (void)setLineCurve:(BOOL)fCurve;
- (void)setLineColor:(MRColor3B)color;
- (void)setLineOpacity:(uint8_t)opacity;
- (void)setLineStart:(MRNode*)nodeStart withEnd:(MRNode*)nodeEnd;
- (void)setLineTicks:(NSString*)strTicks;
- (void)setWiggleMax:(float)flWiggle;
- (void)setDistortionAngleMin:(float)flAngleMin withDelta:(float)flAngleDelta;

@end
