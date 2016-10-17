#pragma once

#include <VFS/VFS.h>
#include "../../../Files/PanelData.h"

@class PanelBriefView;

@interface PanelBriefViewItem : NSCollectionViewItem

/**
 * returns -1 on failure.
 */
- (int) itemIndex;

- (void) setItem:(VFSListingItem)_item;
- (void) setVD:(PanelData::PanelVolatileData)_vd;
- (void) setIcon:(NSImageRep*)_icon;

- (PanelBriefView*)briefView;

@end
