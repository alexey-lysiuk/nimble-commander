#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include "PanelController+Menu.h"
#include "MainWindowFilePanelState.h"
#include <NimbleCommander/States/MainWindowController.h>
#include "Actions/CopyFilePaths.h"
#include "Actions/AddToFavorites.h"
#include "Actions/GoToFolder.h"
#include "Actions/EjectVolume.h"
#include "Actions/ShowVolumeInformation.h"
#include "Actions/InsertFromPasteboard.h"
#include "Actions/OpenXAttr.h"
#include "Actions/CalculateChecksum.h"
#include "Actions/SpotlightSearch.h"
#include "Actions/OpenWithExternalEditor.h"
#include "Actions/ToggleSort.h"
#include "Actions/FindFiles.h"
#include "Actions/ShowGoToPopup.h"
#include "Actions/MakeNew.h"
#include "Actions/CalculateSizes.h"
#include "Actions/BatchRename.h"
#include "Actions/ToggleLayout.h"
#include "Actions/ChangeAttributes.h"
#include "Actions/RenameInPlace.h"
#include "Actions/Select.h"
#include "Actions/CopyToPasteboard.h"
#include "Actions/OpenNetworkConnection.h"
#include "Actions/Delete.h"
#include "Actions/NavigateHistory.h"
#include "Actions/Duplicate.h"
#include "Actions/Compress.h"
#include "PanelView.h"

static const nc::panel::actions::PanelAction *ActionByTag(int _tag) noexcept;
static void Perform(SEL _sel, PanelController *_target, id _sender);

@implementation PanelController (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    try {
        const auto tag = (int)item.tag;
        if( auto a = ActionByTag(tag) )
            return a->ValidateMenuItem(self, item);
        IF_MENU_TAG("menu.go.enclosing_folder")             return self.currentDirectoryPath != "/" || (self.isUniform && self.vfs->Parent() != nullptr);
        IF_MENU_TAG("menu.go.into_folder")                  return self.view.item && !self.view.item.IsDotDot();
        IF_MENU_TAG("menu.command.internal_viewer")         return self.view.item && !self.view.item.IsDir();
        IF_MENU_TAG("menu.command.quick_look")              return self.view.item && !self.state.anyPanelCollapsed;
        IF_MENU_TAG("menu.command.system_overview")         return !self.state.anyPanelCollapsed;
        return true;
    }
    catch(exception &e) {
        cout << "validateMenuItem has caught an exception: " << e.what() << endl;
    }
    catch(...) {
        cout << "validateMenuItem has caught an unknown exception!" << endl;
    }
    return false;
}

- (IBAction)OnGoToUpperDirectory:(id)sender
{ // cmd+up
    [self HandleGoToUpperDirectory];
}

- (IBAction)OnGoIntoDirectory:(id)sender
{ // cmd+down
    auto item = self.view.item;
    if( item && !item.IsDotDot() )
        [self handleGoIntoDirOrArchiveSync:false];
}

- (IBAction)OnOpen:(id)sender { // enter
    [self handleGoIntoDirOrOpenInSystemSync];
}

- (IBAction)OnOpenNatively:(id)sender { // shift+enter
    [self handleOpenInSystem];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender {
    if( auto i = self.view.item ) {
        if( i.IsDir() )
            return;
        [self.mainWindowController RequestBigFileView:i.Path() with_fs:i.Host()];
    }
}

- (IBAction)OnRefreshPanel:(id)sender
{
    [self forceRefreshPanel];
}

- (IBAction)onCompressItems:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onCompressItemsHere:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnDuplicate:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoBack:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoForward:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToFavoriteLocation:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnDeleteCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnDeletePermanentlyCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnMoveToTrash:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToSavedConnectionItem:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToFTP:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToSFTP:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToNetworkShare:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToDropboxStorage:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnConnectToNetworkServer:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)copy:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnSelectByMask:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnDeselectByMask:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickSelectByExtension:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickDeselectByExtension:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)selectAll:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)deselectAll:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnMenuInvertSelection:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnRenameFileInPlace:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)paste:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)moveItemHere:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToHome:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToDocuments:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToDesktop:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToDownloads:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToApplications:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToUtilities:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToLibrary:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToRoot:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToProcessesList:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToFolder:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCreateDirectoryCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCalculateChecksum:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickNewFolder:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickNewFolderWithSelection:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickNewFile:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnBatchRename:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnOpenExtendedAttributes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnAddToFavorites:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnSpotlightSearch:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnEjectVolume:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCopyCurrentFileName:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCopyCurrentFilePath:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCalculateSizes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCalculateAllSizes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleViewHiddenFiles:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleExtensionlessFolders:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleCaseSensitiveComparison:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleNumericComparison:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByName:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByExt:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByMTime:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortBySize:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByBTime:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByATime:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout1:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout2:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout3:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout4:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout5:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout6:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout7:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout8:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout9:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout10:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnOpenWithExternalEditor:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileAttributes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnDetailedVolumeInformation:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onMainMenuPerformFindAction:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsParents:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsHistory:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsVolumes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsFavorites:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsConnections:(id)sender { Perform(_cmd, self, sender); }
@end

