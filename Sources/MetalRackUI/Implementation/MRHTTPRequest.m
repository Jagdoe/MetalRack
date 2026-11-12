#import "MRHTTPRequest.h"

@interface MRHTTPResult ()
@property (nonatomic, readwrite, strong) NSData *responseData;
@property (nonatomic, readwrite, strong) NSURLResponse *response;
@property (nonatomic, readwrite, strong) NSError *error;
@end
@implementation MRHTTPResult
- (NSString *)responseString {
    // Preserve the established client fallback when the server omits charset.
    NSStringEncoding encoding=NSISOLatin1StringEncoding;
    if(self.response.textEncodingName.length) {
        CFStringEncoding cf=CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)self.response.textEncodingName);
        if(cf!=kCFStringEncodingInvalidId)encoding=CFStringConvertEncodingToNSStringEncoding(cf);
    }
    return [[NSString alloc] initWithData:self.responseData encoding:encoding];
}
@end

@implementation MRHTTPRequest {
    NSURLRequest *_request;
    void (^_completion)(MRHTTPResult *);
}
- (instancetype)initWithRequest:(NSURLRequest *)request completion:(void (^)(MRHTTPResult *))completion {
    if((self=[super init])){_request=[request copy];_completion=[completion copy];}
    return self;
}
+ (NSURLRequest *)formRequestWithURL:(NSURL *)url fields:(NSDictionary<NSString *,id> *)fields {
    // Match the established server's UTF-8 form representation, including
    // NSData.description for compressed binary saves. Do not change its wire format.
    NSMutableCharacterSet *allowed=[[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowed removeCharactersInString:@":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"];
    NSMutableArray *pairs=[NSMutableArray array];
    for(NSString *key in [[fields allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *name=[key stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        NSString *value=[[fields[key] description] stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        [pairs addObject:[NSString stringWithFormat:@"%@=%@",name,value]];
    }
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
    request.HTTPMethod=@"POST";
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody=[[pairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    return request;
}
+ (MRHTTPResult *)performRequest:(NSURLRequest *)request {
    MRHTTPResult *result=[MRHTTPResult new];
    dispatch_semaphore_t finished=dispatch_semaphore_create(0);
    // NSURLSession's private delegate queue can complete while the calling
    // thread is blocked; never schedule this completion onto the main queue.
    NSURLSession *session=[NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    NSURLSessionDataTask *task=[session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
        result.responseData=data;result.response=response;result.error=error;
        [session finishTasksAndInvalidate];dispatch_semaphore_signal(finished);
    }];
    [task resume];dispatch_semaphore_wait(finished,DISPATCH_TIME_FOREVER);
    return result;
}
- (void)main {
    if(self.cancelled)return;
    MRHTTPResult *result=[MRHTTPRequest performRequest:_request];
    if(!self.cancelled && _completion)dispatch_async(dispatch_get_main_queue(),^{ self->_completion(result); });
}
@end
