#import <Foundation/Foundation.h>
@interface MRDefinitions:NSObject
+ (instancetype)sharedDefsManager;
- (NSDictionary *)getDefByClass:(NSString *)name Type:(NSString *)type;
@end
