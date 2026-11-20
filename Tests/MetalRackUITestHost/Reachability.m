#import "Reachability.h"
@implementation Reachability
+ (instancetype)reachabilityForInternetConnection {
    [NSException raise:NSInternalInconsistencyException format:@"Culling tests must not call network utilities"];
    return nil;
}
@end
