# In-App Products Manager

This is a slightly modified version of [StoreManager.m](https://developer.apple.com/library/ios/samplecode/sc1991/Listings/iOSInAppPurchases_iOSInAppPurchases_StoreManager_m.html#//apple_ref/doc/uid/DTS40014726-iOSInAppPurchases_iOSInAppPurchases_StoreManager_m-DontLinkElementID_24) / [.h](https://developer.apple.com/library/ios/samplecode/sc1991/Listings/iOSInAppPurchases_iOSInAppPurchases_StoreManager_h.html#//apple_ref/doc/uid/DTS40014726-iOSInAppPurchases_iOSInAppPurchases_StoreManager_h-DontLinkElementID_23) included in [StoreKitSuite](https://www.google.com.ua/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&cad=rja&uact=8&ved=0ahUKEwjN8LjUqKvJAhWIlHIKHdu5AOIQFggbMAA&url=https%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Fios%2Fsamplecode%2Fsc1991%2FIntroduction%2FIntro.html&usg=AFQjCNEPjfoc5IqcDDdb1UIQe2rnhcXQ9Q&sig2=xnuEyG5khlKNypOaJZfQaA)  sample code. This variant supports auto-retry and has slightly changed notifications behaviour.

## Purpose

When using In-App Purchase, before buying things, Products have to be retrieved from the App Store. As suggested by the documentation before user ever come up to your app's In-App Store, the products information has to be alredy there.

## Architecture Decision

In terms of architecture, some kind of manager needed to accomplish that. The manager stays in memmory during the lifetime of an app session and can be accessed anytime while the app is running. Accesment is made in two ways:

1. Control fetching
2. Retrieve products information

## Usage

This is exactly what original StoreManager able to do. However, I wanted it to be more robust and complex :) The manager's `fetchProductInformationForIds:` method might be called as many times as you need the products information to be refreshed. 

When manager encounters an error, it schedules itself for an attempt to retry after 15 seconds. In case, something calls `fetchProductInformationForIds:` during this "waiting", the manager resets auto-retry and starts the request from scratch.

```objective-c
- (void)fetchProductInformation
{
    NSArray* productIds = @[
                          @"com.example.inapp.car.bmw.x6_m_2016",
                          @"com.example.inapp.car.mercedes.gle450_amg_coupe_2016"
                          ];
    [[StoreManager sharedInstance] fetchProductInformationForIds:productIds];
}
```

The manager notifies observers via `NSNotificationCenter`, so to get notifications, component has to subscribe 

```objective-c
[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleStoreManagerDidChangeStatusNotification:)
                                                 name:StoreManagerDidChangeStatusNotification
                                               object:[StoreManager sharedInstance]];
```
Next, implement the selector

```objective-c
-(void)handleStoreManagerDidChangeStatusNotification:(NSNotification *)notification
{
    StoreManager *storeManager = (StoreManager*)[notification object];
    IAPProductRequestStatus result = (IAPProductRequestStatus)storeManager.status;
    
    switch (result)
    {
        case IAPRequestSuceeded: {
            NSArray* invalidProducts = storeManager.invalidProductIds;
            if (invalidProducts.count > 0) {
                NSLog(@"[WARNING]: INVALID product IDs\n%@", invalidProducts);
            }
            
            NSArray* availableProducts = storeManager.availableProducts;
            if (availableProducts.count > 0) {
                NSLog(@"[TRACE]: available product IDs\n%@", availableProducts);
            }
            
            // do other things to process product info, for example, notify UI to update
        } break;
            
        case IAPRequestFailed: {
            NSLog(@"[ERROR]: %@", storeManager.errorFromLastRequest.localizedDescription);
        } break;
            
        default: break;
    }
}
```

On the other hand, your model could be extended in this way
> Note: assuming you store InApp Product ID somewhere inside the model and the property name is `inAppProductID`

**Car+Product.m**

```objective-c
#import "Car+Product.h"
#import "StoreManager.h"

@implementation Car (Product)

- (NSString *)productPrice
{
    return [[StoreManager sharedInstance] priceMatchingProductIdentifier:self.inAppProductID];
}

- (NSString *)productTitle
{
    return [[StoreManager sharedInstance] titleMatchingProductIdentifier:self.inAppProductID];
}

- (NSString *)productDescrition
{
    return [[StoreManager sharedInstance] descriptionMatchingProductIdentifier:self.inAppProductID];
}

- (SKProduct *)product
{
    return [[StoreManager sharedInstance] productMatchingProductIdentifier:self.inAppProductID];
}

@end
```

**Car+Product.h**

```objective-c
#import "Car.h"

@class SKProduct;

@interface Car (Product)

- (NSString *)productPrice;
- (NSString *)productTitle;
- (NSString *)productDescrition;
- (SKProduct *)product;

@end
```
...and obviously, this model could be presented via some `UITableViewCell`

##TODO

* I plan to add some kind of **auto-refresh functionality** in the future, so the manager could be told once to maintain the product information refreshed during the app being active.
* Add code to demonstrate the usage
* Add CocoaPods support
* Add UintTests
