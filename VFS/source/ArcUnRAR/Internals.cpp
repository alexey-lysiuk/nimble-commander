//
//  VFSArchiveUnRARInternals.cpp
//  Files
//
//  Created by Michael G. Kazakov on 06.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "Internals.h"
#include <VFS/VFSError.h>

namespace nc::vfs::unrar {

int VFSArchiveUnRARErrorToVFSError(int _rar_error)
{
    switch (_rar_error) {
        case ERAR_SUCCESS:          return VFSError::Ok;
        case ERAR_BAD_DATA:         return VFSError::UnRARBadData;
        case ERAR_BAD_ARCHIVE:      return VFSError::UnRARBadArchive;
        case ERAR_UNKNOWN_FORMAT:   return VFSError::UnRARUnknownFormat;
        case ERAR_MISSING_PASSWORD: return VFSError::UnRARMissingPassword;
        case ERAR_BAD_PASSWORD:     return VFSError::UnRARBadPassword;
    }
    return VFSError::GenericError;
}

SeekCache::~SeekCache()
{
    if(rar_handle)
        RARCloseArchive(rar_handle);
}

}