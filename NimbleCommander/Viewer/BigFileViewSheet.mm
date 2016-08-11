//
//  BigFileViewSheet.m
//  Files
//
//  Created by Michael G. Kazakov on 21/09/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "../../Files/GoogleAnalytics.h"
#include "BigFileViewSheet.h"
#include "InternalViewerController.h"

@interface BigFileViewSheet ()

@property (strong) IBOutlet BigFileView *view;

@property (strong) IBOutlet NSPopUpButton *mode;
@property (strong) IBOutlet NSTextField *fileSize;
@property (strong) IBOutlet NSButton *filePos;
@property (strong) IBOutlet NSProgressIndicator *searchIndicator;
@property (strong) IBOutlet NSSearchField *searchField;
@property (strong) IBOutlet NSPopover *settingsPopover;
@property (strong) IBOutlet NSPopUpButton *encodings;
@property (strong) IBOutlet NSButton *wordWrap;

- (IBAction)OnClose:(id)sender;


@end

@implementation BigFileViewSheet
{
    VFSHostPtr              m_VFS;
    string                  m_Path;
    unique_ptr<FileWindow>  m_FileWindow;
    
    InternalViewerController *m_Controller;
}

- (id) initWithFilepath:(string)path
                     at:(VFSHostPtr)vfs
{
    self = [super init];
    if(self) {
        m_VFS = vfs;
        m_Path = path;
        
        m_Controller = [[InternalViewerController alloc] init];
        [m_Controller setFile:path at:vfs];
        
    }
    return self;
}

- (bool) open
{
    assert( !dispatch_is_main_queue() );

    return [m_Controller performBackgroundOpening];
}

- (void)windowDidLoad
{
    self.view.hasBorder = true;
    self.view.wantsLayer = true; // to reduce side-effects of overdrawing by scrolling with touchpad

    m_Controller.view = self.view;
    m_Controller.modePopUp = self.mode;
    m_Controller.fileSizeLabel = self.fileSize;
    m_Controller.positionButton = self.filePos;
    m_Controller.searchField = self.searchField;
    m_Controller.searchProgressIndicator = self.searchIndicator;
    m_Controller.encodingsPopUp = self.encodings;
    m_Controller.wordWrappingCheckBox = self.wordWrap;
    
    [m_Controller show];

    GoogleAnalytics::Instance().PostScreenView("File Viewer Sheet");
}

- (IBAction)OnClose:(id)sender
{
    [m_Controller saveFileState];
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    [self OnClose:self];
}

- (void)markInitialSelection:(CFRange)_selection searchTerm:(string)_request
{
    [m_Controller markSelection:_selection forSearchTerm:_request];
}

- (IBAction)onSettingsClicked:(id)sender
{
    [self.settingsPopover showRelativeToRect:objc_cast<NSButton>(sender).bounds
                                      ofView:objc_cast<NSButton>(sender)
                               preferredEdge:NSMaxYEdge];
}

- (IBAction)performFindPanelAction:(id)sender
{
    [self.window makeFirstResponder:self.searchField];
}

@end
