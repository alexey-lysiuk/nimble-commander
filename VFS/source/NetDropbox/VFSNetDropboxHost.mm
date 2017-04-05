#include <Utility/PathManip.h>
#include "../VFSListingInput.h"
#include "Aux.h"
#include "VFSNetDropboxHost.h"
#include "VFSNetDropboxFile.h"

using namespace VFSNetDropbox;

const char *VFSNetDropboxHost::Tag = "net_dropbox";

static const auto g_GetCurrentAccount = [NSURL URLWithString:@"https://api.dropboxapi.com/2/users/get_current_account"];
static const auto g_GetSpaceUsage = [NSURL URLWithString:@"https://api.dropboxapi.com/2/users/get_space_usage"];
static const auto g_GetMetadata = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/get_metadata"];
static const auto g_ListFolder = [NSURL URLWithString:@"https://api.dropboxapi.com/2/files/list_folder"];

static optional<rapidjson::Document> ParseJSON( NSData *_data )
{
    using namespace rapidjson;
    Document json;
    ParseResult ok = json.Parse<kParseNoFlags>( (const char *)_data.bytes, _data.length );
    if( !ok )
        return nullopt;
    return move(json);
}


struct VFSNetDropboxHost::State
{
    string          m_Token;
    NSString       *m_AuthString;
    NSURLSession   *m_GenericSession;
    AccountInfo     m_AccountInfo;
};

VFSNetDropboxHost::VFSNetDropboxHost( const string &_access_token ):
    VFSHost("", nullptr, VFSNetDropboxHost::Tag),
    I(make_unique<State>())
{
    I->m_Token = _access_token;
    if( I->m_Token.empty() )
        throw invalid_argument("bad token");
    
    
    I->m_GenericSession = [NSURLSession sessionWithConfiguration:
        NSURLSessionConfiguration.defaultSessionConfiguration];
    I->m_AuthString = [NSString stringWithFormat:@"Bearer %s", I->m_Token.c_str()];
    
    InitialAccountLookup();
}

VFSNetDropboxHost::~VFSNetDropboxHost()
{
}

void VFSNetDropboxHost::InitialAccountLookup()
{
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_GetCurrentAccount];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    
    NSURLResponse *response;
    auto data = SendSynchonousRequest(GenericSession(), req, &response, nullptr);
    if( IsNormalJSONResponse(response) && data ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            throw VFSErrorException( VFSError::FromErrno(EIO) );
    
    
        I->m_AccountInfo = ParseAccountInfo(*json_opt);

        int a = 10;
        return;
    
//        using namespace rapidjson;
//        Document json;
//        ParseResult ok = json.Parse<kParseNoFlags>( (const char *)data.bytes, data.length );
//        if( !ok ) {
//            return -1;
//        }

//        auto used = json["used"].GetInt64();
//        auto allocated = json["allocation"]["allocated"].GetInt64();
//        
//        _stat.total_bytes = allocated;
//        _stat.free_bytes = allocated - used;
//        _stat.avail_bytes = _stat.free_bytes;
//
//        return 0;
    }

    // TODO: process response
    throw VFSErrorException( VFSError::FromErrno(EIO) );
//    return VFSError::GenericError
}

bool VFSNetDropboxHost::ShouldProduceThumbnails() const
{
    return false;
}

NSURLSession *VFSNetDropboxHost::GenericSession()
{
    return I->m_GenericSession;
}

void VFSNetDropboxHost::FillAuth( NSMutableURLRequest *_request )
{
    [_request setValue:I->m_AuthString forHTTPHeaderField:@"Authorization"];
}

int VFSNetDropboxHost::StatFS(const char *_path,
                              VFSStatFS &_stat,
                              const VFSCancelChecker &_cancel_checker)
{
    WarnAboutUsingInMainThread();
    
    _stat.total_bytes = 0;
    _stat.free_bytes = 0;
    _stat.avail_bytes = 0;
    _stat.volume_name = I->m_AccountInfo.email;

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_GetSpaceUsage];
    req.HTTPMethod = @"POST";
    FillAuth(req);

// bad:
//code: 400, headers {
//    Connection = "keep-alive";
//    "Content-Length" = 99;
//    "Content-Type" = "text/plain; charset=utf-8";
//    Date = "Mon, 03 Apr 2017 05:24:27 GMT";
//    Server = nginx;
//    "X-Dropbox-Request-Id" = 741be324f7c5291d075c14d53cb04e9e;
//}


// good:
//code: 200, headers {
//    "Cache-Control" = "no-cache";
//    Connection = "keep-alive";
//    "Content-Encoding" = gzip;
//    "Content-Type" = "application/json";
//    Date = "Mon, 03 Apr 2017 05:23:26 GMT";
//    Pragma = "no-cache";
//    Server = nginx;
//    "Transfer-Encoding" = Identity;
//    Vary = "Accept-Encoding";
//    "X-Content-Type-Options" = nosniff;
//    "X-Dropbox-Http-Protocol" = None;
//    "X-Dropbox-Request-Id" = a688c4a4567d0308c528bcfec9efbb29;
//    "X-Frame-Options" = SAMEORIGIN;
//    "X-Server-Response-Time" = 69;

    NSURLResponse *response;
    auto data = SendSynchonousRequest(GenericSession(), req, &response, nullptr);
    if( data ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        

        auto used = json["used"].GetInt64();
        auto allocated = json["allocation"]["allocated"].GetInt64();
        
        _stat.total_bytes = allocated;
        _stat.free_bytes = allocated - used;
        _stat.avail_bytes = _stat.free_bytes;

        return 0;
    }

    return VFSError::GenericError;
}

