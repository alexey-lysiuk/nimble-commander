//
//  FindFileSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 12.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"
#import "SheetController.h"

struct FindFilesSheetControllerFoundItem
{
    string filename;
    string dir_path;
    string full_filename;
    VFSStat st;
};

@interface FindFilesSheetController : SheetController<NSTableViewDataSource, NSTableViewDelegate>

- (IBAction)OnClose:(id)sender;
- (IBAction)OnSearch:(id)sender;

@property (nonatomic) VFSHostPtr host;
@property (nonatomic) string path;

@property (strong) IBOutlet NSButton *CloseButton;
@property (strong) IBOutlet NSButton *SearchButton;
@property (strong) IBOutlet NSTextField *MaskTextField;
@property (strong) IBOutlet NSTextField *ContainingTextField;
@property (strong) IBOutlet NSTableView *TableView;
@property (strong) IBOutlet NSButton *CaseSensitiveButton;
@property (strong) IBOutlet NSButton *WholePhraseButton;

@property NSMutableArray *FoundItems;
@property (strong) IBOutlet NSArrayController *ArrayController;
@property (strong) IBOutlet NSPopUpButton *SizeRelationPopUp;
@property (strong) IBOutlet NSTextField *SizeTextField;
@property (strong) IBOutlet NSPopUpButton *SizeMetricPopUp;
@property (strong) IBOutlet NSButton *SearchForDirsButton;
@property (strong) IBOutlet NSButton *SearchInSubDirsButton;
@property (strong) IBOutlet NSPopUpButton *EncodingsPopUp;

- (FindFilesSheetControllerFoundItem*) SelectedItem; // may be nullptr

@end
