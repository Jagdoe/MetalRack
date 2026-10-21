#import "MRSceneEnvironment.h"
@implementation MRSceneEnvironment
- (instancetype)initWithContext:(MRRenderContext *)context scheduler:(MRScheduler *)scheduler input:(MRInput *)input {
    NSParameterAssert(context && scheduler && input);
    if ((self=[super init])) { _context=context; _scheduler=scheduler; _input=input; }
    return self;
}
@end
