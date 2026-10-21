//
//  Cash.h
//  Fingerzilla
//
//  Created by Michael Scandizzo on 1/9/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MRTextLabel.h"
#import "MRUIKit.h"

#define MAX_CASH_INSTANCES	20

typedef enum
{
	ECA_NONE,
	ECA_STAGE_1,
	ECA_STAGE_2,
	ECA_STAGE_3,
} ECASHANIM;

@interface MRCashView : MRTextLabel
{
	ECASHANIM	m_eAnimType;
	BOOL		m_fIsCachedItem;
}

@property (nonatomic) ECASHANIM m_eAnimType;
@property (nonatomic) BOOL m_fIsCachedItem;

// DEPRECATED: specify the font name, such as @"futura"
- (id)initWithWord:(NSString *)strWord usingFrame:(CGRect)frame DEPRECATED_ATTRIBUTE;
- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName usingFrame:(CGRect)frame;
- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName atPoint:(CGPoint)ptLocation fontSize:(float)flFontHeight;
- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName atPoint:(CGPoint)ptLocation fontSize:(float)flFontHeight maxWidth:(float)flTextWidth;

- (void)animate;
- (void)dismissCash;
- (void)removeCash;

@end
