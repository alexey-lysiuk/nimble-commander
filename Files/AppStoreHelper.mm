#include <Habanero/CFDefaultsCPP.h>
#include "../NimbleCommander/GeneralUI/ProFeaturesWindowController.h"
#include "../NimbleCommander/Core/FeedbackManager.h"
#include "GoogleAnalytics.h"
#include "AppStoreHelper.h"

static const auto g_ProFeaturesInAppID  = @"com.magnumbytes.nimblecommander.paid_features";
static const auto g_PrefsPriceString    = @"proFeaturesIAPPriceString";
static const auto g_PrefsPFDontShow     = CFSTR("proFeaturesIAPDontShow");
static const auto g_PrefsPFNextTime     = CFSTR("proFeaturesIAPNextShowTime");

string CFBundleGetAppStoreReceiptPath( CFBundleRef _bundle )
{
    if( !_bundle )
        return "";
    
    CFURLRef url = CFBundleCopyBundleURL( _bundle );
    if( !url )
        return "";
    
    NSBundle *bundle = [NSBundle bundleWithURL:(NSURL*)CFBridgingRelease(url)];
    if( !bundle )
        return "";
    
    return bundle.appStoreReceiptURL.fileSystemRepresentation;
}

@implementation AppStoreHelper
{
    SKProductsRequest                   *m_ProductRequest;
    SKProduct                           *m_ProFeaturesProduct;
    function<void(const string &_id)>   m_PurchaseCallback;
    NSString                            *m_PriceString;
}

@synthesize onProductPurchased = m_PurchaseCallback;
@synthesize priceString = m_PriceString;

- (id) init
{
    if(self = [super init]) {
        [SKPaymentQueue.defaultQueue addTransactionObserver:self];
        
        m_ProductRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:g_ProFeaturesInAppID]];
        m_ProductRequest.delegate = self;
        [m_ProductRequest start];
        m_PriceString = [NSUserDefaults.standardUserDefaults objectForKey:g_PrefsPriceString];
        if( !m_PriceString )
            m_PriceString = @"";
    }
    return self;
}

// background thread
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    for( SKProduct* p in response.products ) {
        if( [p.productIdentifier isEqualToString:g_ProFeaturesInAppID] ) {
            m_ProFeaturesProduct = p;
            
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
            formatter.numberStyle = NSNumberFormatterCurrencyStyle;
            formatter.locale = p.priceLocale;
            NSString *price_string = [formatter stringFromNumber:p.price];
            if( ![price_string isEqualToString:m_PriceString] ) {
                m_PriceString = price_string;
                [NSUserDefaults.standardUserDefaults setObject:m_PriceString forKey:g_PrefsPriceString];
            }
        }
    }
}

// background thread
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
}

// background thread
- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for( SKPaymentTransaction *pt in transactions ) {
        switch( pt.transactionState ) {
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored: {
                string identifier = pt.payment.productIdentifier.UTF8String;
                auto callback = m_PurchaseCallback;
                if( callback )
                    dispatch_to_main_queue([=]{ callback(identifier); } );                
                [queue finishTransaction:pt];
                break;
            }
            case SKPaymentTransactionStateFailed:
            case SKPaymentTransactionStateDeferred:;
                [queue finishTransaction:pt];
                break;
            default:
                break;
        }
    }
}

- (void) askUserToBuyProFeatures
{
    if( !m_ProFeaturesProduct )
        return;
    
    
    SKPayment *payment = [SKPayment paymentWithProduct:m_ProFeaturesProduct];
    [SKPaymentQueue.defaultQueue addPayment:payment];
}

- (void) askUserToRestorePurchases
{
    if( !m_ProFeaturesProduct )
        return;
    
    GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Buy Pro features IAP");
    [SKPaymentQueue.defaultQueue restoreCompletedTransactions];
}

//- (void) paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
//{
//    auto callback = m_PurchaseCallback;
//    for( SKPaymentTransaction *transaction in queue.transactions ) {
//        string identifier = transaction.payment.productIdentifier.UTF8String;
//        if( callback )
//            dispatch_to_main_queue([=]{ callback(identifier); } );
//    }
//}

- (void) showProFeaturesWindow
{
    dispatch_assert_main_queue();
    ProFeaturesWindowController *w = [[ProFeaturesWindowController alloc] init];
    w.suppressDontShowAgain = true;
    GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Show Pro features IAP");
    
    const auto result = [NSApp runModalForWindow:w.window];
    
    if( result == NSModalResponseOK )
        [self askUserToBuyProFeatures];
}

- (void) showProFeaturesWindowIfNeededAsNagScreen
{
    dispatch_assert_main_queue();
    const auto min_runs = 10;
    const auto next_show_delay = 60l * 60l* 24l * 14l; // every 14 days

    if( FeedbackManager::Instance().ApplicationRunsCount() < min_runs ||    // don't show nag screen if user didn't use software for long enough
        CFDefaultsGetBool(g_PrefsPFDontShow) )                              // don't show nag screen it user has opted to
        return;
    
    const auto next_time = CFDefaultsGetOptionalLong(g_PrefsPFNextTime);
    if( next_time && *next_time > time(0) )
        return; // it's not time yet
    
    // setup next show time
    CFDefaultsSetLong(g_PrefsPFNextTime, time(0) + next_show_delay);
    
    // let's show a nag screen
    GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Show Pro features IAP As Nagscreen");

    ProFeaturesWindowController *w = [[ProFeaturesWindowController alloc] init];
    const auto result = [NSApp runModalForWindow:w.window];
    
    if( w.dontShowAgain )
        CFDefaultsSetBool(g_PrefsPFDontShow, true);
    if( result == NSModalResponseOK )
        [self askUserToBuyProFeatures];
}

@end
