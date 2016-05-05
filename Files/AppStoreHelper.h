#pragma once

#ifdef __OBJC__

#include <StoreKit/StoreKit.h>

@interface AppStoreHelper : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic) function<void(const string &_id)> onProductPurchased;

- (void) askUserToBuyProFeatures;
- (void) askUserToRestorePurchases;

@end

#endif

string CFBundleGetAppStoreReceiptPath( CFBundleRef _bundle );