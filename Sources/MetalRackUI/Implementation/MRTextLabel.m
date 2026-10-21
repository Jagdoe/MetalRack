#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DText.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 11/3/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "MRTextLabel.h"
#import "MRSnapshot.h"
#import "MRBitmapFont.h"
#import "MRUIKit.h"
#import "MRSceneConfiguration.h"

@implementation MRTextLabel

@synthesize sizeText = m_sizeText;
@synthesize nLines = m_nLines;

//#ifdef MR_IPHONE
//#define FONT_SPACING (-1.4)
//#else
//#define FONT_SPACING (-2.8)
//#endif

+ (id)textWithWord:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight
{
	id ob = ([[self alloc] initWithWord:strWord fontName:strFontName fontSize:flFontHeight]);
	return ob;
}

+ (id)textWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth
{
	id ob = ([[self alloc] initWithParagraph:strWord fontName:strFontName fontSize:flFontHeight maxWidth:flTextWidth]);
	return ob;
}

+ (id)textWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth centered:(BOOL)fCentered
{
	id ob = ([[self alloc] initWithParagraph:strWord fontName:strFontName fontSize:flFontHeight maxWidth:flTextWidth centered:fCentered]);
	return ob;
}

- (MRDefinitionSprite *)getLetter:(char)bLetter font:(MRBitmapFont *)font
{
	if (bLetter == ' ')
		return nil;
	NSString *strKey = [NSString stringWithFormat:@"%c", bLetter];
	MRSpriteFrame *frame = [font.m_dictFrames objectForKey:strKey];
    if (frame == nil)
        return nil;
	MRDefinitionSprite *sprLetter = [MRDefinitionSprite spriteWithFrame:frame];
	return sprLetter;
}

- (float)getKernYData:(char)bLetter font:(MRBitmapFont *)font
{
	NSString *strKey = [NSString stringWithFormat:@"%c", bLetter];
	float flKern = [[font.m_dictKernData objectForKey:strKey] floatValue];
	flKern = flKern / 2.0f;
	// Do we need to adjust based on retina/non-retina?


	return flKern;
}

- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName usingFrame:(CGRect)frame
{
    if ((self = [self initWithWord:strWord fontName:strFontName fontSize:frame.size.height]))
    {
        [self setPosition:frame.origin];
    }
    return self;
}

- (id)initWithWord:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight
{
    MRTextAtlas *atlas=[[MRSceneRuntime sharedRuntime] textAtlasNamed:strFontName];
    if (atlas) {
        if ((self=[super init])) {
            m_nativeText=[[MRText alloc] initWithAtlas:atlas text:strWord ?: @"" fontSize:MAX(.01,flFontHeight)];
            m_nativeText.horizontalInset=flFontHeight*[[MRSceneRuntime sharedRuntime] textInsetRatioForFont:strFontName];
            [self addChild:m_nativeText];self.contentSize=m_nativeText.contentSize;
            m_sizeText=self.contentSize;m_nLines=(int)m_nativeText.lineCount;m_fKill=NO;m_sprOutline=nil;
        }
        return self;
    }

    if ((self = [super init]))
	{
		MRBitmapFont *font = [MRBitmapFont getFontByName:strFontName];

        // Initialization code
		int nLetterIndex = 0;
		int nCount = [strWord length];
		float flXPos = 0;


		float flHeight = [font getMaxHeight];

		// Use max height for spacing -- we scale our size down at the end of the function
		float flSpaceWidth = [font getSpaceWidthForFontHeight:flHeight];
		float flWidth = flHeight / 2.0f;

        float flFontSpacing = [font getFontSpacing];// * flFontHeight / flHeight;
        // We use different art assets that are already pixel aligned

		for (nLetterIndex = 0; nLetterIndex < nCount; nLetterIndex++)
		{
			unichar uLetter = [strWord characterAtIndex:nLetterIndex];

			MRDefinitionSprite *sprLetter =  [self getLetter:(char)uLetter font:font];
			[sprLetter setAnchorPoint:MRPoint(0.0f, 1.0f)];
			if (sprLetter != nil)
			{
				float flKernY = [self getKernYData:(char)uLetter font:font];
				[self addChild:sprLetter];

				flWidth = sprLetter.contentSize.width * sprLetter.scale;
                //				sprLetter.position = CGPointMake(flXPos + (flWidth / 2), flHeight - flKernY + 1);
				[sprLetter setPosition:CGPointMake(flXPos, flHeight - flKernY + 1)];
			}
            else if (uLetter == ' ')
            {
//                flWidth = flXPos / nLetterIndex - flFontSpacing;
//                flWidth /= 2.0f;
				flWidth = flSpaceWidth;
            }

			flXPos += flWidth + flFontSpacing;
		}

        flXPos -= flFontSpacing;

		// Set our size
		[self setContentSize:CGSizeMake(flXPos, flHeight)];


		// Alter our size based on scale
		float flPercent = flFontHeight / flHeight;
		[self setScale:flPercent];

        [self setColorChildren:YES];

		m_sizeText = CGSizeMake(flXPos * flPercent, flHeight * flPercent);

		m_fKill = NO;
        m_sprOutline = nil;
    }

    return self;
}

- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName usingFrame:(CGRect)frame
{
    if ((self = [self initWithParagraph:strWord fontName:strFontName fontSize:frame.size.height maxWidth:frame.size.width]))
	{
        [self setPosition:frame.origin];
    }
    return self;
}

- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth
{
	return [self initWithParagraph:strWord fontName:strFontName fontSize:flFontHeight maxWidth:flTextWidth centered:NO];
}

- (id)initWithParagraph:(NSString *)strWord fontName:(NSString *)strFontName fontSize:(float)flFontHeight maxWidth:(float)flTextWidth centered:(BOOL)fCentered
{
    MRTextAtlas *atlas=[[MRSceneRuntime sharedRuntime] textAtlasNamed:strFontName];
    if (atlas) {
        if ((self=[super init])) {
            m_nativeText=[[MRText alloc] initWithAtlas:atlas text:strWord ?: @"" fontSize:MAX(.01,flFontHeight)];
            m_nativeText.horizontalInset=flFontHeight*[[MRSceneRuntime sharedRuntime] textInsetRatioForFont:strFontName];
            m_nativeText.maximumWidth=MAX(.01,flTextWidth);m_nativeText.centered=fCentered;
            [self addChild:m_nativeText];self.contentSize=m_nativeText.contentSize;
            m_sizeText=self.contentSize;m_nLines=(int)m_nativeText.lineCount;m_fKill=NO;m_sprOutline=nil;
        }
        return self;
    }

    if ((self = [super init]))
	{
        float flXPos = 0;
        float flYPos = 0;
        float flMaxWidth = flTextWidth;

        float flHeight = flFontHeight;
        float flLineSpacing = flHeight * 1.2f;

        // Deal with font spacing so our space between words is correct.
        MRBitmapFont *font = [MRBitmapFont getFontByName:strFontName];
        float flFontSpacing = [font getFontSpacing];

		// Use our font height since our words are scaled already.
        float flBlankSpace = [font getSpaceWidthForFontHeight:flFontHeight]; //flHeight / 4.0f; // Give it some value!
        float flWidestLine = 0;

		m_nLines = 1;

        // We want to color (and fade) our children.
        [self setColorChildren:YES];

		NSMutableArray *aCurrentLineSprites = [NSMutableArray arrayWithCapacity:10];

        NSArray *aWords = [strWord componentsSeparatedByString:@" "];
        for (NSString *strWord in aWords)
        {
			NSArray *aSplitOnReturns = [strWord componentsSeparatedByString:@"\n"];
            for (NSString *strWord in aSplitOnReturns)
            {
                //            NSLog(@"Word = [%@]", strWord);
                if ([strWord length] > 0)
                {
                    MRTextLabel *textWord = ([[MRTextLabel alloc] initWithWord:strWord fontName:strFontName fontSize:flFontHeight]);
                    float flWordWidth = [textWord contentSize].width * textWord.scale;

                    if (((flXPos + flWordWidth > flMaxWidth) && flXPos != 0))
                    {
                        // Account for long completed lines
                        if (flXPos > flWidestLine)
                            flWidestLine = flXPos;

                        if (fCentered == YES)
                        {
                            // Re-center our text
                            float flLineLength = flXPos;
                            float flXAdjust = (flTextWidth - flLineLength) / 2.0f;
                            for (MRTextLabel *textOb in aCurrentLineSprites)
                            {
                                CGPoint ptPosition = textOb.position;
                                ptPosition.x += flXAdjust;
                                [textOb setPosition:ptPosition];
                            }
                            [aCurrentLineSprites removeAllObjects];
                        }

                        flXPos = 0;

                        flYPos -= flLineSpacing;
                        m_nLines++;
                    }
                    else
                    {
                        // Account for long partial lines
                        if (flXPos + flWordWidth > flWidestLine)
                            flWidestLine = flXPos + flWordWidth;
                    }
                    [textWord setAnchorPoint:MRPoint(0, 0)];
                    [textWord setPosition:MRPoint(flXPos, flYPos)];
                    [self addChild:textWord];
                    flXPos += flWordWidth + flBlankSpace + flFontSpacing;
                    if (fCentered == YES)
                        [aCurrentLineSprites addObject:textWord];

                }

                // As long as we aren't the last word, we've split on a return
                if ([aSplitOnReturns indexOfObject:strWord] < [aSplitOnReturns count] - 1)
                {
                    // Account for long completed lines
                    if (flXPos > flWidestLine)
                        flWidestLine = flXPos;

                    if (fCentered == YES)
                    {
                        // Re-center our text
                        float flLineLength = flXPos;
                        float flXAdjust = (flTextWidth - flLineLength) / 2.0f;
                        for (MRTextLabel *textOb in aCurrentLineSprites)
                        {
                            CGPoint ptPosition = textOb.position;
                            ptPosition.x += flXAdjust;
                            [textOb setPosition:ptPosition];
                        }
                        [aCurrentLineSprites removeAllObjects];
                    }

                    flXPos = 0;
                    flYPos -= flLineSpacing;
                    m_nLines++;
                }
            }
        }

		// Handle last line.
		if (fCentered == YES)
		{
			// Re-center our text
			float flLineLength = flXPos;
			float flXAdjust = (flTextWidth - flLineLength) / 2.0f;
			for (MRTextLabel *textOb in aCurrentLineSprites)
			{
				CGPoint ptPosition = textOb.position;
				ptPosition.x += flXAdjust;
				[textOb setPosition:ptPosition];
			}
			[aCurrentLineSprites removeAllObjects];

			// This prevents centering errors.  We centered our words based on
			// MaxWidth, so we must maintain that size.
			flWidestLine = flMaxWidth;
		}

        //        NSLog(@"\n");

        float flNewHeight = flHeight - flYPos; // yPos is 0 or negative
        [self setContentSize:CGSizeMake(flWidestLine, flNewHeight)];
		m_sizeText = [self contentSize];
        for (MRTextLabel *textChild in self.children)
        {
            CGPoint pos = textChild.position;
            [textChild setPosition:MRPoint(pos.x, pos.y - flYPos)];
        }
        [self setColorChildren:YES];
        m_sprOutline = nil;
    }
    return self;
}

- (void)removeOutline
{
    [m_sprOutline removeFromParentAndCleanup:YES];
    m_sprOutline = nil;
}

// Outline styling was disabled in the existing text API. Preserve that behavior.
- (id)outlineWithColor:(NSString *)color { return nil; }

- (void)setColor:(MRColor3B)color { [super setColor:color];m_nativeText.color=color; }
- (void)setOpacity:(uint8_t)opacity { [super setOpacity:opacity];m_nativeText.opacity=opacity; }
- (void)dealloc
{
	[self removeAllChildrenWithCleanup:YES];

	MRSprite *sprLetter;
	for (sprLetter in [self children])
	{
		(void)0;
	}
    (void)0;
}

- (void)suicide
{
	m_fKill = YES;
	[self.parent removeChild:self cleanup:YES];
}

@end
#endif
