//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Habanero/CommonPaths.h>
#import "MainWindowFilePanelState+Menu.h"
#import "ActionsShortcutsManager.h"
#import "PanelController.h"
#import "FileDeletionOperation.h"
#import "FilePanelMainSplitView.h"
#import "OperationsController.h"
#import "Common.h"
#import "ExternalEditorInfo.h"
#import "MainWindowController.h"
#import "FileCompressOperation.h"
#import "FileLinkNewSymlinkSheetController.h"
#import "FileLinkAlterSymlinkSheetController.h"
#import "FileLinkNewHardlinkSheetController.h"
#import "FileLinkOperation.h"
#import "FileCopyOperation.h"
#import "MassCopySheetController.h"

static auto g_DefsGeneralShowTabs = @"GeneralShowTabs";

@implementation MainWindowFilePanelState (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.view.swap_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.view.sync_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.file.open_in_opposite_panel")  return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.activePanelView.item.IsDir();
    IF_MENU_TAG("menu.command.compress")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item.IsDotDot();
    IF_MENU_TAG("menu.command.link_create_soft")     return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item.IsDotDot() && self.leftPanelController.vfs->IsNativeFS() && self.rightPanelController.vfs->IsNativeFS();
    IF_MENU_TAG("menu.command.link_create_hard")     return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.leftPanelController.vfs->IsNativeFS() && self.rightPanelController.vfs->IsNativeFS() && !self.activePanelView.item.IsDir();
    IF_MENU_TAG("menu.command.link_edit")            return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && self.activePanelController.vfs->IsNativeFS() && self.activePanelView.item.IsSymlink();
    IF_MENU_TAG("menu.command.copy_to")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.command.copy_as")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.command.move_to")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.command.move_as")              return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.file.close") {
        unsigned tabs = self.currentSideTabsCount;
        if( tabs == 0 ) {
            // in this case (no other adequate responders) - pass validation  up
            NSResponder *resp = self;
            while( (resp = resp.nextResponder) )
                if( [resp respondsToSelector:item.action] && [resp respondsToSelector:@selector(validateMenuItem:)] )
                    return [resp validateMenuItem:item];
            return true;
        }
        item.title = tabs > 1 ? NSLocalizedString(@"Close Tab", "Menu item title for closing current tab") :
                                NSLocalizedString(@"Close Window", "Menu item title for closing current window");
        return true;
    }
    IF_MENU_TAG("menu.file.close_window") {
        item.hidden = self.currentSideTabsCount < 2;
        return true;
    }
    IF_MENU_TAG("menu.window.show_previous_tab")    return self.currentSideTabsCount > 1;
    IF_MENU_TAG("menu.window.show_next_tab")        return self.currentSideTabsCount > 1;
    IF_MENU_TAG("menu.view.show_tabs") {
        item.title = [NSUserDefaults.standardUserDefaults boolForKey:g_DefsGeneralShowTabs] ?
            NSLocalizedString(@"Hide Tab Bar", "Menu item title for hiding tab bar") :
            NSLocalizedString(@"Show Tab Bar", "Menu item title for showing tab bar");
        return true;
    }
    IF_MENU_TAG("menu.view.show_terminal") {
        item.title = NSLocalizedString(@"Show Terminal", "Menu item title for showing terminal");
        return true;
    }
    
    return true;
}

- (IBAction)OnSyncPanels:(id)sender
{
    if(!self.activePanelController || !self.oppositePanelController || m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    [self.oppositePanelController GoToDir:self.activePanelController.currentDirectoryPath
                                      vfs:self.activePanelController.vfs
                             select_entry:""
                                    async:true];
}

- (IBAction)OnSwapPanels:(id)sender
{
    if(m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    swap(m_LeftPanelControllers, m_RightPanelControllers);
    [m_MainSplitView SwapViews];
    
    [self.leftPanelController AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
    [self.rightPanelController AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
    
    [self savePanelsOptions];
}

- (IBAction)OnShowTerminal:(id)sender
{
    string path = "";
    if(self.isPanelActive && self.activePanelController.vfs->IsNativeFS())
        path = self.activePanelController.currentDirectoryPath;
    [(MainWindowController*)self.window.delegate RequestTerminal:path];
}

- (IBAction)OnFileOpenInOppositePanel:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed || !self.activePanelView.item || !self.activePanelView.item.IsDir()) return;
    auto cur = self.activePanelController;
    auto opp = self.oppositePanelController;
    [opp GoToDir:cur.currentFocusedEntryPath
             vfs:cur.vfs
    select_entry:""
           async:true];
}

- (IBAction)OnCompressFiles:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed) return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntries;
    if(entries.empty())
        return;

    FileCompressOperation *op = [[FileCompressOperation alloc] initWithFiles:move(entries)
                                                                     dstroot:self.oppositePanelController.currentDirectoryPath
                                                                      dstvfs:self.oppositePanelController.vfs];
    op.TargetPanel = self.oppositePanelController;
    [m_OperationsController AddOperation:op];
}

- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
    if(!self.activePanelController || !self.oppositePanelController)
        return;
    
    auto item = self.activePanelView.item;
    if(!item)
        return;
    
    string source_path = [self activePanelData]->DirectoryPathWithTrailingSlash();
    if(!item.IsDotDot())
        source_path += item.Name();
    
    string link_path = self.oppositePanelController.currentDirectoryPath;
    
    if(!item.IsDotDot())
        link_path += item.Name();
    else
        link_path += [self activePanelData]->DirectoryPathShort();
    
    FileLinkNewSymlinkSheetController *sheet = [FileLinkNewSymlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcepath:[NSString stringWithUTF8String:source_path.c_str()]
            linkpath:[NSString stringWithUTF8String:link_path.c_str()]
             handler:^(int result){
                 if(result == DialogResult::Create && [[sheet.LinkPath stringValue] length] > 0)
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithNewSymbolinkLink:[[sheet.SourcePath stringValue] fileSystemRepresentation]
                                                                 linkname:[[sheet.LinkPath stringValue] fileSystemRepresentation]
                       ]
                      ];
             }];
}

- (IBAction)OnEditSymbolicLinkCommand:(id)sender
{
    auto data = self.activePanelData;
    auto item = self.activePanelView.item;
    assert(item.IsSymlink());
    
    string link_path = data->DirectoryPathWithTrailingSlash() + item.Name();
    NSString *linkpath = [NSString stringWithUTF8String:link_path.c_str()];
    
    FileLinkAlterSymlinkSheetController *sheet = [FileLinkAlterSymlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcepath:[NSString stringWithUTF8String:item.Symlink()]
            linkname:[NSString stringWithUTF8String:item.Name()]
             handler:^(int _result){
                 if(_result == DialogResult::OK)
                 {
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithAlteringOfSymbolicLink:[[sheet.SourcePath stringValue] fileSystemRepresentation]
                                                                       linkname:[linkpath fileSystemRepresentation]]
                      ];
                 }
             }];
}

- (IBAction)OnCreateHardLinkCommand:(id)sender
{
    auto item = self.activePanelView.item;
    assert(not item.IsDir());
    
    string dir_path = [self activePanelData]->DirectoryPathWithTrailingSlash();
    string src_path = dir_path + item.Name();
    NSString *srcpath = [NSString stringWithUTF8String:src_path.c_str()];
    NSString *dirpath = [NSString stringWithUTF8String:dir_path.c_str()];
    
    FileLinkNewHardlinkSheetController *sheet = [FileLinkNewHardlinkSheetController new];
    [sheet ShowSheet:[self window]
          sourcename:[NSString stringWithUTF8String:item.Name()]
             handler:^(int _result){
                 if(_result == DialogResult::Create)
                 {
                     NSString *name = [sheet.LinkName stringValue];
                     if([name length] == 0) return;
                     
                     if([name fileSystemRepresentation][0] != '/')
                         name = [NSString stringWithFormat:@"%@%@", dirpath, name];
                     
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithNewHardLink:[srcpath fileSystemRepresentation]
                                                            linkname:[name fileSystemRepresentation]]
                      ];
                 }
             }];
}

// when Operation.AddOnFinishHandler will use C++ lambdas - change return type here:
- (void (^)()) refreshBothCurrentControllersLambda
{
    __weak auto cur = self.activePanelController;
    __weak auto opp = self.oppositePanelController;
    auto update_both_panels = [=] {
        dispatch_to_main_queue( [=]{
            [(PanelController*)cur RefreshDirectory];
            [(PanelController*)opp RefreshDirectory];
        });
    };
    return update_both_panels;
}

