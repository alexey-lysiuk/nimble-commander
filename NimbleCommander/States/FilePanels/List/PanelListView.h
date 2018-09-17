// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../PanelViewImplementationProtocol.h"
#include <VFSIcon/IconRepository.h>

namespace nc::panel {
namespace data {
    class Model;
}
}

struct PanelViewPresentationItemsColoringRule;
@class PanelView;
class PanelListViewGeometry;

struct PanelListViewColumnsLayout;

@interface PanelListView: NSView<PanelViewImplementationProtocol, NSTableViewDataSource, NSTableViewDelegate>

- (id) initWithFrame:(NSRect)frameRect andIR:(nc::vfsicon::IconRepository&)_ir;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;
@property (nonatomic) nc::panel::data::SortMode sortMode;
@property (nonatomic) function<void(nc::panel::data::SortMode)> sortModeChangeCallback;
@property (nonatomic) PanelView *panelView;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(nc::panel::data::Model*)_data;

- (const PanelListViewGeometry&) geometry;

- (NSFont*) font;

- (NSMenu*) columnsSelectionMenu;

@property (nonatomic) PanelListViewColumnsLayout columnsLayout;

@end

void DrawTableVerticalSeparatorForView(NSView *v);
