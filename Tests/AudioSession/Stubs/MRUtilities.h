#import <Foundation/Foundation.h>
#define MR_PREFS_KEY_MUSIC @"music"
@interface MRUtilities:NSObject
+ (NSString *)getContentStringForKey:(NSString *)key;
+ (void)setContentStringForKey:(NSString *)key withString:(NSString *)value;
@end
