#include <Utility/PathManip.h>
#include "../VFSListingInput.h"
#include "Aux.h"
#include "VFSNetDropboxHost.h"
#include "VFSNetDropboxFile.h"

using namespace VFSNetDropbox;

const char *VFSNetDropboxHost::UniqueTag = "net_dropbox";

class VFSNetDropboxHostConfiguration
{
public:
    string account;
    string token;
    string verbose;
    
    const char *Tag() const
    {
        return VFSNetDropboxHost::UniqueTag;
    }
    
    const char *Junction() const
    {
        return account.c_str();
    }
    
    bool operator==(const VFSNetDropboxHostConfiguration&_rhs) const
    {
        return account == _rhs.token && token == _rhs.token;
    }
    
    const char *VerboseJunction() const
    {
        return verbose.c_str();
    }
};

static VFSNetDropboxHostConfiguration Compose(const string &_account, const string &_token)
{
    VFSNetDropboxHostConfiguration config;
    config.account = _account;
    config.token = _token;
    config.verbose = "dropbox://"s + _account;
    return config;
}

struct VFSNetDropboxHost::State
{
    string          m_Account;
    string          m_Token;
    NSString       *m_AuthString;
    NSURLSession   *m_GenericSession;
    AccountInfo     m_AccountInfo;
};

VFSNetDropboxHost::VFSNetDropboxHost( const string &_account, const string &_access_token ):
    VFSHost("", nullptr, VFSNetDropboxHost::UniqueTag),
    I(make_unique<State>()),
    m_Config{Compose(_account, _access_token)}
{
    Init();
}

VFSNetDropboxHost::VFSNetDropboxHost( const VFSConfiguration &_config ):
    VFSHost("", nullptr, VFSNetDropboxHost::UniqueTag),
    I(make_unique<State>()),
    m_Config(_config)
{
    Init();
}

void VFSNetDropboxHost::Init()
{
    Construct(Config().account, Config().token);
    InitialAccountLookup();
    AddFeatures( VFSHostFeatures::NonEmptyRmDir );
}

void VFSNetDropboxHost::Construct(const string &_account, const string &_access_token)
{
    I->m_Account = _account;
    I->m_Token = _access_token;
    if( I->m_Token.empty() )
        throw VFSErrorException{VFSError::FromErrno(EINVAL)};
    
    I->m_GenericSession = [NSURLSession sessionWithConfiguration:
                           NSURLSessionConfiguration.defaultSessionConfiguration];
    I->m_AuthString = [NSString stringWithFormat:@"Bearer %s", I->m_Token.c_str()];
}

VFSNetDropboxHost::~VFSNetDropboxHost()
{
}

const VFSNetDropboxHostConfiguration &VFSNetDropboxHost::Config() const
{
    return m_Config.Get<VFSNetDropboxHostConfiguration>();
}

void VFSNetDropboxHost::InitialAccountLookup()
{
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::GetCurrentAccount];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req);
    if( rc == VFSError::Ok  ) {
        auto json = ParseJSON(data);
        if( !json )
            throw VFSErrorException( VFSError::FromErrno(EBADMSG) );
        I->m_AccountInfo = ParseAccountInfo(*json);
    }
    else
        throw VFSErrorException( rc );
}

pair<int, string> VFSNetDropboxHost::CheckTokenAndRetrieveAccountEmail( const string &_token )
{
    const auto config = NSURLSessionConfiguration.defaultSessionConfiguration;
    const auto session = [NSURLSession sessionWithConfiguration:config];
    const auto auth_string = [NSString stringWithFormat:@"Bearer %s", _token.c_str()];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:api::GetCurrentAccount];
    request.HTTPMethod = @"POST";
    [request setValue:auth_string forHTTPHeaderField:@"Authorization"];
    auto [rc, data] = SendSynchronousRequest(session, request);
    if( rc == VFSError::Ok  ) {
        const auto json = ParseJSON(data);
        if( !json )
            return {VFSError::FromErrno(EBADMSG), ""};
        const auto account_info = ParseAccountInfo(*json);
        return {VFSError::Ok, account_info.email};
    }
    else
        return {rc, ""};
}

VFSMeta VFSNetDropboxHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent,
                           const VFSConfiguration& _config,
                           VFSCancelChecker _cancel_checker) {
        return make_shared<VFSNetDropboxHost>(_config);
    };
    return m;
}

VFSConfiguration VFSNetDropboxHost::Configuration() const
{
    return m_Config;
}

NSURLSession *VFSNetDropboxHost::GenericSession() const
{
    return I->m_GenericSession;
}

NSURLSessionConfiguration *VFSNetDropboxHost::GenericConfiguration() const
{
    return NSURLSessionConfiguration.defaultSessionConfiguration;
}

void VFSNetDropboxHost::FillAuth( NSMutableURLRequest *_request ) const
{
    [_request setValue:I->m_AuthString forHTTPHeaderField:@"Authorization"];
}

