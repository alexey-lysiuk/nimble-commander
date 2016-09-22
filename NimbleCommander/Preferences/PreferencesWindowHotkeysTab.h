//
//  PreferencesWindowHotkeysTab.h
//  Files
//
//  Created by Michael G. Kazakov on 01.07.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "../../Files/3rd_party/RHPreferences/RHPreferences/RHPreferences.h"

class ExternalToolsStorage;

@interface PreferencesWindowHotkeysTab : NSViewController<RHPreferencesViewControllerProtocol,
                                                            NSTableViewDataSource,
                                                            NSTableViewDelegate>

- (id) initWithToolsStorage:(function<ExternalToolsStorage&()>)_tool_storage;

@end