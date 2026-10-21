//
//  C2DFont.h
//  Befuddled2
//
//  Created by Michael Scandizzo on 3/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MRUIKit.h"
#import "MRDefinitionSprite.h"

@interface MRBitmapFont : NSObject
{
	NSString			*m_strFontName;
	NSMutableDictionary *m_dictFrames;
	NSMutableDictionary *m_dictKernData;
    float               m_flFontSpacing;
}

@property (nonatomic, readonly)	NSString *m_strFontName;
@property (nonatomic, readonly) NSMutableDictionary *m_dictFrames;
@property (nonatomic, readonly) NSMutableDictionary *m_dictKernData;


+ (MRBitmapFont *)getFontByName:(NSString *)strFontName;
+ (void)addFont:(MRBitmapFont *)font;

- (id)initWithFontName:(NSString *)strFontName;
- (float)getMaxHeight;
- (float)getSpaceWidthForFontHeight:(float)flFontHeight;
- (float)getFontSpacing;

@end
