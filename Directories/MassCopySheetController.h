//
//  MassCopySheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^MassCopySheetCompletionHandler)(int result);

@interface MassCopySheetController : NSWindowController
@property (strong) IBOutlet NSButton *CopyButton;
@property (strong) IBOutlet NSTextField *TextField;
- (IBAction)OnCopy:(id)sender;
- (IBAction)OnCancel:(id)sender;

- (void)ShowSheet:(NSWindow *)_window initpath:(NSString*)_path handler:(MassCopySheetCompletionHandler)_handler;

@end
