//
//  WorkspaceIconsCache.mm
//  Files
//
//  Created by Michael G. Kazakov on 25.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include "WorkspaceIconsCache.h"

WorkspaceIconsCache& WorkspaceIconsCache::Instance()
{
    static auto inst = make_unique<WorkspaceIconsCache>();
    return *inst;
}

NSImage *WorkspaceIconsCache::IconIfHas(const string &_filename)
{
    shared_lock<shared_timed_mutex> lock(m_ItemsLock);
    
    auto i = m_Items.find(_filename);
    if(i != end(m_Items))
        return (*i).second.image;
    return nil;
}

static NSImage *BuildRep(const string &_filename)
{
    NSImage *result = nil;
    CFStringRef item_path = CFStringCreateWithUTF8StdStringNoCopy(_filename);
    result = [NSWorkspace.sharedWorkspace iconForFile: (__bridge NSString*)item_path];
    CFRelease(item_path);
    return result;
}

NSImage *WorkspaceIconsCache::ProduceIcon(const string &_filename)
{
    m_ItemsLock.lock_shared();
    
    NSImage *result = nil;
    
    auto i = m_Items.find(_filename);
    if(i != end(m_Items))
    { // check what do we have in a cache
        Info &info = i->second;
        
        // check if cache is up-to-date
        bool is_uptodate = false;
        struct stat st;
        if(stat(_filename.c_str(), &st) == 0) {
            if( i->second.file_size == st.st_size &&
               i->second.mtime == st.st_mtime &&
               i->second.mode == st.st_mode) {
                is_uptodate = true;
            }
            else if( NSImage *img = BuildRep(_filename) ) {
                info.image = img;
                info.file_size = st.st_size;
                info.mtime = st.st_mtime;
                info.mode = st.st_mode;
                is_uptodate = true;
            }
        }
        
        if(is_uptodate) {
            result = info.image;
            m_ItemsLock.unlock_shared();
            
            // make this item MRU
            lock_guard<mutex> mru_lock(m_MRULock);
            m_MRU.erase(find(begin(m_MRU), end(m_MRU), i));
            m_MRU.emplace_back(i);
        }
        else {
            m_ItemsLock.unlock_shared();
        }
    }
    else
    { // build from scratch
        m_ItemsLock.unlock_shared();
        
        result = BuildRep( _filename ); // img may be nil - it's ok
        
        struct stat st;
        if(stat(_filename.c_str(), &st) == 0) // but file should exist and be accessible
        { // put in a cache
            
            lock_guard<mutex> mru_lock(m_MRULock);
            lock_guard<shared_timed_mutex> items_lock(m_ItemsLock);
            
            while(m_MRU.size() >= m_CacheSize)
            { // wipe out old ones if cache is too fat
                m_Items.erase(m_MRU.front());
                m_MRU.pop_front();
            }
            
            auto emp = m_Items.emplace(_filename, Info());
            if(emp.second)
            {
                auto it = emp.first;
                Info &info = it->second;
                info.image = result;
                info.file_size = st.st_size;
                info.mtime = st.st_mtime;
                info.mode = st.st_mode;
                
                m_MRU.emplace_back(it);
            }
        }
    }
    return result;
}