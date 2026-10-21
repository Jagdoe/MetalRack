#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  Cash.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 1/9/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MRSceneConfiguration.h"
#import <QuartzCore/QuartzCore.h>
#import "MRCashView.h"
#import "MRUtilities.h"

@implementation MRCashView

@synthesize m_eAnimType;
@synthesize m_fIsCachedItem;

- (void)localStartUs:(CGPoint)pOrigin
{
	if (pOrigin.x < 20.0f)
	{
		NSLog(@"Cash on left.");
	}

	int nWidth = self.contentSize.width;  //self.frame.size.width;
	pOrigin.x -= nWidth / 2;

	[self setPosition:pOrigin];

	[self animate];
}

- (id)initWithWord:(NSString *)strWord usingFrame:(CGRect)frame;
{
    NSString *strFont = [[MRUtilities sharedUtilityManager] getDefaultFont];
    return [self initWithWord:strWord fontName:strFont usingFrame:frame];
}

- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName usingFrame:(CGRect)frame
{
    self = [super initWithWord:strWord fontName:strFontName usingFrame:frame];
	if (self == nil)
		return nil;

	[self localStartUs:frame.origin];

    return self;
}

- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName atPoint:(CGPoint)ptLocation fontSize:(float)flFontHeight
{
    self = [super initWithWord:strWord fontName:strFontName fontSize:flFontHeight];
	if (self == nil)
		return nil;

	[self localStartUs:ptLocation];

    return self;
}

- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName atPoint:(CGPoint)ptLocation fontSize:(float)flFontHeight maxWidth:(float)flTextWidth
{
    self = [super initWithParagraph:strWord fontName:strFontName fontSize:flFontHeight maxWidth:flTextWidth];
	if (self == nil)
		return nil;

	[self localStartUs:ptLocation];

    return self;
}

-(void) setOpacity:(uint8_t) anOpacity
{
	for (MRSprite *sprite in [self children])
	{
		[sprite setOpacity:anOpacity];
	}
}

- (void)animate
{
	[self setOpacity:0];

    float flScaleAdjust = [MRUtilities getDeviceScaleAdjustment];

	float flDelay = 1.3f;

//    [self setScale:0.1f];
//    CCScaleTo *animScaleY = [CCScaleTo actionWithDuration:0.1f scaleX:0.3f scaleY:1.2f];
//    CCScaleTo *animScaleX = [CCScaleTo actionWithDuration:0.2f scaleX:1.5f scaleY:1.0f];
//    CCScaleTo *animScale1 = [CCScaleTo actionWithDuration:0.2f scaleX:1.0f scaleY:1.0f];
//    CCSequence *animScale = [CCSequence actions:animScaleX, animScale1, nil];
//    [self runAction:animScale];

	MRMoveBy *animMoveBy = [MRMoveBy actionWithDuration:flDelay position:CGPointMake(0.0f, 240.0f * flScaleAdjust)];
	MRFadeIn *animFadeIn = [MRFadeIn actionWithDuration:0.4];
	MRDelayTime *animDelay = [MRDelayTime actionWithDuration:0.4];
	MRFadeOut *animFadeOut = [MRFadeOut actionWithDuration:0.4];
	MRCallFunc *animDie = [MRCallFunc actionWithTarget:self selector:@selector(dismissCash)];
	MRAction * animSequence = [MRSequence actions:animFadeIn, animDelay, animFadeOut, animDie, nil];
	[self runAction:animMoveBy];
	[self runAction:animSequence];
}

- (void)dismissCash
{
	m_eAnimType = ECA_NONE;
	if (m_fIsCachedItem == NO)
	{
		[self removeCash];
	}
	else
	{
		//self.hidden = YES;
	}
}

- (void)removeCash
{
	[self suicide];
}

- (void)dealloc
{
    (void)0;
}


@end

#endif
