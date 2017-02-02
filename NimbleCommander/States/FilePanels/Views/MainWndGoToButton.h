//
//  MainWndGoToButton.h
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>

@class MainWindowFilePanelState;

@interface MainWndGoToButtonSelection : NSObject
@end

@interface MainWndGoToButtonSelectionVFSPath : MainWndGoToButtonSelection
@property string path;
@property VFSHostWeakPtr vfs;
@end

@interface MainWndGoToButtonSelectionSavedNetworkConnection : MainWndGoToButtonSelection
@property NetworkConnectionsManager::Connection connection;
@end

@interface MainWndGoToButton : NSPopUpButton<NSMenuDelegate>
@property (nonatomic) __weak MainWindowFilePanelState *owner;
@property (nonatomic) bool isRight;
@property (nonatomic, readonly) MainWndGoToButtonSelection *selection;

- (void) popUp;

+ (vector<NSURL*>) finderFavorites;

@end