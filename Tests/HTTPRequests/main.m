#import <Foundation/Foundation.h>
#import "MRHTTPRequest.h"

int main(int argc,const char **argv) {
    @autoreleasepool {
        NSString *base=[NSString stringWithUTF8String:argv[1]];
        NSURL *url=[NSURL URLWithString:[base stringByAppendingString:@"/echo"]];
        NSDictionary *fields=@{@"save":[NSData dataWithBytes:"\000\377" length:2],@"text":@"A+B & =/% é",@"query":@"query"};
        NSURLRequest *request=[MRHTTPRequest formRequestWithURL:url fields:fields];
        NSString *body=[[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        NSURLComponents *form=[NSURLComponents new];form.percentEncodedQuery=body;
        NSMutableDictionary *decoded=[NSMutableDictionary dictionary];for(NSURLQueryItem *item in form.queryItems)decoded[item.name]=item.value;
        NSCAssert([decoded[@"save"] isEqual:[fields[@"save"] description]] && [body containsString:@"text=A%2BB%20%26%20%3D%2F%25%20%C3%A9"],@"Preserve binary description and UTF-8 escaping: %@",body);
        MRHTTPResult *result=[MRHTTPRequest performRequest:request];
        NSCAssert(!result.error && [result.responseData isEqual:request.HTTPBody],@"Synchronous upload roundtrips exact bytes");
        MRHTTPResult *redirect=[MRHTTPRequest performRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/redirect"]]]];
        NSCAssert(!redirect.error && [redirect.responseString isEqual:@"café"],@"Redirect and response charset preserved");
        MRHTTPResult *unlabelled=[MRHTTPRequest performRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/unlabelled"]]]];
        NSCAssert([unlabelled.responseString isEqual:@"café"],@"Unspecified charset retains the established Latin-1 fallback");
        NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;
        __block BOOL complete=NO;
        [queue addOperation:[[MRHTTPRequest alloc] initWithRequest:request completion:^(MRHTTPResult *value){
            NSCAssert(NSThread.isMainThread && [value.responseData isEqual:request.HTTPBody],@"Async callbacks run on main with matching bytes");complete=YES;
        }]];
        NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:10];
        while(!complete && deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
        NSCAssert(complete,@"Asynchronous request finishes");
        NSURLRequest *invalid=[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:1/"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:1];
        NSCAssert([MRHTTPRequest performRequest:invalid].error,@"Transport errors propagate");
        puts("HTTP_REQUESTS_PASS exactFormBytes=1 binarySave=1 UTF8=1 charset=1 redirects=1 synchronous=1 asynchronousMainCallback=1 transportErrors=1");
    }
}
