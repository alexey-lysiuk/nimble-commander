//
//  SheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 05/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Cocoa/Cocoa.h>

@interface SheetController : NSWindowController

- (void) beginSheetForWindow:(NSWindow*)_wnd
           completionHandler:(void (^)(NSModalResponse returnCode))_handler;
- (void) beginSheetForWindow:(NSWindow*)_wnd;

- (void) endSheet:(NSModalResponse)returnCode;

@end
