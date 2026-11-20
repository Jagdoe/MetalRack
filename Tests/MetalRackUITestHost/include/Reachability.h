#import <Foundation/Foundation.h>
// MetalRackUI gets this optional network provider from its host. Culling tests
// must never use it: provide the linker class and fail if queried.
@interface Reachability : NSObject
+ (instancetype)reachabilityForInternetConnection;
@end
