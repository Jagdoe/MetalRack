//
//  C2DText.h
//  Fingerzilla
//
//  Created by Michael Scandizzo on 11/3/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRUIKit.h"
#import "MRDefinitionSprite.h"
#import "MRTextLabel.h"
#import "MRBitmapFont.h"

@interface MRTextLabel : MRDefinitionSprite
{
	BOOL		m_fKill;
    MRText *m_nativeText;
    MRDefinitionSprite   *m_sprOutline;
	int			m_nLines;
	CGSize		m_sizeText;
}

@property (readonly, getter = getTextSize)	CGSize sizeText;
@property (readonly, getter = getLineCount)	int nLines;

+ (id)textWithWord:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight;
+ (id)textWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth;
+ (id)textWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth centered:(BOOL)fCentered;

- (MRDefinitionSprite *)getLetter:(char)bLetter font:(MRBitmapFont *)font;
- (float)getKernYData:(char)bLetter font:(MRBitmapFont *)font;
- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName usingFrame:(CGRect)frame;
- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight;
// initWithParagraph line wraps
- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName usingFrame:(CGRect)frame;
- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth;
- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth centered:(BOOL)fCentered;
- (void)removeOutline;
- (id)outlineWithColor:(NSString*)strColor;
- (void)suicide;

@end
