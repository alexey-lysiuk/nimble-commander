#pragma once

@class PanelBriefViewItem;
struct PanelBriefViewItemLayoutConstants;

@interface PanelBriefViewItemCarrier : NSView

@property (nonatomic, weak) PanelBriefViewItem                 *controller;
@property (nonatomic)       NSColor                            *background;
@property (nonatomic)       NSString                           *filename;
@property (nonatomic)       NSColor                            *filenameColor;
@property (nonatomic)       NSImage                            *icon;
@property (nonatomic)       PanelBriefViewItemLayoutConstants   layoutConstants;
@property (nonatomic)       pair<int16_t, int16_t>              qsHighlight;
@property (nonatomic)       bool                                highlighted;

- (void) setupFieldEditor:(NSScrollView*)_editor;

@end