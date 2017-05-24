#pragma once

class VFSListingItem;

namespace nc::panel::data {

struct ItemVolatileData;

struct ExternalEntryKey
{
    ExternalEntryKey();
    ExternalEntryKey(const VFSListingItem& _item, const ItemVolatileData &_item_vd);
    
    string      name;
    NSString   *display_name;
    string      extension;
    uint64_t    size;
    time_t      mtime;
    time_t      btime;
    time_t      add_time; // -1 means absent
    bool        is_dir;
    bool        is_valid() const noexcept;
};

}