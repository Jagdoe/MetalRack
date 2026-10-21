#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#import "MRSceneHost.h"
static Class MRHostClass;
static CGSize (^MRScreenSize)(void);
static NSDictionary *MRHostOptions;
@implementation MRSceneHost
+ (void)configureWithClass:(Class)hostClass screenSize:(CGSize (^)(void))screenSize options:(NSDictionary *)options {
    MRHostClass = hostClass;
    (void)0; MRScreenSize = [screenSize copy];
    (void)0; MRHostOptions = [options copy];
}
+ (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [MRHostClass respondsToSelector:selector];
}
+ (id)forwardingTargetForSelector:(SEL)selector { return MRHostClass; }
+ (id)sharedAppDelegate { return [MRHostClass performSelector:@selector(sharedAppDelegate)]; }
+ (UIViewController *)getGameController { return [MRHostClass performSelector:@selector(getGameController)]; }
+ (CGFloat)screenMinor { return MRScreenSize ? MRScreenSize().width : 0; }
+ (CGFloat)screenMajor { return MRScreenSize ? MRScreenSize().height : 0; }
+ (NSString *)option:(NSString *)key fallback:(NSString *)fallback { return MRHostOptions[key] ?: fallback; }
@end
#endif
