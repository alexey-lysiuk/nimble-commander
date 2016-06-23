#include "ExternalToolsSupport.h"
#include "../../../Files/Config.h"
#include "../../../Files/rapidjson.h"

ExternalToolsParameters::Step::Step(ActionType t, uint16_t i):
    type(t),
    index(i)
{
}

void ExternalToolsParameters::InsertUserDefinedText(UserDefined _ud)
{
    m_Steps.emplace_back( ActionType::UserDefined, m_UserDefined.size() );
    m_UserDefined.emplace_back( move(_ud) );
}

void ExternalToolsParameters::InsertValueRequirement(EnterValue _ev)
{
    m_Steps.emplace_back( ActionType::EnterValue, m_EnterValues.size() );
    m_EnterValues.emplace_back( move(_ev) );
}

void ExternalToolsParameters::InsertCurrentItem(CurrentItem _ci)
{
    m_Steps.emplace_back( ActionType::CurrentItem, m_CurrentItems.size() );
    m_CurrentItems.emplace_back( move(_ci) );
}

void ExternalToolsParameters::InsertSelectedItem(SelectedItems _si)
{
    m_Steps.emplace_back( ActionType::SelectedItems, m_SelectedItems.size() );
    m_SelectedItems.emplace_back( move(_si) );
}

const ExternalToolsParameters::Step &ExternalToolsParameters::StepNo(unsigned _number) const
{
    return m_Steps.at(_number);
}

unsigned ExternalToolsParameters::StepsAmount() const
{
    return (unsigned)m_Steps.size();
}

const ExternalToolsParameters::UserDefined &ExternalToolsParameters::GetUserDefined( unsigned _index ) const
{
    return m_UserDefined.at(_index);
}
const ExternalToolsParameters::EnterValue &ExternalToolsParameters::GetEnterValue( unsigned _index ) const
{
    return m_EnterValues.at(_index);
}

const ExternalToolsParameters::CurrentItem &ExternalToolsParameters::GetCurrentItem( unsigned _index ) const
{
    return m_CurrentItems.at(_index);
}

const ExternalToolsParameters::SelectedItems &ExternalToolsParameters::GetSelectedItems( unsigned _index ) const
{
    return m_SelectedItems.at(_index);
}

unsigned ExternalToolsParameters::GetMaximumTotalFiles() const
{
    return m_MaximumTotalFiles;
}

namespace {
    
struct InterpretInvertFlag{};
struct SetMaximumFilesFlag{ unsigned maximum; };
    
}

