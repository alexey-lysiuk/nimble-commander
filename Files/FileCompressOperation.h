//
//  FileCompressOperation.h
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"
#import "Operation.h"
#import "OperationDialogAlert.h"

@interface FileCompressOperation : Operation

- (id)initWithFiles:(vector<VFSFlexibleListingItem>)_src_files
            dstroot:(const string&)_dst_root
             dstvfs:(VFSHostPtr)_dst_vfs;


- (OperationDialogAlert *)OnCantAccessSourceItem:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnCantAccessSourceDir:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnReadError:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnWriteError:(NSError*)_error;
@end