using namespace nc::panel::actions;
static const tuple<const char*, SEL, const PanelAction *> g_Wiring[] = {
{"menu.file.find",                      @selector(onMainMenuPerformFindAction:),    new FindFiles},
{"menu.file.find_with_spotlight",       @selector(OnSpotlightSearch:),              new SpotlightSearch},
{"menu.file.duplicate",                 @selector(OnDuplicate:),                    new Duplicate},
{"menu.file.add_to_favorites",          @selector(OnAddToFavorites:),               new AddToFavorites},
{"menu.file.calculate_sizes",           @selector(OnCalculateSizes:),               new CalculateSizes},
{"menu.file.calculate_all_sizes",       @selector(OnCalculateAllSizes:),            new CalculateAllSizes},
{"menu.file.calculate_checksum",        @selector(OnCalculateChecksum:),            new CalculateChecksum},
{"menu.file.new_file",                  @selector(OnQuickNewFile:),                 new MakeNewFile},
{"menu.file.new_folder",                @selector(OnQuickNewFolder:),               new MakeNewFolder},
{"menu.file.new_folder_with_selection", @selector(OnQuickNewFolderWithSelection:),  new MakeNewFolderWithSelection},
{"menu.edit.copy",                      @selector(copy:),                   new CopyToPasteboard},
{"menu.edit.paste",                     @selector(paste:),                  new PasteFromPasteboard},
{"menu.edit.move_here",                 @selector(moveItemHere:),           new MoveFromPasteboard},
{"menu.edit.select_all",                @selector(selectAll:),              new SelectAll},
{"menu.edit.deselect_all",              @selector(deselectAll:),            new DeselectAll},
{"menu.edit.invert_selection",          @selector(OnMenuInvertSelection:),  new InvertSelection},
{"menu.view.sorting_by_name",               @selector(ToggleSortByName:),               new ToggleSortingByName},
{"menu.view.sorting_by_extension",          @selector(ToggleSortByExt:),                new ToggleSortingByExtension},
{"menu.view.sorting_by_size",               @selector(ToggleSortBySize:),               new ToggleSortingBySize},
{"menu.view.sorting_by_modify_time",        @selector(ToggleSortByMTime:),              new ToggleSortingByModifiedTime},
{"menu.view.sorting_by_creation_time",      @selector(ToggleSortByBTime:),              new ToggleSortingByCreatedTime},
{"menu.view.sorting_by_added_time",         @selector(ToggleSortByATime:),              new ToggleSortingByAddedTime},
{"menu.view.sorting_case_sensitive",        @selector(ToggleCaseSensitiveComparison:),  new ToggleSortingCaseSensitivity},
{"menu.view.sorting_separate_folders",      @selector(ToggleSeparateFoldersFromFiles:), new ToggleSortingFoldersSeparation},
{"menu.view.sorting_extensionless_folders", @selector(ToggleExtensionlessFolders:),     new ToggleSortingExtensionlessFolders},
{"menu.view.sorting_numeric_comparison",    @selector(ToggleNumericComparison:),        new ToggleSortingNumerical},
{"menu.view.sorting_view_hidden",           @selector(ToggleViewHiddenFiles:),          new ToggleSortingShowHidden},
{"menu.view.toggle_layout_1",  @selector(onToggleViewLayout1:),  new ToggleLayout{0}},
{"menu.view.toggle_layout_2",  @selector(onToggleViewLayout2:),  new ToggleLayout{1}},
{"menu.view.toggle_layout_3",  @selector(onToggleViewLayout3:),  new ToggleLayout{2}},
{"menu.view.toggle_layout_4",  @selector(onToggleViewLayout4:),  new ToggleLayout{3}},
{"menu.view.toggle_layout_5",  @selector(onToggleViewLayout5:),  new ToggleLayout{4}},
{"menu.view.toggle_layout_6",  @selector(onToggleViewLayout6:),  new ToggleLayout{5}},
{"menu.view.toggle_layout_7",  @selector(onToggleViewLayout7:),  new ToggleLayout{6}},
{"menu.view.toggle_layout_8",  @selector(onToggleViewLayout8:),  new ToggleLayout{7}},
{"menu.view.toggle_layout_9",  @selector(onToggleViewLayout9:),  new ToggleLayout{8}},
{"menu.view.toggle_layout_10", @selector(onToggleViewLayout10:), new ToggleLayout{9}},
{"menu.go.back",            @selector(OnGoBack:),           new GoBack},
{"menu.go.forward",         @selector(OnGoForward:),        new GoForward},
{"menu.go.home",            @selector(OnGoToHome:),         new GoToHomeFolder},
{"menu.go.documents",       @selector(OnGoToDocuments:),    new GoToDocumentsFolder},
{"menu.go.desktop",         @selector(OnGoToDesktop:),      new GoToDesktopFolder},
{"menu.go.downloads",       @selector(OnGoToDownloads:),    new GoToDownloadsFolder},
{"menu.go.applications",    @selector(OnGoToApplications:), new GoToApplicationsFolder},
{"menu.go.utilities",       @selector(OnGoToUtilities:),    new GoToUtilitiesFolder},
{"menu.go.library",         @selector(OnGoToLibrary:),      new GoToLibraryFolder},
{"menu.go.root",            @selector(OnGoToRoot:),         new GoToRootFolder},
{"menu.go.processes_list",  @selector(OnGoToProcessesList:),new GoToProcessesList},
{"menu.go.to_folder",       @selector(OnGoToFolder:),       new GoToFolder},
{"menu.go.connect.ftp",             @selector(OnGoToFTP:),                  new OpenNewFTPConnection},
{"menu.go.connect.sftp",            @selector(OnGoToSFTP:),                 new OpenNewSFTPConnection},
{"menu.go.connect.lanshare",        @selector(OnGoToNetworkShare:),         new OpenNewLANShare},
{"menu.go.connect.dropbox",         @selector(OnGoToDropboxStorage:),       new OpenNewDropboxStorage},
{"menu.go.connect.network_server",  @selector(OnConnectToNetworkServer:),   new OpenNetworkConnections},
{"",                                @selector(OnGoToSavedConnectionItem:),  new OpenExistingNetworkConnection},
{"menu.go.quick_lists.parent_folders",  @selector(OnGoToQuickListsParents:),    new ShowParentFoldersQuickList},
{"menu.go.quick_lists.history",         @selector(OnGoToQuickListsHistory:),    new ShowHistoryQuickList},
{"menu.go.quick_lists.favorites",       @selector(OnGoToQuickListsFavorites:),  new ShowFavoritesQuickList},
{"menu.go.quick_lists.volumes",         @selector(OnGoToQuickListsVolumes:),    new ShowVolumesQuickList},
{"menu.go.quick_lists.connections",     @selector(OnGoToQuickListsConnections:),new ShowConnectionsQuickList},
{"",                                    @selector(OnGoToFavoriteLocation:),     new GoToFavoriteLocation},
{"menu.command.select_with_mask",       @selector(OnSelectByMask:),             new SelectAllByMask{true}},
{"menu.command.select_with_extension",  @selector(OnQuickSelectByExtension:),   new SelectAllByExtension{true}},
{"menu.command.deselect_with_mask",     @selector(OnDeselectByMask:),           new SelectAllByMask{false}},
{"menu.command.deselect_with_extension",@selector(OnQuickDeselectByExtension:), new SelectAllByExtension{false}},
{"menu.command.volume_information",     @selector(OnDetailedVolumeInformation:),new ShowVolumeInformation},
{"menu.command.file_attributes",        @selector(OnFileAttributes:),           new ChangeAttributes},
{"menu.command.external_editor",        @selector(OnOpenWithExternalEditor:),   new OpenWithExternalEditor},
{"menu.command.eject_volume",           @selector(OnEjectVolume:),              new EjectVolume},
{"menu.command.copy_file_name",         @selector(OnCopyCurrentFileName:),      new CopyFileName},
{"menu.command.copy_file_path",         @selector(OnCopyCurrentFilePath:),      new CopyFilePath},
{"menu.command.create_directory",       @selector(OnCreateDirectoryCommand:),   new MakeNewNamedFolder},
{"menu.command.batch_rename",           @selector(OnBatchRename:),              new BatchRename},
{"menu.command.rename_in_place",        @selector(OnRenameFileInPlace:),        new RenameInPlace},
{"menu.command.open_xattr",             @selector(OnOpenExtendedAttributes:),   new OpenXAttr},
{"menu.command.move_to_trash",          @selector(OnMoveToTrash:),              new MoveToTrash},
{"menu.command.delete",                 @selector(OnDeleteCommand:),            new Delete},
{"menu.command.delete_permanently",     @selector(OnDeletePermanentlyCommand:), new Delete{true}},
{"menu.command.compress_here",          @selector(onCompressItemsHere:),        new CompressHere},
{"menu.command.compress_to_opposite",   @selector(onCompressItems:),            new CompressToOpposite},
};

static const PanelAction *ActionByTag(int _tag) noexcept
{
    static const auto actions = []{
        unordered_map<int, const PanelAction*> m;
        auto &am = ActionsShortcutsManager::Instance();
        for( auto &a: g_Wiring )
            if( get<0>(a)[0] != 0 ) {
                if( auto tag = am.TagFromAction(get<0>(a)); tag >= 0 )
                    m.emplace( tag, get<2>(a) );
                else
                    cout << "warning - unrecognized action: " << get<0>(a) << endl;
            }
        return m;
    }();
    const auto v = actions.find(_tag);
    return v == end(actions) ? nullptr : v->second;
}

static void Perform(SEL _sel, PanelController *_target, id _sender)
{
    static const auto actions = []{
        unordered_map<SEL, const PanelAction*> m;
        for( auto &a: g_Wiring )
            m.emplace( get<1>(a), get<2>(a) );
        return m;
    }();
    if( const auto v = actions.find(_sel); v != end(actions) )
        v->second->Perform(_target, _sender);
    else
        cout << "warning - unrecognized selector: " <<
            NSStringFromSelector(_sel).UTF8String << endl;
}
