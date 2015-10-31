//
//  PanelController+DataAccess.h
//  Files
//
//  Created by Michael G. Kazakov on 22.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (DataAccess)

/**
 * Copies currently focused entry name.
 * Return "" if there's no focused entry (invalid state).
 */
@property (nonatomic, readonly) string currentFocusedEntryFilename;

/**
 * Copies currently focused item's full path relating to it's host.
 * Return "" if there's no focused entry (invalid state).
 */
@property (nonatomic, readonly) string currentFocusedEntryPath;

/** Copies current directory path with trailing slash relating to it's host. */
@property (nonatomic, readonly) string currentDirectoryPath;

/**
 * Return a list of selected entries filenames if any.
 * If no entries is selected - return currently focused element filename.
 * On case of only focused dot-dot entry return an empty list.
 */
@property (nonatomic, readonly) vector<string> selectedEntriesOrFocusedEntryFilenames;

/**
 * Like previous, but returns indeces in listing.
 * Order of items will obey current sorting.
 */
@property (nonatomic, readonly) vector<unsigned> selectedEntriesOrFocusedEntryIndeces;

/**
 * Return a list of selected entries filenames if any.
 * If no entries is selected - return currently focused element filename, including case of dot-dot.
 */
@property (nonatomic, readonly) vector<string> selectedEntriesOrFocusedEntryFilenamesWithDotDot;

@property (nonatomic, readonly) vector<VFSFlexibleListingItem> selectedEntriesOrFocusedEntries;

/**
 * Return current (topmost in vfs stack) VFS Host.
 * If current listing is non-uniform - will throw an exception.
 */
@property (nonatomic, readonly) const VFSHostPtr& vfs;

/**
 * Expands path with replacting ./ or ~/
 */
- (string) expandPath:(const string&)_ref;

@end
