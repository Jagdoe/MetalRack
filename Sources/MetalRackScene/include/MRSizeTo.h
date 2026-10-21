#pragma once
#import "MRActionInterval.h"
@interface MRSizeTo : MRActionInterval <NSCopying>
{
	float sizeX_;
	float sizeY_;
	float startSizeX_;
	float startSizeY_;
	float endSizeX_;
	float endSizeY_;
	float deltaX_;
	float deltaY_;
}

/** creates the action with and X factor and a Y factor */
+(id) actionWithDuration: (MRTime)duration sizeX:(float) sx sizeY:(float)sy;
/** initializes the action with and X factor and a Y factor */
-(id) initWithDuration: (MRTime)duration sizeX:(float) sx sizeY:(float)sy;

@end
