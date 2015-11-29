/*
     File: StoreManager.m
 Abstract: Retrieves product information from the App Store using SKRequestDelegate, SKProductsRequestDelegate,SKProductsResponse, and
           SKProductsRequest. Notifies its observer with a list of products available for sale along with a list of invalid product
           identifiers. Logs an error message if the product request failed.
*/

#import "StoreManager.h"

NSString * const StoreManagerDidChangeStatusNotification = @"StoreManagerDidChangeStatusNotification";

@interface StoreManager()
<SKRequestDelegate, SKProductsRequestDelegate>
@property (nonatomic, readwrite) IAPProductRequestStatus    status;
@property (nonatomic, strong) SKProductsRequest*            currentRequest;
@property (nonatomic, strong) NSArray*                      requestedProductIdentifiers;
@property (nonatomic, getter=shouldRetryAfterFailure) BOOL  retryAfterFailure;
@property (nonatomic) NSTimeInterval                        retryDelayInSeconds;
@property (nonatomic, copy, readwrite) NSError*             errorFromLastRequest;
@end

@implementation StoreManager

+ (StoreManager *)sharedInstance
{
    static dispatch_once_t onceToken;
    static StoreManager * storeManagerSharedInstance;
    
    dispatch_once(&onceToken, ^{
        storeManagerSharedInstance = [[StoreManager alloc] init];
    });
    return storeManagerSharedInstance;
}


- (id)init
{
    self = [super init];
	if (self != nil)
	{
		_availableProducts = [[NSMutableArray alloc] initWithCapacity:0];
		_invalidProductIds = [[NSMutableArray alloc] initWithCapacity:0];
        _status = IAPRequestIdle;
        _errorFromLastRequest = nil;
        _currentRequest = nil;
        _retryAfterFailure = YES;
        _retryDelayInSeconds = 15.0;
	}
    return self;
}

#pragma mark -
#pragma mark Custom Accessors

- (void)setStatus:(IAPProductRequestStatus)status
{
    if (status != _status) {
        _status = status;
        [[NSNotificationCenter defaultCenter] postNotificationName:StoreManagerDidChangeStatusNotification object:self];
    }
}

#pragma mark -
#pragma mark Request

- (void)fetchProductInformationForIds:(NSArray *)productIds
{
    // return if in-progress OR empty productIds
    if (self.status == IAPRequestInProgress
        || productIds == nil
        || productIds.count == 0) {
        return;
    }
    
    // cancel request waiting to happen, b/c calling this method is kind of forced operation
    if (self.status == IAPRequestWaitingForRetry) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
    
    self.requestedProductIdentifiers = [productIds copy];
    
    [self.availableProducts removeAllObjects];
    [self.invalidProductIds removeAllObjects];
    
    [self startProductRequestWithProductIds:self.requestedProductIdentifiers];
}

- (void)retryFetchProductInformation
{
    assert(self.status == IAPRequestWaitingForRetry);
    assert(self.requestedProductIdentifiers);
    assert(self.requestedProductIdentifiers.count > 0);
    
    if (self.status == IAPRequestWaitingForRetry
        && self.requestedProductIdentifiers
        && self.requestedProductIdentifiers.count > 0)
    {
        [self startProductRequestWithProductIds: self.requestedProductIdentifiers];
    }
}

- (void)startProductRequestWithProductIds:(NSArray *)productIds
{
    self.errorFromLastRequest = nil;
    
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIds]];
    self.currentRequest = request;
    self.currentRequest.delegate = self;
    [self.currentRequest start];
    
    self.status = IAPRequestInProgress;
}

#pragma mark -
#pragma mark - SKProductsRequestDelegate

// Used to get the App Store's response to your request and notifies your observer
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if (![self.currentRequest isEqual:request]) {
        assert(NO);
        return;
    }
    
    if ([response.products count] > 0) {
        self.availableProducts = [NSMutableArray arrayWithArray:response.products];
    }

    if ([response.invalidProductIdentifiers count] > 0) {
        self.invalidProductIds = [NSMutableArray arrayWithArray:response.invalidProductIdentifiers];
    }
    
    self.status = IAPRequestSuceeded;
}

#pragma mark -
#pragma mark SKRequestDelegate method

- (void)requestDidFinish:(SKRequest *)request
{
    if ([request isEqual:self.currentRequest]) {
        self.requestedProductIdentifiers = nil;
        self.currentRequest = nil;
    }
}

// Called when the product request failed.
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    if (![request isEqual:self.currentRequest]) {
        assert(NO);
        return;
    }
    
    NSLog(@"[ERROR]: Error was:: %@",[error localizedDescription]);
    self.errorFromLastRequest = error;
    
    self.status = IAPRequestFailed;
    
    if ([self shouldRetryAfterFailure] && self.requestedProductIdentifiers && self.requestedProductIdentifiers.count > 0) {
        [self performSelector:@selector(retryFetchProductInformation)
                   withObject:self
                   afterDelay:self.retryDelayInSeconds];
        self.status = IAPRequestWaitingForRetry;
    }
    else {
        self.requestedProductIdentifiers = nil;
    }
    
    self.currentRequest = nil;
}

#pragma mark -
#pragma mark Helper method

// Return the product's title matching a given product identifier
- (NSString *)titleMatchingProductIdentifier:(NSString *)identifier
{
    NSString *productTitle = nil;
    SKProduct* matchingProduct = [self productMatchingProductIdentifier: identifier];
    if (matchingProduct) {
        productTitle = matchingProduct.localizedTitle;
    }
    return productTitle;
}

- (NSString *)descriptionMatchingProductIdentifier:(NSString *)identifier {
    NSString *productDescription = nil;
    SKProduct* matchingProduct = [self productMatchingProductIdentifier: identifier];
    if (matchingProduct) {
        productDescription = matchingProduct.localizedDescription;
    }
    return productDescription;
}

static NSNumberFormatter * currencyFormatter = nil;

- (NSString *)priceMatchingProductIdentifier:(NSString *)identifier
{
    NSString *productPrice = nil;
    SKProduct* matchingProduct = [self productMatchingProductIdentifier: identifier];
    if (matchingProduct) {
        if (!currencyFormatter) {
            currencyFormatter = [[NSNumberFormatter alloc] init];
            currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        }
        
        currencyFormatter.locale = matchingProduct.priceLocale;
        NSString* formattedString = [currencyFormatter stringFromNumber:matchingProduct.price];
        productPrice = formattedString;
    }
    return productPrice;
}

- (SKProduct *)productMatchingProductIdentifier:(NSString *)identifier
{
    SKProduct* result = nil;
    // Iterate through availableProducts to find the product whose productIdentifier
    // property matches identifier, return the SKProduct object when found
    for (SKProduct *product in self.availableProducts)
    {
        if ([product.productIdentifier isEqualToString:identifier])
        {
            result = product;
        }
    }
    return result;
}
@end