int VFSNetDropboxHost::StatFS(const char *_path,
                              VFSStatFS &_stat,
                              const VFSCancelChecker &_cancel_checker)
{
    WarnAboutUsingInMainThread();
    
    _stat = VFSStatFS{};

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::GetSpaceUsage];
    req.HTTPMethod = @"POST";
    FillAuth(req);

    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    if( rc == VFSError::Ok ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        
        auto used = json["used"].GetInt64();
        auto allocated = json["allocation"]["allocated"].GetInt64();
        
        _stat.total_bytes = allocated;
        _stat.free_bytes = allocated - used;
        _stat.avail_bytes = _stat.free_bytes;
        _stat.volume_name = I->m_AccountInfo.email;
    }

    return rc;
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
        _st.mode = DirectoryAccessMode;
        _st.meaning.mode = true;
        return 0;
    }
    
    string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::GetMetadata];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    if( rc == VFSError::Ok ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;

        
        auto md = ParseMetadata(json);
        if( md.name.empty() )
            return VFSError::GenericError;
        
        _st.mode = md.is_directory ? DirectoryAccessMode : RegularFileAccessMode;
        _st.meaning.mode = true;

        if( md.size >= 0 ) {
            _st.size = md.size;
            _st.meaning.size = true;
        }
        
        if( md.chg_time >= 0 ) {
            _st.ctime.tv_sec = md.chg_time;
            _st.btime = _st.mtime = _st.ctime;
            _st.meaning.ctime = _st.meaning.btime = _st.meaning.mtime = true;
        }
    }
    return rc;
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

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::ListFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req);
    
    if( rc == VFSError::Ok ) {
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
                        return VFSError::Cancelled;
                }
            }
        }
    }
    
    return rc;
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

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::ListFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    if( rc == VFSError::Ok  ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        
        auto entries = ExtractMetadataEntries(json);
        
        VFSListingInput listing_source;
        listing_source.hosts[0] = shared_from_this();
        listing_source.directories[0] =  EnsureTrailingSlash(_path);
        listing_source.sizes.reset( variable_container<>::type::sparse );
        listing_source.atimes.reset( variable_container<>::type::sparse );
        listing_source.btimes.reset( variable_container<>::type::sparse );
        listing_source.ctimes.reset( variable_container<>::type::sparse );
        listing_source.mtimes.reset( variable_container<>::type::sparse );
    
        int index = 0;
        if( !(_flags & VFSFlags::F_NoDotDot) && path != "" ) {
            listing_source.filenames.emplace_back( ".." );
            listing_source.unix_modes.emplace_back( DirectoryAccessMode );
            listing_source.unix_types.emplace_back( DT_DIR );
            index++;
        }
    
        for( auto &e: entries ) {
            listing_source.filenames.emplace_back( e.name );
            listing_source.unix_modes.emplace_back( e.is_directory ?
                DirectoryAccessMode :
                RegularFileAccessMode );
            listing_source.unix_types.emplace_back( e.is_directory ? DT_DIR : DT_REG );
            if( e.size >= 0  )
                listing_source.sizes.insert( index, e.size );
            if( e.chg_time >= 0 ) {
                listing_source.btimes.insert( index, e.chg_time );
                listing_source.ctimes.insert( index, e.chg_time );
                listing_source.mtimes.insert( index, e.chg_time );
            }
            index++;
        }
    
        _target = VFSListing::Build(move(listing_source));
    }
    return rc;
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

int VFSNetDropboxHost::Unlink(const char *_path, const VFSCancelChecker &_cancel_checker )
{
   WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::Delete];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, _path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

int VFSNetDropboxHost::RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker )
{
    WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::Delete];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

int VFSNetDropboxHost::CreateDirectory(const char* _path,
                                       int _mode,
                                       const VFSCancelChecker &_cancel_checker )
{
    WarnAboutUsingInMainThread();
    
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::CreateFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

bool VFSNetDropboxHost::IsWritable() const
{
    return true;
}

int VFSNetDropboxHost::Rename(const char *_old_path,
                              const char *_new_path,
                              const VFSCancelChecker &_cancel_checker)
{
    WarnAboutUsingInMainThread();

    if( !_old_path || _old_path[0] != '/' || !_new_path || _new_path[0] != '/' )
        return VFSError::InvalidCall;
    
    const string old_path = EnsureNoTrailingSlash(_old_path);
    const string new_path = EnsureNoTrailingSlash(_new_path);

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::Move];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    const string path_spec = "{ "s +
        "\"from_path\": \"" + EscapeString(old_path) + "\", " +
        "\"to_path\": \"" + EscapeString(new_path) + "\"" +
         " }";
    [req setHTTPBody:[NSData dataWithBytes:data(path_spec) length:size(path_spec)]];
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

const string &VFSNetDropboxHost::Account() const
{
    return I->m_Account;
}
