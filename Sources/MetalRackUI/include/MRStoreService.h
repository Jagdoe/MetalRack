#import <Foundation/Foundation.h>

// Objective-C bridge to the StoreKit 2 implementation in MetalRackServices.
@interface MRStoreProduct : NSObject
@property (nonatomic, readonly, copy) NSString *productIdentifier;
@property (nonatomic, readonly, copy) NSString *displayPrice;
@end
@interface MRStoreResponse : NSObject
@property (nonatomic, readonly, copy) NSArray<MRStoreProduct *> *products;
@property (nonatomic, readonly, copy) NSArray<NSString *> *invalidProductIdentifiers;
@end
@interface MRStoreTransaction : NSObject
@property (nonatomic, readonly, copy) NSString *productIdentifier;
@property (nonatomic, readonly, copy) NSString *transactionIdentifier;
@property (nonatomic, readonly, strong) NSError *error;
@property (nonatomic, readonly, copy) NSString *status;
@end
@interface MRStoreService : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (class, nonatomic, readonly, strong) MRStoreService *shared;
- (void)startObservingWithDelivery:(BOOL (^)(MRStoreTransaction *))delivery notification:(void (^)(MRStoreTransaction *))notification;
- (void)loadProducts:(NSSet<NSString *> *)identifiers completion:(void (^)(MRStoreResponse *, NSError *))completion;
- (void)purchaseProduct:(MRStoreProduct *)product;
@end
@interface MRLegacyIdentifierDigest : NSObject
+ (NSString *)digest:(NSData *)data;
@end