int VFSNetDropboxHost::Stat(const char *_path,
                            VFSStat &_st,
                            int _flags,
                            const VFSCancelChecker &_cancel_checker)
{
    WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
        memset( &_st, 0, sizeof(_st) );
    
    if( strcmp( _path, "/") == 0 ) {
        // special treatment for root dir
        _st.mode = S_IRUSR | S_IWUSR | S_IFDIR;
        _st.meaning.mode = true;
        return 0;
    }
    
    
    string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_GetMetadata];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    string body = "{ \"path\": \"" + EscapeString(path) + "\"}";
    [req setHTTPBody:[NSData dataWithBytes:data(body) length:size(body)]];
    
    
    NSURLResponse *response;
    auto data = SendSynchonousRequest(GenericSession(), req, &response, nullptr);
    
    if( IsNormalJSONResponse(response) && data ) {
        /// ....
//        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);

        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;

        
        auto md = ParseMetadata(json);
        if( md.name.empty() )
            return VFSError::GenericError;
        
        if( md.is_directory  ) {
            _st.mode = S_IRUSR | S_IWUSR | S_IFDIR;
            _st.meaning.mode = true;
        }
        else {
            _st.mode = S_IRUSR | S_IWUSR | S_IFREG;
            _st.meaning.mode = true;
        }

        if( md.size >= 0 ) {
            _st.size = md.size;
            _st.meaning.size = true;
        }
        
        if( md.chg_time >= 0 ) {
            _st.ctime.tv_sec = md.chg_time;
            _st.btime = _st.mtime = _st.ctime;
            _st.meaning.ctime = _st.meaning.btime = _st.meaning.mtime = true;
        }
        
        return 0;
    }
    else if( data ) {
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    }
    return VFSError::GenericError;
}

int VFSNetDropboxHost::IterateDirectoryListing(const char *_path,
                                               const function<bool(const VFSDirEnt &_dirent)> &_handler)
{ // TODO: process ListFolderResult.has_more
    WarnAboutUsingInMainThread();

  if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_ListFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    string body = "{ \"path\": \"" + EscapeString(path) + "\"}";
    [req setHTTPBody:[NSData dataWithBytes:data(body) length:size(body)]];
    
    NSURLResponse *response;
    auto data = SendSynchonousRequest(GenericSession(), req, &response, nullptr);
    
    if( IsNormalJSONResponse(response) && data ) {
        /// ....
//        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
     
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        
        auto entries = json.FindMember("entries");
        if( entries != json.MemberEnd() ) {
            for( int i = 0, e = entries->value.Size(); i != e; ++i ) {
                auto &entry = entries->value[i];

                auto metadata = ParseMetadata(entry);
                if( !metadata.name.empty() ) {
                    VFSDirEnt dirent;
                    dirent.type = metadata.is_directory ? VFSDirEnt::Dir : VFSDirEnt::Reg;
                    strcpy( dirent.name, metadata.name.c_str() );
                    dirent.name_len = metadata.name.length();
                    bool goon = _handler(dirent);
                    if( !goon )
                        return VFSError::Ok;
                }
            }
        }
        
        
        
        return VFSError::Ok;
    }
    else if( data ) {
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    }
    
    return VFSError::GenericError;
}

int VFSNetDropboxHost::FetchDirectoryListing(const char *_path,
                                             shared_ptr<VFSListing> &_target,
                                             int _flags,
                                             const VFSCancelChecker &_cancel_checker)
{ // TODO: process ListFolderResult.has_more
    WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:g_ListFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    string body = "{ \"path\": \"" + EscapeString(path) + "\"}";
    [req setHTTPBody:[NSData dataWithBytes:data(body) length:size(body)]];
    
    NSURLResponse *response;
    auto data = SendSynchonousRequest(GenericSession(), req, &response, nullptr);
    
    if( IsNormalJSONResponse(response) && data ) {
        /// ....
//        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
     
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        
        auto entries = ExtractMetadataEntries(json);
        
        
        // set up our listing structure
        VFSListingInput listing_source;
        listing_source.hosts[0] = shared_from_this();
        
        
        
        listing_source.directories[0] =  EnsureTrailingSlash(_path);
        listing_source.sizes.reset( variable_container<>::type::sparse );
        listing_source.atimes.reset( variable_container<>::type::sparse );
        listing_source.btimes.reset( variable_container<>::type::sparse );
        listing_source.ctimes.reset( variable_container<>::type::sparse );
        listing_source.mtimes.reset( variable_container<>::type::sparse );
    
        for( int index = 0, index_e = (int)entries.size(); index != index_e; ++index ) {
            auto &e = entries[index];
            listing_source.filenames.emplace_back( e.name );
            listing_source.unix_modes.emplace_back( e.is_directory ?
                (S_IRUSR | S_IWUSR | S_IFDIR) :
                (S_IRUSR | S_IWUSR | S_IFREG) );
            listing_source.unix_types.emplace_back( e.is_directory ? DT_DIR : DT_REG );
            if( e.size >= 0  )
                listing_source.sizes.insert( index, e.size );
            if( e.chg_time >= 0 ) {
                listing_source.btimes.insert( index, e.chg_time );
                listing_source.ctimes.insert( index, e.chg_time );
                listing_source.mtimes.insert( index, e.chg_time );
            }
        }
    
        _target = VFSListing::Build(move(listing_source));
        
        return 0;
    }
    else if( data ) {
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    }
    


    return VFSError::GenericError;
}

int VFSNetDropboxHost::CreateFile(const char* _path,
                                  shared_ptr<VFSFile> &_target,
                                  const VFSCancelChecker &_cancel_checker)
{
    auto file = make_shared<VFSNetDropboxFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

const string &VFSNetDropboxHost::Token() const
{
    return I->m_Token;
}
