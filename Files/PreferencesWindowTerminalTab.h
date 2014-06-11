//
//  PreferencesWindowTerminalTab.h
//  Files
//
//  Created by Michael G. Kazakov on 10.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "3rd_party/RHPreferences/RHPreferences/RHPreferences.h"

@interface PreferencesWindowTerminalTab : NSViewController<RHPreferencesViewControllerProtocol>

@property (strong) IBOutlet NSTextField *fontVisibleName;

@end
