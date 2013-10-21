//
//  VFSFile.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>
#import <memory>

#import "VFSError.h"

class VFSHost;

class VFSFile : public std::enable_shared_from_this<VFSFile>
{
public:
    enum class ReadParadigm {
        /**
         * the best possible variant - can read a block of data from a random offset. Seeking is also possible
         */
        Random      = 3,

        /**
         * classic I/O - can seek and sequentially read requested data
         */
        Seek        = 2,
        
        /**
         * the worst variant - can only read file sequentially from the beginning
         * (http downloading without resuming for example)
         * should also support Skip operation, which can be not cheap
         */
        Sequential  = 1,

        /**
         * this file cannot be read
         */
        NoRead      = 0
    };
    
    VFSFile(const char* _relative_path, std::shared_ptr<VFSHost> _host);
    virtual ~VFSFile();

    enum {
        OF_Read,
        OF_Write,
        OF_ShLock, // not implemented
        OF_ExLock  // not implemented
    };
    virtual int     Open(int _open_flags);
    virtual bool    IsOpened() const;
    virtual int     Close();

    virtual ReadParadigm GetReadParadigm() const;
    virtual ssize_t Read(void *_buf, size_t _size);
    
    /**
     * ReadAt is available only on Random level
     * will not move any file pointers
     * read up to _size bytes, may return less
     */
    virtual ssize_t ReadAt(off_t _pos, void *_buf, size_t _size);
    
    enum {
        Seek_Set = 0,
        Seek_Cur = 1,
        Seek_End = 2
    };
    
    /**
     * Seek() is available if Read paradigm is Seek or above
     */
    virtual off_t Seek(off_t _off, int _basis);
    
    /**
     * Pos() should always be available, except of dummy VFSFile class, which returns VFSError::NotSupported
     */
    virtual ssize_t Pos() const;

    /**
     * Size() should always be available, except of dummy VFSFile class, which returns VFSError::NotSupported
     */
    virtual ssize_t Size() const;

    /**
     * Eof() should always be available, return true on not-valid file state
     */
    virtual bool Eof() const;
    
    /**
     * XAttrCount() should be always available, returning 0 on non-supported case
     */
    virtual unsigned XAttrCount() const;
    
    /**
     * XAttrIterateNames() will call block with every xattr name for this file while handler returns true
     */
    virtual void XAttrIterateNames(
                                   bool (^_handler)(const char* _xattr_name) // return true for allowing iteration, false to stop it
                                   ) const;
    
    /**
     * XAttrGet copies an extended attribute value named _xattr_name into buffer _buffer limited with _buf_size.
     * If requested xattr was not found this function returns VFSError::NotFound.
     * If _buffer is NULL and requested xattr was found then size of this xattr is returned.
     * If _buf_size is smaller than required buffer for _xattr_name then data will be truncated and _buf_size will be returned.
     * Generally this function returns amount of bytes copied (note that valid xattr value can be 0 bytes long).
     */
    virtual ssize_t XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const;
    
    /**
     * Clone() returns an object of same type with same parent host and relative path
     * Open status and file positions are not shared
     * Can return null pointer in some cases
     */
    virtual std::shared_ptr<VFSFile> Clone() const;

    /**
     * ComposeFullHostsPath() relies solely on RelativePath() and Host()
     */
    void ComposeFullHostsPath(char *_buf) const;
    
    // sugar wrappers for Cocoa APIs
#ifdef __OBJC__
    /**
     * ReadFile() return full file content in NSData object or nil
     */
    NSData *ReadFile();
#endif
    
    inline std::shared_ptr<VFSFile> SharedPtr() { return shared_from_this(); }
    inline std::shared_ptr<const VFSFile> SharedPtr() const { return shared_from_this(); }
    const char* RelativePath() const;
    std::shared_ptr<VFSHost> Host() const;
private:
    std::string m_RelativePath;
    std::shared_ptr<VFSHost> m_Host;
    
    // forbid copying
    VFSFile(const VFSFile&) = delete;
    void operator=(const VFSFile&) = delete;
};

