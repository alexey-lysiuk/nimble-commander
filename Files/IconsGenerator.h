//
//  IconsGenerator.h
//  Files
//
//  Created by Michael G. Kazakov on 04.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include "DispatchQueue.h"
#include "vfs/VFS.h"

#include "PanelData.h"

class IconsGenerator
{
public:
    enum class IconMode
    {
        Generic         = 0,
        Icons           = 1,
        Thumbnails      = 2,
        IconModesCount  = 3
    };
        
    IconsGenerator();
    ~IconsGenerator();
    
    void SetUpdateCallback( function<void()> _callback ); // callback will be executed in main thread
    void SetIconMode(IconMode _mode);
    void SetIconSize(int _size);
    int IconSize() const { return m_IconSize; }
    
    NSImageRep *ImageFor(const VFSListingItem &_item, PanelVolatileData &_item_vd);
    void Flush(); // should be called on every directory changes thus loosing generated icons' ID
    
    
private:
    enum {MaxIcons = 65535,
        MaxFileSizeForThumbnailNative = 256*1024*1024,
        MaxFileSizeForThumbnailNonNative = 1*1024*1024 // ?
    };

    struct IconStorage
    {
        uint64_t    file_size;
        time_t      mtime;
        NSImageRep *generic;   // just folder or document icon
        NSImageRep *filetype;  // icon generated from file's extension or taken from a bundle
        NSImageRep *thumbnail; // the best - thumbnail generated from file's content
        NSImageRep *Any() const;
    };
    
    struct BuildRequest
    {
        unsigned long generation;
        uint64_t    file_size;
        mode_t      unix_mode;
        time_t      mtime;
        string      extension;
        string      relative_path;
        VFSHostPtr  host;
        NSImageRep *filetype;  // icon generated from file's extension or taken from a bundle
        NSImageRep *thumbnail; // the best - thumbnail generated from file's content
    };
    
    struct BuildResult
    {
        NSImageRep *filetype;
        NSImageRep *thumbnail;
    };
    
    void BuildGenericIcons();
    optional<BuildResult> Runner(const BuildRequest &_req);
    IconsGenerator(const IconsGenerator&) = delete;
    void operator=(const IconsGenerator&) = delete;
    
    
    vector<IconStorage>     m_Icons;
    int                     m_IconSize = 16;
    IconMode                m_IconsMode = IconMode::Thumbnails;

    shared_ptr<atomic_ulong>m_GenerationSh = make_shared<atomic_ulong>(0);
    atomic_ulong           &m_Generation = *m_GenerationSh;
    DispatchGroup           m_WorkGroup{DispatchGroup::Low};
    function<void()>        m_UpdateCallback;
    
    NSImageRep             *m_GenericFileIcon;
    NSImageRep             *m_GenericFolderIcon;
    NSBitmapImageRep       *m_GenericFileIconBitmap;
    NSBitmapImageRep       *m_GenericFolderIconBitmap;

    mutex                   m_ExtensionIconsCacheLock;
    map<string,NSImageRep*> m_ExtensionIconsCache;
};
