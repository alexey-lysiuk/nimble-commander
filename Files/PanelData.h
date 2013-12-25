#pragma once
#include <vector>
#include "DispatchQueue.h"
#include "VFS.h"

struct FlexChainedStringsChunk;

struct PanelSortMode
{
    enum Mode
    {
        SortNoSort      = 0x000,
        SortByName      = 0x001,
        SortByNameRev   = 0x002,
        SortByExt       = SortByName    << 2,
        SortByExtRev    = SortByNameRev << 2,
        SortBySize      = SortByName    << 4,
        SortBySizeRev   = SortByNameRev << 4,
        SortByMTime     = SortByName    << 6,
        SortByMTimeRev  = SortByNameRev << 6,
        SortByBTime     = SortByName    << 8,
        SortByBTimeRev  = SortByNameRev << 8,
        // for internal usage, seems to be meaningless for human reading (sort by internal UTF8 representation)
        SortByRawCName  = 0xF0000000,
        SortByNameMask  = SortByName | SortByNameRev,
        SortByExtMask   = SortByExt  | SortByExtRev,
        SortBySizeMask  = SortBySize | SortBySizeRev,
        SortByMTimeMask = SortByMTime| SortByMTimeRev,
        SortByBTimeMask = SortByBTime| SortByBTimeRev
    };
    
    Mode sort;
    bool sep_dirs;      // separate directories from files, like win-like
    bool show_hidden;   // shown hidden files (which are: begining with "." or having hidden flag)
    bool case_sens;     // case sensitivity when comparing filenames, ignored on Raw Sorting (SortByRawCName)
    bool numeric_sort;  // try to treat filenames as numbers and use them as compare basis
    
    inline PanelSortMode():
        sort(SortByRawCName),
        sep_dirs(false),
        show_hidden(true),
        case_sens(false),
        numeric_sort(false)
    {}
    
    inline bool isdirect() const
    {
        return sort == SortByName || sort == SortByExt || sort == SortBySize || sort == SortByMTime || sort == SortByBTime;
    }
    inline bool isrevert() const
    {
        return sort == SortByNameRev || sort == SortByExtRev || sort == SortBySizeRev || sort == SortByMTimeRev || sort == SortByBTimeRev;        
    }
    inline bool operator ==(const PanelSortMode& _r) const
    {
        return sort == _r.sort && sep_dirs == _r.sep_dirs && show_hidden == _r.show_hidden && case_sens == _r.case_sens && numeric_sort == _r.numeric_sort;
    }
    inline bool operator !=(const PanelSortMode& _r) const
    {
        return !(*this == _r);
    }
};

/**
 * PanelData actually does the following things:
 * - sorting data
 * - handling reloading with preserving of custom entries data
 * - searching
 * - paths accessing
 * - custom information setting/getting
 * - statistics
 */
class PanelData
{
public:
    typedef vector<unsigned> DirSortIndT; // value in this array is an index for VFSListing
    
    PanelData();
    
    // these methods should be called by a controller, since some view's props have to be updated
    // PanelData is solely sync class - it does not give a fuck about concurrency,
    // any parallelism should be done by callers (i.e. controller)
    // just like Metallica:
    void Load(shared_ptr<VFSListing> _listing);
    void ReLoad(shared_ptr<VFSListing> _listing);

    shared_ptr<VFSHost>     Host() const;
    shared_ptr<VFSListing>  Listing() const;
    
    const VFSListing&       DirectoryEntries() const;
    const DirSortIndT&      SortedDirectoryEntries() const;
    const VFSListingItem&   EntryAtRawPosition(int _pos) const;
    chained_strings         StringsFromSelectedEntries() const;

    /**
     * will redirect ".." upwards
     */
    string FullPathForEntry(int _raw_index) const;
    
    /**
     * Converts sorted index into raw index. Returns -1 on any errors.
     */
    int RawIndexForSortIndex(int _index) const;
    
    /**
     * Performs a binary case-sensivitive search.
     * Return -1 if didn't found.
     * Returning value is in raw land, that is DirectoryEntries[N], not sorted ones.
     */
    int RawIndexForName(const char *_filename) const;
    
