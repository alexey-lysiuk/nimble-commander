//
//  VFSGenericMemReadOnlyFile.h
//  Files
//
//  Created by Michael G. Kazakov on 27.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "VFSFile.h"

class VFSGenericMemReadOnlyFile : public VFSFile
{
public:
    VFSGenericMemReadOnlyFile(const char* _relative_path,
                              shared_ptr<VFSHost> _host,
                              const void *_memory,
                              uint64_t _mem_size);
    
    
    virtual int     Open(int _open_flags, VFSCancelChecker _cancel_checker) override;
    virtual bool    IsOpened() const override;
    virtual int     Close() override;
    
    virtual ssize_t Read(void *_buf, size_t _size) override;
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size) override;
    virtual ReadParadigm GetReadParadigm() const override;
    virtual off_t Seek(off_t _off, int _basis) override;
    virtual ssize_t Pos() const override;
    virtual ssize_t Size() const override;
    virtual bool Eof() const override;

private:
    const void * const  m_Mem;
    const uint64_t      m_Size;
    ssize_t             m_Pos = 0;
    bool                m_Opened = false;
};