- (IBAction)OnFileCopyCommand:(id)sender{
    if(!self.activePanelController ||
       !self.oppositePanelController ||
       [m_MainSplitView anyCollapsedOrOverlayed])
        return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntries;
    if( entries.empty() )
        return;
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda;

    FileCopyOperationOptions opts;
    opts.docopy = true;
    
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                             sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                          initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];        
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileCopyAsCommand:(id)sender{
    if(!self.activePanelController ||
       !self.oppositePanelController ||
       [m_MainSplitView anyCollapsedOrOverlayed])
        return;
    
    // process only current cursor item
    auto item = self.activePanelView.item;
    if( !item || item.IsDotDot() )
        return;

    auto entries = vector<VFSFlexibleListingItem>({item});
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
    
    FileCopyOperationOptions opts;
    opts.docopy = true;
    
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:item.Host()
                                             sourceDirectory:item.Directory()
                                          initialDestination:item.Filename()
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileRenameMoveCommand:(id)sender{
    if(!self.activePanelController ||
       !self.oppositePanelController ||
       [m_MainSplitView anyCollapsedOrOverlayed])
        return;
    
    if( self.activePanelController.isUniform && !self.activePanelController.vfs->IsWriteable() )
        return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntries;
    if( entries.empty() )
        return;
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
    
    FileCopyOperationOptions opts;
    opts.docopy = false;
    
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                             sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                          initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileRenameMoveAsCommand:(id)sender {
    if(!self.activePanelController ||
       !self.oppositePanelController ||
       [m_MainSplitView anyCollapsedOrOverlayed])
        return;
    
    // process only current cursor item
    auto item = self.activePanelView.item;
    if( !item || item.IsDotDot() || !item.Host()->IsWriteable() )
        return;
    
    FileCopyOperationOptions opts;
    opts.docopy = false;

    auto entries = vector<VFSFlexibleListingItem>({item});
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:item.Host()
                                             sourceDirectory:item.Directory()
                                          initialDestination:item.Filename()
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileNewTab:(id)sender
{
    if(!self.activePanelController)
        return;
    if(self.activePanelController == self.leftPanelController)
       [self addNewTabToTabView:m_MainSplitView.leftTabbedHolder.tabView];
    else if(self.activePanelController == self.rightPanelController)
        [self addNewTabToTabView:m_MainSplitView.rightTabbedHolder.tabView];
}

- (IBAction)performClose:(id)sender
{
    PanelController *cur = self.activePanelController;
    int tabs = 1;
    if( [self isLeftController:cur] )
        tabs = m_MainSplitView.leftTabbedHolder.tabsCount;
    if( [self isRightController:cur] )
        tabs = m_MainSplitView.rightTabbedHolder.tabsCount;

    if(tabs > 1)
        [self closeCurrentTab];
    else
        [self.window performClose:sender];
}

- (IBAction)OnFileCloseWindow:(id)sender
{
    [self.window performClose:sender];
}

- (IBAction)OnWindowShowPreviousTab:(id)sender
{
    [self selectPreviousFilePanelTab];
}

- (IBAction)OnWindowShowNextTab:(id)sender
{
    [self selectNextFilePanelTab];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString* characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    auto kc = theEvent.keyCode;
    auto mod = theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    mod &= ~NSAlphaShiftKeyMask;
    mod &= ~NSNumericPadKeyMask;
    mod &= ~NSFunctionKeyMask;
    auto unicode = [characters characterAtIndex:0];
    
    const auto &am = ActionsShortcutsManager::Instance();
    
    // workaround for (shift)+ctrl+tab when it's menu item is disabled. mysterious stuff...
    if( unicode == NSTabCharacter && mod == NSControlKeyMask ) {
        static const int next_tab = ActionsShortcutsManager::Instance().TagFromAction("menu.window.show_next_tab");
        if([NSApplication.sharedApplication.menu itemWithTagHierarchical:next_tab].enabled)
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    if( unicode == NSTabCharacter && mod == (NSControlKeyMask|NSShiftKeyMask) ) {
        static const int prev_tab = ActionsShortcutsManager::Instance().TagFromAction("menu.window.show_previous_tab");
        if([NSApplication.sharedApplication.menu itemWithTagHierarchical:prev_tab].enabled)
            return [super performKeyEquivalent:theEvent];
        return true;
    }

    const auto isshortcut = [&](int tag) {
        if( auto sc = am.ShortCutFromTag(tag) )
            return sc->IsKeyDown(unicode, kc, mod);
        return false;
    };

    // overlapped terminal stuff
    if( configuration::has_terminal ) {
        static const auto filepanels_move_up = am.TagFromAction( "menu.view.panels_position.move_up" );
        if( isshortcut(filepanels_move_up) ) {
            [self OnViewPanelsPositionMoveUp:self];
            return true;
        }
        
        static const auto filepanels_move_down = am.TagFromAction( "menu.view.panels_position.move_down" );
        if( isshortcut(filepanels_move_down) ) {
            [self OnViewPanelsPositionMoveDown:self];
            return true;
        }
        
        static const auto filepanels_showhide = am.TagFromAction( "menu.view.panels_position.showpanels" );
        if( isshortcut(filepanels_showhide) ) {
            [self OnViewPanelsPositionShowHidePanels:self];
            return true;
        }
        
        static const auto filepanels_focusterminal = am.TagFromAction( "menu.view.panels_position.focusterminal" );
        if( isshortcut(filepanels_focusterminal) ) {
            [self OnViewPanelsPositionFocusOverlappedTerminal:self];
            return true;
        }
    }
    
    return [super performKeyEquivalent:theEvent];
}

- (IBAction)OnShowTabs:(id)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:![defaults boolForKey:g_DefsGeneralShowTabs] forKey:g_DefsGeneralShowTabs];
}

- (IBAction)OnViewPanelsPositionMoveUp:(id)sender
{
    [self increaseBottomTerminalGap];
}

- (IBAction)OnViewPanelsPositionMoveDown:(id)sender
{
    [self decreaseBottomTerminalGap];
}

- (IBAction)OnViewPanelsPositionShowHidePanels:(id)sender
{
    if(self.isPanelsSplitViewHidden)
        [self showPanelsSplitView];
    else
        [self hidePanelsSplitView];
}

- (IBAction)OnViewPanelsPositionFocusOverlappedTerminal:(id)sender
{
    [self handleCtrlAltTab];
}

- (IBAction)OnFileFeedFilenameToTerminal:(id)sender
{
    [self feedOverlappedTerminalWithCurrentFilename];
}

- (IBAction)OnFileFeedFilenamesToTerminal:(id)sender
{
    [self feedOverlappedTerminalWithFilenamesMenu];
}

@end
