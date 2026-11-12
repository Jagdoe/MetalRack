#import <Foundation/Foundation.h>

@interface MRHTTPResult : NSObject
@property (nonatomic, readonly, strong) NSData *responseData;
@property (nonatomic, readonly, strong) NSURLResponse *response;
@property (nonatomic, readonly, strong) NSError *error;
@property (nonatomic, readonly, copy) NSString *responseString;
@end

@interface MRHTTPRequest : NSOperation
- (instancetype)initWithRequest:(NSURLRequest *)request completion:(void (^)(MRHTTPResult *))completion;
+ (NSURLRequest *)formRequestWithURL:(NSURL *)url fields:(NSDictionary<NSString *, id> *)fields;
// Callback execution is left to the caller; safe on a worker or during the
// existing application-suspension synchronous save path.
+ (MRHTTPResult *)performRequest:(NSURLRequest *)request;
@end
