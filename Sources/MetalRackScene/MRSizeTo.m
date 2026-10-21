// Native size interpolation, adapted from Michael Scandizzo's 2010 C2DAction.
#import "MRSizeTo.h"
@implementation MRSizeTo

+(id) actionWithDuration: (MRTime) t sizeX:(float)sx sizeY:(float)sy
{
	return ([[self alloc] initWithDuration: t sizeX:sx sizeY:sy]);
}

-(id) initWithDuration: (MRTime) t sizeX:(float)sx sizeY:(float)sy
{
	if( (self=[super initWithDuration: t]) ) {
		endSizeX_ = sx;
		endSizeY_ = sy;
	}
	return self;
}

-(id) copyWithZone: (NSZone*) zone
{
	MRAction *copy = [[[self class] allocWithZone: zone] initWithDuration:[self duration] sizeX:endSizeX_ sizeY:endSizeY_];
	return copy;
}

-(void) startWithTarget:(MRNode *)aTarget
{
	[super startWithTarget:aTarget];
	CGSize size = [target_ contentSize];
	startSizeX_ = size.width;
	startSizeY_ = size.height;
	deltaX_ = endSizeX_ - startSizeX_;
	deltaY_ = endSizeY_ - startSizeY_;
}

-(void) update: (MRTime) t
{
	[target_ setContentSize:CGSizeMake(startSizeX_ + deltaX_ * t, startSizeY_ + deltaY_ * t)];
}
@end
