#include "PanelDataOptionsPersistence.h"
#include "PanelData.h"
#include "PanelDataSortMode.h"

static const auto g_RestorationSepDirsKey = "separateDirectories";
static const auto g_RestorationExtlessDirsKey = "extensionlessDirectories";
static const auto g_RestorationShowHiddenKey = "showHidden";
static const auto g_RestorationCaseSensKey = "caseSensitive";
static const auto g_RestorationNumericSortKey = "numericSort";
static const auto g_RestorationSortModeKey = "sortMode";

namespace panel {

DataOptionsExporter::DataOptionsExporter(const PanelData &_data):
    m_Data(_data)
{
}

rapidjson::StandaloneValue DataOptionsExporter::Export() const
{
    rapidjson::StandaloneValue json(rapidjson::kObjectType);
    auto add_bool = [&](const char*_name, bool _v) {
        json.AddMember(rapidjson::StandaloneValue(_name, rapidjson::g_CrtAllocator),
                       rapidjson::StandaloneValue(_v), rapidjson::g_CrtAllocator); };
    auto add_int = [&](const char*_name, int _v) {
        json.AddMember(rapidjson::StandaloneValue(_name, rapidjson::g_CrtAllocator),
                       rapidjson::StandaloneValue(_v), rapidjson::g_CrtAllocator); };
    auto sort_mode = m_Data.SortMode();
    add_bool(g_RestorationSepDirsKey, sort_mode.sep_dirs);
    add_bool(g_RestorationExtlessDirsKey, sort_mode.extensionless_dirs);
    add_bool(g_RestorationShowHiddenKey, m_Data.HardFiltering().show_hidden);
    add_bool(g_RestorationCaseSensKey, sort_mode.case_sens);
    add_bool(g_RestorationNumericSortKey, sort_mode.numeric_sort);
    add_int(g_RestorationSortModeKey, (int)sort_mode.sort);
    return json;
}

DataOptionsImporter::DataOptionsImporter(PanelData &_data):
    m_Data(_data)
{
}
    
void DataOptionsImporter::Import(const rapidjson::StandaloneValue& _options)
{
  using namespace rapidjson;
    if( !_options.IsObject() )
        return;
    
    auto sort_mode = m_Data.SortMode();
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationSepDirsKey) )
        sort_mode.sep_dirs = *v;
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationExtlessDirsKey) )
        sort_mode.extensionless_dirs = *v;
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationCaseSensKey) )
        sort_mode.case_sens = *v;
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationNumericSortKey) )
        sort_mode.numeric_sort = *v;
    if( auto v = GetOptionalIntFromObject(_options, g_RestorationSortModeKey)  )
        if( auto mode = (PanelDataSortMode::Mode)*v; PanelDataSortMode::validate(mode) )
            sort_mode.sort = mode;
    m_Data.SetSortMode(sort_mode);
    
    auto hard_filtering = m_Data.HardFiltering();
    if( auto v = GetOptionalBoolFromObject(_options, g_RestorationShowHiddenKey) )
        hard_filtering.show_hidden = *v;
    m_Data.SetHardFiltering(hard_filtering);
}

}
