// Copyright (C) 2017-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <RHPreferences/RHPreferences/RHPreferences.h>

namespace nc::bootstrap {
class ActivationManager;
}

@interface PreferencesWindowThemesTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                          NSOutlineViewDelegate,
                                                          NSOutlineViewDataSource,
                                                          NSTextFieldDelegate,
                                                          NSTableViewDataSource,
                                                          NSTableViewDelegate,
                                                          NSMenuItemValidation>

- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am;

@end