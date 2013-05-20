//
//  MainWindowController.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PanelView.h"
#import "PanelData.h"
#import "MainWndGoToButton.h"
#import "ApplicationSkins.h"

@class OperationsController;

@interface MainWindowController : NSWindowController <NSWindowDelegate>

enum ActiveState
{
    StateLeftPanel,
    StateRightPanel
    // many more will be here
};

@property OperationsController *OperationsController;

// Window NIB outlets
@property (strong) IBOutlet MainWndGoToButton *LeftPanelGoToButton;
@property (strong) IBOutlet MainWndGoToButton *RightPanelGoToButton;
@property (weak) IBOutlet NSView *OpSummaryBox;
@property (weak) IBOutlet NSBox *SheetAnchorLine;
@property (strong) IBOutlet NSProgressIndicator *LeftPanelSpinningIndicator;
@property (strong) IBOutlet NSProgressIndicator *RightPanelSpinningIndicator;

// Window NIB actions
- (IBAction)LeftPanelGoToButtonAction:(id)sender;
- (IBAction)RightPanelGoToButtonAction:(id)sender;

// Menu and HK actions
- (IBAction)ToggleShortViewMode:(id)sender;
- (IBAction)ToggleMediumViewMode:(id)sender;
- (IBAction)ToggleFullViewMode:(id)sender;
- (IBAction)ToggleWideViewMode:(id)sender;
- (IBAction)ToggleSortByName:(id)sender;
- (IBAction)ToggleSortByExt:(id)sender;
- (IBAction)ToggleSortByMTime:(id)sender;
- (IBAction)ToggleSortBySize:(id)sender;
- (IBAction)ToggleSortByBTime:(id)sender;
- (IBAction)ToggleViewHiddenFiles:(id)sender;
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender;
- (IBAction)LeftPanelGoto:(id)sender;
- (IBAction)RightPanelGoto:(id)sender;
- (IBAction)OnSyncPanels:(id)sender;
- (IBAction)OnSwapPanels:(id)sender;
- (IBAction)OnRefreshPanel:(id)sender;
- (IBAction)OnFileAttributes:(id)sender;
- (IBAction)OnDetailedVolumeInformation:(id)sender;
- (IBAction)OnDeleteCommand:(id)sender;
- (IBAction)OnCreateDirectoryCommand:(id)sender;
- (IBAction)OnFileViewCommand:(id)sender;
- (IBAction)OnFileCopyCommand:(id)sender;
- (IBAction)OnFileCopyAsCommand:(id)sender;
- (IBAction)OnFileRenameMoveCommand:(id)sender;
- (IBAction)OnFileRenameMoveAsCommand:(id)sender;
- (IBAction)OnPreferencesCommand:(id)sender;

- (IBAction)OnFileBigFileViewCommand:(id)sender;

- (void)ActivatePanelByController:(PanelController *)controller;
- (void)ActivatePanel:(ActiveState)_state;

// this method will be called by App in all MainWindowControllers with same params
- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket;

- (void)SavePanelPaths;
- (void)PanelPathChanged:(PanelController*)_panel;

- (void)ApplySkin:(ApplicationSkin)_skin;

- (void)RevealEntries:(FlexChainedStringsChunk*)_entries inPath:(const char*)_path;

@end
