#include <boost/uuid/random_generator.hpp>
#include <boost/uuid/string_generator.hpp>
#include <boost/uuid/uuid_io.hpp>
#include <Habanero/algo.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Utility/SystemInformation.h>
#include "GoogleAnalytics.h"

static const auto g_TrackingID = "UA-47180125-2"s;
static const auto g_DefaultsClientIDKey = CFSTR("GATrackingUUID");
static const auto g_SendingDelay = /*2min*/10s;
static const auto g_URLSingle = @"http://www.google-analytics.com/collect";
static const auto g_URLBatch  = @"http://www.google-analytics.com/batch";
static const auto g_MessagesOverflowLimit = 100;

static string GetStoredOrNewClientID()
{
    if( auto stored_id = CFDefaultsGetOptionalString(g_DefaultsClientIDKey) )
        return *stored_id;

    auto client_id = to_string( boost::uuids::basic_random_generator<boost::mt19937>()() );
    CFDefaultsSetString(g_DefaultsClientIDKey, client_id);
    return client_id;
}

static string GetAppName()
{
    if( auto s = objc_cast<NSString>([NSBundle.mainBundle.infoDictionary valueForKey:(id)kCFBundleNameKey]) )
        return s.UTF8String;
    return "Unknown";
}

static string GetAppVersion()
{
    if( auto s = objc_cast<NSString>([NSBundle.mainBundle.infoDictionary valueForKey:@"CFBundleShortVersionString"]) )
        return s.UTF8String;
    return "0.0.0";
}

static string EscapeString(const string &_original) // very inefficient
{
    return [[NSString stringWithUTF8StdString:_original] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet].UTF8String;
}

static string EscapeString(const char *_original) // very inefficient
{
    return [[NSString stringWithUTF8String:_original] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet].UTF8String;
}

GoogleAnalytics& GoogleAnalytics::Instance()
{
    static auto inst = new GoogleAnalytics;
    return *inst;
}

//App / Screen Tracking
//v=1                         // Version.
//&tid=UA-XXXXX-Y             // Tracking ID / Property ID.
//&cid=555                    // Anonymous Client ID.
//&t=screenview               // Screenview hit type.
//&an=funTimes                // App name.
//&av=4.2.0                   // App version.
//&aid=com.foo.App            // App Id.
//&aiid=com.android.vending   // App Installer Id.
//&cd=Home                    // Screen name / content description.

//Mozilla/5.0 (Linux; Android 4.4.2; Nexus 5 Build/KOT49H)

static NSString *GetUserAgent()
{
    sysinfo::SystemOverview sysoverview;
    sysinfo::GetSystemOverview(sysoverview);
    
    NSDictionary *osInfo = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    
//    NSLocale *currentLocale = [NSLocale autoupdatingCurrentLocale];
//    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/3.0 (Macintosh; Intel %@ %@; %@-%@; %@)",
    NSString *UA = [NSString stringWithFormat:@"GoogleAnalytics/3.0 (Macintosh; Intel %@ %@; %@)",
                    osInfo[@"ProductName"],
                    [osInfo[@"ProductVersion"] stringByReplacingOccurrencesOfString:@"." withString:@"_"],
//                    [currentLocale objectForKey:NSLocaleLanguageCode],
//                    [currentLocale objectForKey:NSLocaleCountryCode],
                    [NSString stringWithUTF8StdString:sysoverview.coded_model]
                    ];
    return UA;
}

static NSURLSession *GetPostingSession()
{
    static NSURLSession *session = []{
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.discretionary = true;
        config.networkServiceType = NSURLNetworkServiceTypeBackground;
        config.HTTPShouldSetCookies = false;
        config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
        config.HTTPAdditionalHeaders = @{ @"User-Agent": GetUserAgent() };
        
        return [NSURLSession sessionWithConfiguration:config];
    }();
    
    return session;
}

GoogleAnalytics::GoogleAnalytics():
    m_ClientID( GetStoredOrNewClientID() ),
    m_AppName( GetAppName() ),
    m_AppVersion( GetAppVersion() )
{
    m_PayloadPrefix =   "v=1"s + "&"
                        "tid=" + g_TrackingID + "&" +
                        "cid=" + m_ClientID + "&" +
                        "an="  + EscapeString(m_AppName) + "&" +
                        "av="  + m_AppVersion + "&";
    
    m_Enabled = true;
}

void GoogleAnalytics::PostScreenView(const char *_screen)
{
    if( !m_Enabled )
        return;
    
    string message = "t=screenview&cd="s + _screen;
    
    AcceptMessage( EscapeString(message) );
}

void GoogleAnalytics::PostEvent(const char *_category, const char *_action, const char *_label, unsigned _value)
{
    if( !m_Enabled )
        return;

    string message = "t=event&ec="s + _category + "&ea=" + _action + "&el=" + _label + "&ev=" + to_string(_value);

    AcceptMessage( EscapeString(message) );
}

void GoogleAnalytics::AcceptMessage(string _message)
{
    // TODO: check if analytics is off
    
    LOCK_GUARD(m_MessagesLock) {
        if(m_Messages.size() < g_MessagesOverflowLimit)
            m_Messages.emplace_back( move(_message) );
    }
    
    MarkDirty();
}

void GoogleAnalytics::MarkDirty()
{
    if( !m_SendingScheduled.test_and_set() )
        dispatch_to_background_after(g_SendingDelay, [=]{
            PostMessages();
            m_SendingScheduled.clear();
        });
}

void GoogleAnalytics::PostMessages()
{
    dispatch_assert_background_queue();
    static auto batch_url = [NSURL URLWithString:g_URLBatch];
    
    vector<string> messages;
    LOCK_GUARD(m_MessagesLock)
        messages = move(m_Messages);
    
    string payload;
    for( size_t ind = 0, ind_max = messages.size(); ind < ind_max; ) {
        
        payload.clear();
        for(int i = 0; i < 20 && ind < ind_max; ++i, ++ind) {
            payload += m_PayloadPrefix;
            payload += messages[ind];
            payload += "\n";
        }
        
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:batch_url];
        req.HTTPMethod = @"POST";
        req.HTTPBody = [NSData dataWithBytes:payload.data() length:payload.length()];
        
        NSURLSessionDataTask *task = [GetPostingSession() dataTaskWithRequest:req completionHandler:^(NSData* d, NSURLResponse* r, NSError* e){}];
        [task resume];
    }
}
