//
//  VFSArchiveUnRARHost.h
//  Files
//
//  Created by Michael G. Kazakov on 02.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/DispatchQueue.h>
#include "../VFSHost.h"
#include "../VFSFile.h"

struct VFSArchiveUnRAREntry;
struct VFSArchiveUnRARDirectory;
struct VFSArchiveUnRARSeekCache;

class VFSArchiveUnRARHost : public VFSHost
{
public:
    static const char *Tag;
    VFSArchiveUnRARHost(const string &_path);
    VFSArchiveUnRARHost(const VFSHostPtr &_parent, const VFSConfiguration &_config);
    ~VFSArchiveUnRARHost();
    
    virtual bool IsImmutableFS() const noexcept override;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    

    static bool IsRarArchive(const char *_archive_native_path);
    
    
    // core VFSHost methods
    virtual int FetchFlexibleListing(const char *_path,
                                     shared_ptr<VFSListing> &_target,
                                     int _flags,
                                     VFSCancelChecker _cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        function<bool(const VFSDirEnt &_dirent)> _handler) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker) override;
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     VFSCancelChecker _cancel_checker) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;
    
    
    virtual bool ShouldProduceThumbnails() const override;
    
    
    // internal UnRAR stuff
    
    /**
     * Return zero on not found.
     */
    uint32_t ItemUUID(const string& _filename) const;

    /**
     * Returns UUID of a last item in archive.
     */
    uint32_t LastItemUUID() const;

    /**
     * Return nullptr on not found.
     */
    const VFSArchiveUnRAREntry *FindEntry(const string &_full_path) const;
    
    /**
     * Inserts opened rar handle into host's seek cache.
     */
    void CommitSeekCache(unique_ptr<VFSArchiveUnRARSeekCache> _sc);
    
    /**
     * if there're no appropriate caches, host will try to open a new RAR handle.
     * If can't satisfy this call - zero ptr is returned.
     */
    unique_ptr<VFSArchiveUnRARSeekCache> SeekCache(uint32_t _requested_item);
    
    
    VFS_DECLARE_SHARED_PTR(VFSArchiveUnRARHost);
private:
    int DoInit(); // flags will be added later
    
    int InitialReadFileList(void *_rar_handle);

    VFSArchiveUnRARDirectory *FindOrBuildDirectory(const string& _path_with_tr_sl);
    const VFSArchiveUnRARDirectory *FindDirectory(const string& _path) const;
    
    map<string, VFSArchiveUnRARDirectory>   m_PathToDir; // path to dir with trailing slash -> directory contents
    uint32_t                                m_LastItemUID = 0;
    list<unique_ptr<VFSArchiveUnRARSeekCache>> m_SeekCaches;
    dispatch_queue_t                           m_SeekCacheControl;
    uint64_t                                m_PackedItemsSize = 0;
    uint64_t                                m_UnpackedItemsSize = 0;
    bool                                    m_IsSolidArchive = false;
    struct stat                             m_ArchiveFileStat;
    VFSConfiguration                        m_Configuration;

    // TODO: int m_FD for exclusive lock?
};