    /**
     * return -1 if didn't found.
     * returned value is in sorted indxs land.
     */
    int SortedIndexForName(const char *_filename) const;
    
    /**
     * does bruteforce O(N) search.
     * return -1 if didn't found.
     * _desired_raw_index - raw item index.
     */
    int SortedIndexForRawIndex(int _desired_raw_index) const;
    
    /**
     * return current directory in long variant starting from /
     */
    string DirectoryPathWithoutTrailingSlash() const;

    /**
     * same as DirectoryPathWithoutTrailingSlash() but path will ends with slash
     */
    string DirectoryPathWithTrailingSlash() const;
    
    /**
     * return name of a current directory in a parent directory.
     * returns a zero string for a root dir.
     */
    string DirectoryPathShort() const;
    
    
    // TODO: refactor:    
    void GetDirectoryFullHostsPathWithTrailingSlash(char _buf[MAXPATHLEN*8]) const;
    
    // sorting
    void SetCustomSortMode(PanelSortMode _mode);
    PanelSortMode GetCustomSortMode() const;
    
    /**
     * Fast search support.
     * Searches on sorted elements (which can be less than non-sorted raw listing).
     * _desired_offset is a offset from first suitable element.
     * if _desired_offset causes going out of fitting ranges - the nearest valid element will be returned.
     * return raw index into _ind_out number if any.
     * _range is filled with number of valid suitable entries - 1 (for 1 valid entry _range will be filled with 0).
     * Return true if there're any suitable entries, false otherwise.
     */
    bool FindSuitableEntries(CFStringRef _prefix, unsigned _desired_offset, unsigned *_ind_out, unsigned *_range) const;
    
    // files statistics - notes below
    unsigned long GetTotalBytesInDirectory() const;
    unsigned GetTotalFilesInDirectory() const;
    unsigned GetSelectedItemsCount() const;
    unsigned GetSelectedItemsFilesCount() const;
    unsigned GetSelectedItemsDirectoriesCount() const;
    unsigned long GetSelectedItemsSizeBytes() const;
    
    // manupulation with user flags for directory entries
    void CustomFlagsSelectSorted(int _at_sorted_pos, bool _is_selected);
    void CustomFlagsSelectAllSorted(bool _select);
    int  CustomFlagsSelectAllSortedByMask(NSString* _mask, bool _select, bool _ignore_dirs);
    
    void CustomIconSet(size_t _at_raw_pos, unsigned short _icon_id);
    void CustomIconClearAll();
    
    bool SetCalculatedSizeForDirectory(const char *_entry, unsigned long _size); // return true if changed something
private:    
    PanelData(const PanelData&) = delete;
    void operator=(const PanelData&) = delete;
    
    // this function will erase data from _to, make it size of _form->size(), and fill it with indeces according to _mode
    static void DoSort(shared_ptr<VFSListing> _from, DirSortIndT &_to, PanelSortMode _mode);
    void CustomFlagsSelectRaw(int _at_raw_pos, bool _is_selected);
    void ClearSelectedFlagsFromHiddenElements();
    void UpdateStatictics();    
    
    PanelSortMode HumanSort() const;
    
    // m_Listing container will change every time directory change/reloads,
    // while the following sort-indeces(except for m_EntriesByRawName) will be permanent with it's content changing
    shared_ptr<VFSListing>                  m_Listing;

    DirSortIndT                             m_EntriesByRawName;    // sorted with raw strcmp comparison
    DirSortIndT                             m_EntriesByHumanName;  // sorted with human-reasonable literal sort
    DirSortIndT                             m_EntriesByCustomSort; // custom defined sort
    PanelSortMode                           m_CustomSortMode;
    DispatchGroup                           m_SortExecGroup;
    
    // statistics
    unsigned long                           m_TotalBytesInDirectory = 0; // assuming regular files ONLY!
    unsigned                                m_TotalFilesInDirectory = 0; // NOT DIRECTORIES! only regular files, maybe + symlinks and other stuff
    unsigned long                           m_SelectedItemsSizeBytes = 0;
    unsigned                                m_SelectedItemsCount = 0;
    unsigned                                m_SelectedItemsFilesCount = 0;
    unsigned                                m_SelectedItemsDirectoriesCount = 0;
};
