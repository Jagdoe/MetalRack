#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// The application supplies its delegate class and live logical dimensions.
// Optional deviceScaleAdjustment (positive finite string) overrides the legacy
// phone 1/tablet 2 layout multiplier; it does not resize atlas frame geometry.
// The package never imports or names an application class.
@interface MRSceneHost : NSObject
+ (void)configureWithClass:(Class)hostClass screenSize:(CGSize (^)(void))screenSize options:(NSDictionary *)options;
+ (id)sharedAppDelegate;
+ (UIViewController *)getGameController;
+ (CGFloat)screenMinor;
+ (CGFloat)screenMajor;
+ (NSString *)option:(NSString *)key fallback:(NSString *)fallback;
@end
