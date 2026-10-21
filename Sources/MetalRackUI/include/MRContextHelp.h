//
//  ContextHelp.h
//  Befuddled2
//
//  Created by Michael Scandizzo on 11/17/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MRGestureLayer.h"

#define TAG_CONTEXT_HELP_LAYER	(345)

@class MRPlacementScene;
@class MRLayer;

@interface MRContextHelp : NSObject <MRGestureDelegate>
{
	NSDictionary	*m_dictHelp;
	NSMutableArray	*m_aHelpStack;
	NSString		*m_strCurrentContext;
}

+ (id)sharedContextHelp;

- (id)displayHelpForContext:(NSString *)strContext;

@end
