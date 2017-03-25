//
//  NetworkShareSheetController.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 3/24/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>

@interface NetworkShareSheetController : SheetController<NSTextFieldDelegate>

- (instancetype) init;
- (instancetype) initWithConnection:(NetworkConnectionsManager::Connection)_connection;

@property (readonly, nonatomic) NSString* providedPassword;
@property (readonly, nonatomic) NetworkConnectionsManager::Connection connection;

@end