static pair<any, unsigned> Eat( NSString *_source, NSRange _range, bool _invert_flag )
{
    assert( _source && _source.length == _range.location + _range.length );
    assert( _range.length > 0 );
    static NSCharacterSet *percent = [NSCharacterSet characterSetWithCharactersInString:@"%"];
    static NSCharacterSet *quote = [NSCharacterSet characterSetWithCharactersInString:@"\""];
        
    const auto r = [_source rangeOfCharacterFromSet:percent options:0 range:_range];
    if( r.location != NSNotFound ) {
        // found % somewhere in the string
        if( r.location == _range.location ) {
            // we're right at % symbol, let's parse a placeholder
            bool minus_sign = false;
            auto produce_location = [&]{
                if( !_invert_flag ) {
                    if( !minus_sign )
                        return ExternalToolsParameters::Location::Source;
                    else
                        return ExternalToolsParameters::Location::Target;
                }
                else {
                    if( !minus_sign )
                        return ExternalToolsParameters::Location::Left;
                    else
                        return ExternalToolsParameters::Location::Right;
                }
            };
            bool list_flag = false;
            int number = 0;
            string prompt_text;
            unsigned long position = r.location + 1;
            do {
                if( position >= _range.location + _range.length ) {
                    if( minus_sign )
                        return make_pair( any(InterpretInvertFlag()), 2 ); // treat this situation as "%-" inversion flag
                    return make_pair( any(), 0 ); // malformed string, aborting
                }
                
                const auto c = [_source characterAtIndex:position];
                if( c >= '0' && c <= '9'  ) {
                    number = number*10 + c - '0';
                }
                else if( c == '"' ) {
                    const auto right_quote = [_source rangeOfCharacterFromSet:quote options:0 range:NSMakeRange(position+1, _source.length - (position + 1))];
                    if( right_quote.location != NSNotFound ) {
                        NSString *substr = [_source substringWithRange:NSMakeRange(position+1, right_quote.location-position-1)];
                        prompt_text = substr.UTF8String;
                        position = right_quote.location + 1;
                        continue;
                    }
                    else
                        return make_pair( any(), 0 ); // malformed string, aborting
                }
                else if( c == '%' && position == r.location + 1 ) {
                    ExternalToolsParameters::UserDefined result;
                    result.text = "%";
                    return make_pair( any(move(result)), position - _range.location + 1 );
                }
                else switch( c ) {
                    case '-': {
                        if( minus_sign == true )
                            return make_pair( any(), 0 ); // already up - malformed string, aborting
                        minus_sign = true;
                        break;
                    }
                    case 'L': {
                        if( list_flag == true )
                            return make_pair( any(), 0 ); // already up - malformed string, aborting
                        list_flag = true;
                        break;
                    }
                    case '?': { // terminal - ask user for parameter
                        if( minus_sign != false || number != 0 || list_flag != false )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::EnterValue result;
                        result.name = move(prompt_text);
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'r': { // terminal - directory path
                        if( number != 0 || !prompt_text.empty() || list_flag != false )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::CurrentItem result;
                        result.what = ExternalToolsParameters::FileInfo::DirectoryPath;
                        result.location = produce_location();
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'p': { // terminal - current path
                        if( number != 0 || !prompt_text.empty() || list_flag != false )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::CurrentItem result;
                        result.what = ExternalToolsParameters::FileInfo::Path;
                        result.location = produce_location();
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'f': { // terminal - current filename
                        if( number != 0 || !prompt_text.empty() || list_flag != false )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::CurrentItem result;
                        result.what = ExternalToolsParameters::FileInfo::Filename;
                        result.location = produce_location();
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'n': { // terminal - current filename w/o ext
                        if( number != 0 || !prompt_text.empty() || list_flag != false )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::CurrentItem result;
                        result.what = ExternalToolsParameters::FileInfo::FilenameWithoutExtension;
                        result.location = produce_location();
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'e': { // terminal - current filename extension
                        if( number != 0 || !prompt_text.empty() || list_flag != false )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::CurrentItem result;
                        result.what = ExternalToolsParameters::FileInfo::FileExtension;
                        result.location = produce_location();
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'F': { // terminal - selected filenames
                        if( !prompt_text.empty() )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::SelectedItems result;
                        result.what = ExternalToolsParameters::FileInfo::Filename;
                        result.location = produce_location();
                        result.as_parameters = !list_flag;
                        result.max = number;
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'P': { // terminal - selected filepaths
                        if( !prompt_text.empty() )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        ExternalToolsParameters::SelectedItems result;
                        result.what = ExternalToolsParameters::FileInfo::Path;
                        result.location = produce_location();
                        result.as_parameters = !list_flag;
                        result.max = number;
                        return make_pair( any(move(result)), position - _range.location + 1 );
                    }
                    case 'T': {
                        if( minus_sign != false || list_flag != false != !prompt_text.empty() )
                            return make_pair( any(), 0 ); // malformed string, aborting
                        SetMaximumFilesFlag limit;
                        limit.maximum = number >= 0 ? number : 0;
                        return make_pair( any(limit), position - _range.location + 1 );
                    }
                    default: {
                        if( minus_sign )
                            return make_pair( any(InterpretInvertFlag()), 2 ); // treat this situation as "%-" inversion flag
                        else
                            return make_pair( any(), 0 ); // malformed string, aborting
                    }
                }
                position++;
            } while(true);
        }
        else {
            // % symbol is somewhere next
            ExternalToolsParameters::UserDefined result;
            result.text = [_source substringWithRange:NSMakeRange(_range.location, r.location - _range.location)].UTF8String;
            return make_pair( any(move(result)), r.location - _range.location );
        }
    }
    else {
        // there's no % in the string - can return the whole tail at one
        ExternalToolsParameters::UserDefined result;
        result.text = [_source substringFromIndex:_range.location].UTF8String;
        return make_pair( any(move(result)), _range.length );
    }
    return make_pair( any(), 0 );
}

ExternalToolsParameters ExternalToolsParametersParser::Parse( const string &_source, function<void(string)> _parse_error )
{
    ExternalToolsParameters result;
    
    NSString *source = [NSString stringWithUTF8StdString:_source];
    bool invert_flag = false;
    const auto length = source.length;
    auto range = NSMakeRange(0, length);
    while( range.length > 0 ) {
        auto res = Eat( source, range, invert_flag );
        assert( res.second <= range.length );
        if( res.second == 0 ) {
            if( _parse_error ) {
                NSString *left = [source substringFromIndex:range.location];
                string error = "Parse error nearby following symbols: \""s + left.UTF8String + "\"";
                _parse_error( move(error) );
            }
            break;
        }
        
        range = NSMakeRange(range.location + res.second, length - range.location - res.second);
        
        if( res.first.type() == typeid(ExternalToolsParameters::UserDefined) ) {
            auto &v = any_cast<ExternalToolsParameters::UserDefined&>(res.first);
            result.InsertUserDefinedText( move(v) );
        }
        else if( res.first.type() == typeid(ExternalToolsParameters::EnterValue) ) {
            auto &v = any_cast<ExternalToolsParameters::EnterValue&>(res.first);
            result.InsertValueRequirement( move(v) );
        }
        else if( res.first.type() == typeid(ExternalToolsParameters::CurrentItem) ) {
            auto &v = any_cast<ExternalToolsParameters::CurrentItem&>(res.first);
            result.InsertCurrentItem( move(v) );
        }
        else if( res.first.type() == typeid(ExternalToolsParameters::SelectedItems) ) {
            auto &v = any_cast<ExternalToolsParameters::SelectedItems&>(res.first);
            result.InsertSelectedItem( move(v) );
        }
        else if( res.first.type() == typeid(InterpretInvertFlag) ) {
            invert_flag = !invert_flag;
        }
        else if( res.first.type() == typeid(SetMaximumFilesFlag) ) {
            auto v = any_cast<SetMaximumFilesFlag>(res.first);
            result.m_MaximumTotalFiles = v.maximum;
        }
    }
    
    return result;
}

static const auto g_TitleKey = "title";
static const auto g_PathKey = "path";
static const auto g_ParametersKey = "parameters";
static const auto g_ShortcutKey = "shortcut";

static GenericConfig::ConfigValue SaveTool( const ExternalTool& _et )
{
    using namespace rapidjson;
    GenericConfig::ConfigValue v(kObjectType);
    
    v.AddMember( MakeStandaloneString(g_TitleKey), MakeStandaloneString(_et.m_Title), g_CrtAllocator );
    v.AddMember( MakeStandaloneString(g_PathKey), MakeStandaloneString(_et.m_ExecutablePath), g_CrtAllocator );
    v.AddMember( MakeStandaloneString(g_ParametersKey), MakeStandaloneString(_et.m_Parameters), g_CrtAllocator );
    v.AddMember( MakeStandaloneString(g_ShortcutKey), MakeStandaloneString(_et.m_Shorcut.ToPersString()), g_CrtAllocator );
    
    return v;
}

static optional<ExternalTool> LoadTool( const GenericConfig::ConfigValue& _from )
{
    using namespace rapidjson;
    if( !_from.IsObject() )
        return nullopt;
    
    ExternalTool et;
    if( _from.HasMember(g_PathKey) && _from[g_PathKey].IsString() )
        et.m_ExecutablePath = _from[g_PathKey].GetString();
    else
        return nullopt;

    if( _from.HasMember(g_TitleKey) && _from[g_TitleKey].IsString() )
        et.m_Title = _from[g_TitleKey].GetString();

    if( _from.HasMember(g_ParametersKey) && _from[g_ParametersKey].IsString() )
        et.m_Parameters = _from[g_ParametersKey].GetString();

    if( _from.HasMember(g_ShortcutKey) && _from[g_ShortcutKey].IsString() )
        et.m_Shorcut = ActionShortcut( _from[g_ShortcutKey].GetString() );
    
    return et;
}

ExternalToolsStorage::ExternalToolsStorage(const char*_config_path):
    m_ConfigPath(_config_path)
{
    LoadToolsFromConfig();
  
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(_config_path, [=]{
        LoadToolsFromConfig();
        FireObservers();
    }) );
}

void ExternalToolsStorage::LoadToolsFromConfig()
{
    auto tools = GlobalConfig().Get(m_ConfigPath);
    if( !tools.IsArray())
        return;
    
    LOCK_GUARD(m_ToolsLock) {
        m_Tools.clear();
        for( auto i = tools.Begin(), e = tools.End(); i != e; ++i )
            if( auto et = LoadTool( *i ) )
                m_Tools.emplace_back( make_shared<ExternalTool>(move(*et)) );
    }
}

size_t ExternalToolsStorage::ToolsCount() const
{
    lock_guard<spinlock> guard(m_ToolsLock);
    return m_Tools.size();
}

shared_ptr<const ExternalTool> ExternalToolsStorage::GetTool(size_t _no) const
{
    lock_guard<spinlock> guard(m_ToolsLock);
    return _no < m_Tools.size() ? m_Tools[_no] : nullptr;
}

vector<shared_ptr<const ExternalTool>> ExternalToolsStorage::GetAllTools() const
{
    lock_guard<spinlock> guard(m_ToolsLock);
    return m_Tools;
}

shared_ptr<ExternalToolsStorage::ChangesObserver> ExternalToolsStorage::ObserveChanges( function<void()> _callback )
{
    shared_ptr<ExternalToolsStorage::ChangesObserver> observer;
    LOCK_GUARD(m_ObserversLock) {
        auto o = make_shared<ExternalToolsStorage::ChangesObserver>();
        o->callback = _callback;
        m_Observers.emplace_back( o );
        observer = o;
    }
    return observer;
}

void ExternalToolsStorage::FireObservers()
{
    LOCK_GUARD(m_ObserversLock) {
        for( auto &w: m_Observers )
            if( auto s = w.lock() )
                if( s->enabled && s->callback )
                    s->callback();
    }
}