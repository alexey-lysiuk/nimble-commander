//
//  TrialWindowController.h
//  Files
//
//  Created by Michael G. Kazakov on 27/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TrialWindowController : NSWindowController<NSWindowDelegate>
- (IBAction)OnClose:(id)sender;
@property (strong) IBOutlet NSTextField *versionTextField;
@property (strong) IBOutlet NSTextView *messageTextView;
@property (strong) IBOutlet NSTextField *copyrightTextField;


@end
