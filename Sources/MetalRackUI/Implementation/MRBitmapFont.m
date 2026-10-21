#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  C2DFont.m
//  Befuddled2
//
//  Created by Michael Scandizzo on 3/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MRTextLabel.h"
#import "MRSceneConfiguration.h"
#import "MRUtilities.h"

@implementation MRBitmapFont

@synthesize m_strFontName;
@synthesize m_dictFrames;
@synthesize m_dictKernData;

static NSMutableDictionary *sgdictFonts = nil;

//static BOOL					fIsInitialized = FALSE;	// Have we had our master class init yet?
//static NSMutableArray		*aValueTypes;			// Holds our list of circle number values.

static NSString *sstrCharacterSet = @"01234567890/$.,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz:()+!?-%";
//									  222212121220099000000000000000000000000000303030300000333333313333333



+ (MRBitmapFont *)getFontByName:(NSString *)strFontName
{
	if (sgdictFonts == nil)
	{
		sgdictFonts = ([NSMutableDictionary dictionaryWithCapacity:2]);
	}
	MRBitmapFont *font = [sgdictFonts objectForKey:strFontName];
	if (font == nil)
	{
		font = [[MRBitmapFont alloc] initWithFontName:strFontName];
	}
	return font;
}


+ (void)addFont:(MRBitmapFont *)font
{
	if (sgdictFonts == nil)
	{
		sgdictFonts = ([NSMutableDictionary dictionaryWithCapacity:2]);
	}

	[sgdictFonts setObject:font forKey:font.m_strFontName];
}

- (id)initWithFontName:(NSString *)strFontName
{
	NSString *strFontFile = [NSString stringWithFormat:@"%@.plist", strFontName];
	[[MRSceneRuntime sharedRuntime] loadAtlasNamed:strFontFile]; // @"futura.plist"

	m_strFontName = [strFontName copy];
	m_dictFrames = ([NSMutableDictionary dictionaryWithCapacity:70]);
	m_dictKernData = ([NSMutableDictionary dictionaryWithCapacity:70]);

	// Set up and fill our value type array.
	int nCount = [sstrCharacterSet length];
	for (int i = 0; i < nCount; ++i)
	{
		char bLetter = [sstrCharacterSet characterAtIndex:i];
		NSString *strLetter = [NSString stringWithFormat:@"%c", bLetter];
		if (bLetter == '/')
		{
			strLetter = @"slash";
		}
		else if (bLetter == '$')
		{
			strLetter = @"dollar";
		}
		else if (bLetter == '.')
		{
			strLetter = @"period";
		}
		else if (bLetter == ',' || bLetter == '\'')
		{
			strLetter = @"comma";
		}
		else if (bLetter == '\'')
		{
			strLetter = @"comma"; // Apostrophe looks wrong
		}
		else if (bLetter == ':')
		{
			strLetter = @"colon";
		}
		else if (bLetter == '(')
		{
			strLetter = @"lparen";
		}
		else if (bLetter == ')')
		{
			strLetter = @"rparen";
		}
		else if (bLetter == '+')
		{
			strLetter = @"plus";
		}
		else if (bLetter == '!')
		{
			strLetter = @"exclamation";
		}
		else if (bLetter == '?')
		{
			strLetter = @"question";
		}
		else if (bLetter == '-')
		{
			strLetter = @"hyphen";
		}
		else if (bLetter >= 'a' && bLetter <= 'z')
		{
			strLetter = [NSString stringWithFormat:@"lower_%c", bLetter];
		}
		else if (bLetter >= 'A' && bLetter <= 'Z')
		{
			strLetter = [NSString stringWithFormat:@"upper_%c", bLetter];
		}
		NSString *imageName = [NSString stringWithFormat:@"%@_%@.png", strFontName, strLetter];
		MRSpriteFrame *frame = [[MRSceneRuntime sharedRuntime].resources frameNamed:imageName];
		NSString *strKey= [NSString stringWithFormat:@"%c", bLetter];
		if (frame != nil) // Skip letters that don't exist in this font
            [m_dictFrames setObject:frame forKey:strKey];
//		[m_dictKernData setObject:[NSNumber numberWithFloat:sflTopAlign[i]] forKey:strKey];
	}

	NSString *strKernData = [NSString stringWithFormat:@"kern_%@.plist", m_strFontName];
	NSString *path = [MRBundleResources pathForResource:strKernData];

    NSDictionary *dictData = [[NSMutableDictionary alloc] initWithContentsOfFile:path];

	m_dictKernData = [dictData objectForKey:@"height"];

    m_flFontSpacing = [[dictData objectForKey:@"font spacing"] floatValue];
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//        m_flFontSpacing *= 2.0f;
    float flDeviceAdjust = [MRUtilities getDeviceScaleAdjustment];
    m_flFontSpacing *= flDeviceAdjust;

	[MRBitmapFont addFont:self];
	return self;
}

- (float)getMaxHeight
{
    if ([m_dictFrames count] < 1)
    {
        NSLog(@"Font error: Can't find font!");
        return 12.0f;
    }

	MRSpriteFrame *sprframe = [m_dictFrames objectForKey:@"B"]; // Letter B
	if (sprframe == nil)
	{
		NSArray *aKeys = [m_dictFrames allKeys];
		NSString *strKey = [aKeys objectAtIndex:0];
		sprframe = [m_dictFrames objectForKey:strKey];
	}
	return sprframe.pointRect.size.height;
}

- (float)getSpaceWidthForFontHeight:(float)flFontHeight
{
	MRSpriteFrame *sprFrame = [m_dictFrames objectForKey:@"W"]; // Letter W
	float flScale = flFontHeight / sprFrame.pointRect.size.height;
	return sprFrame.pointRect.size.width * flScale / 3.0f;
}

- (float)getFontSpacing
{
    return m_flFontSpacing;
}

@end


#endif
