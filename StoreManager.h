/*
     File: StoreManager.h
 Abstract: Retrieves product information from the App Store using SKRequestDelegate,
           SKProductsRequestDelegate,SKProductsResponse, and SKProductsRequest.
           Notifies its observer with a list of products available for sale along with
           a list of invalid product identifiers. Logs an error message if the product request failed.
 */

@import StoreKit;

// Provide notification about the product request
NSString * const StoreManagerDidChangeStatusNotification;

typedef NS_ENUM(NSInteger, IAPProductRequestStatus)
{
    IAPRequestIdle,
    IAPRequestInProgress,
    IAPRequestSuceeded,
    IAPRequestFailed,
    IAPRequestWaitingForRetry,
};

@interface StoreManager : NSObject

// Provide the status of the product request
@property (nonatomic, readonly) IAPProductRequestStatus status;

// Indicate the cause of the product request failure
@property (nonatomic, copy, readonly) NSError* errorFromLastRequest;

+ (StoreManager *)sharedInstance;

// Query the App Store about the given product identifiers
- (void)fetchProductInformationForIds:(NSArray *)productIds;

// Keep track of all valid products. These products are available for sale in the App Store
@property (nonatomic, strong) NSMutableArray *availableProducts;
// Keep track of all invalid product identifiers
@property (nonatomic, strong) NSMutableArray *invalidProductIds;

// Return the product's title matching a given product identifier
- (NSString *)titleMatchingProductIdentifier:(NSString *)identifier;
- (NSString *)descriptionMatchingProductIdentifier:(NSString *)identifier;
- (NSString *)priceMatchingProductIdentifier:(NSString *)identifier;
- (SKProduct *)productMatchingProductIdentifier:(NSString *)identifier;

@end
