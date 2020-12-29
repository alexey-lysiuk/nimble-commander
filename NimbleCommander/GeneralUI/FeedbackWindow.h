// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc {
class FeedbackManager;
}

namespace nc::bootstrap {
class ActivationManager;
}

@interface FeedbackWindow : NSWindowController

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am
                          feedbackManager:(nc::FeedbackManager &)_fm;

@property(nonatomic) int rating;

@end
