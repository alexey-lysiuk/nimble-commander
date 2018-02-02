// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CommonPaths.h>
#include <Utility/PathManip.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/ColoredSeparatorLine.h>
#include <VFS/Native.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/Core/rapidjson.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/FeedbackManager.h>
#include <NimbleCommander/States/MainWindowController.h>
#include "MainWindowFilePanelState.h"
#include "PanelController.h"
#include "PanelController+DataAccess.h"
#include "MainWindowFilePanelsStateToolbarDelegate.h"
#include "AskingForRatingOverlayView.h"
#include "Favorites.h"
#include "Views/QuickLookOverlay.h"
#include "Views/FilePanelMainSplitView.h"
#include "Views/BriefSystemOverview.h"
#include "Views/FilePanelOverlappedTerminal.h"
#include "PanelData.h"
#include "PanelView.h"
#include <Operations/Pool.h>
#include <Operations/PoolViewController.h>
#include "Views/QuickLookPanel.h"
#include <Quartz/Quartz.h>
#include "PanelAux.h"
#include "PanelControllerPersistency.h"
#include "Helpers/ClosedPanelsHistory.h"
#include "PanelHistory.h"
#include "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#include "MainWindowFilePanelState+TabsSupport.h"

using namespace nc::panel;

static const auto g_ConfigGoToActivation    = "filePanel.general.goToButtonForcesPanelActivation";
static const auto g_ConfigInitialLeftPath   = "filePanel.general.initialLeftPanelPath";
static const auto g_ConfigInitialRightPath  = "filePanel.general.initialRightPanelPath";
static const auto g_ConfigGeneralShowTabs   = "general.showTabs";
static const auto g_ConfigRouteKeyboardInputIntoTerminal = "filePanel.general.routeKeyboardInputIntoTerminal";
static const auto g_ResorationPanelsKey     = "panels_v1";
static const auto g_ResorationUIKey         = "uiState";
static const auto g_ResorationUISelectedLeftTab = "selectedLeftTab";
static const auto g_ResorationUISelectedRightTab = "selectedRightTab";
static const auto g_ResorationUIFocusedSide = "focusedSide";
static const auto g_InitialStatePath = "filePanel.initialState";
static const auto g_InitialStateLeftDefaults = "left";
static const auto g_InitialStateRightDefaults = "right";

static string ExpandPath(const string &_ref )
{
    if( _ref.empty() )
        return {};
    
    if( _ref.front() == '/' ) // absolute path
        return _ref;
    
    if( _ref.front() == '~' ) { // relative to home
        auto ref = _ref.substr(1);
        path p = path(CommonPaths::Home());
        if( !ref.empty() )
            p.remove_filename();
        p /= ref;
        return p.native();
    }
    
    return {};
}

static void SetupUnregisteredLabel(NSView *_background_view)
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,0,0)];
    tf.translatesAutoresizingMaskIntoConstraints = false;
    tf.stringValue = @"UNREGISTERED";
    tf.editable = false;
    tf.bordered = false;
    tf.drawsBackground = false;
    tf.alignment = NSTextAlignmentCenter;
    tf.textColor = NSColor.tertiaryLabelColor;
    tf.font = [NSFont labelFontOfSize:12];
    
    [_background_view addSubview:tf];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                                 attribute:NSLayoutAttributeCenterX
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1.0
                                                                  constant:0]];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:tf
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1.0
                                                                  constant:0]];
    [_background_view layoutSubtreeIfNeeded];
}

static void SetupRatingOverlay(NSView *_background_view)
{
    AskingForRatingOverlayView *v = [[AskingForRatingOverlayView alloc] initWithFrame:_background_view.bounds];
    v.translatesAutoresizingMaskIntoConstraints = false;
    [_background_view addSubview:v];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:v
                                                                 attribute:NSLayoutAttributeCenterX
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1.0
                                                                  constant:0]];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:v
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1.0
                                                                  constant:0]];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:v
                                                                 attribute:NSLayoutAttributeWidth
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeWidth
                                                                multiplier:1.0
                                                                  constant:0]];
    [_background_view addConstraint:[NSLayoutConstraint constraintWithItem:v
                                                                 attribute:NSLayoutAttributeHeight
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:_background_view
                                                                 attribute:NSLayoutAttributeHeight
                                                                multiplier:1.0
                                                                  constant:0]];
    [_background_view layoutSubtreeIfNeeded];
}

static bool GoToForcesPanelActivation()
{
    static const auto fetch = []{
        return GlobalConfig().GetBool(g_ConfigGoToActivation);
    };
    static bool force = []{
        static auto ticket = GlobalConfig().Observe(g_ConfigGoToActivation, []{
            force = fetch();
        });
        return fetch();
    }();
    return force;
}

static NSString *TrimmedTitleForWindow( NSString *_title, NSWindow *_window );
static NSString *TitleForData( const data::Model* _data );

@implementation MainWindowFilePanelState

@synthesize splitView = m_SplitView;
@synthesize closedPanelsHistory = m_ClosedPanelsHistory;
@synthesize favoriteLocationsStorage = m_FavoriteLocationsStorage;

- (instancetype) initBaseWithFrame:(NSRect)frameRect
                           andPool:(nc::ops::Pool&)_pool
                      panelFactory:(function<PanelController*()>)_panel_factory
{
    assert( _panel_factory );
    if( self = [super initWithFrame:frameRect] ) {
        m_PanelFactory = move(_panel_factory);
        m_ClosedPanelsHistory = nullptr;
        m_OperationsPool = _pool.shared_from_this();
        m_OverlappedTerminal = make_unique<MainWindowFilePanelState_OverlappedTerminalSupport>();
        m_ShowTabs = GlobalConfig().GetBool(g_ConfigGeneralShowTabs);
        
        m_LeftPanelControllers.emplace_back(m_PanelFactory());
        [self attachPanel:m_LeftPanelControllers.front()];

        m_RightPanelControllers.emplace_back(m_PanelFactory());
        [self attachPanel:m_RightPanelControllers.front()];
        
        [self CreateControls];
        
        [self updateTabBarsVisibility];
        [self loadOverlappedTerminalSettingsAndRunIfNecessary];
     
        [self setupNotificationsCallbacks];
    }
    return self;
}

- (instancetype) initWithFrame:(NSRect)frameRect
                       andPool:(nc::ops::Pool&)_pool
            loadDefaultContent:(bool)_load_content
                  panelFactory:(function<PanelController*()>)_panel_factory
{
    self = [self initBaseWithFrame:frameRect
                           andPool:_pool
                      panelFactory:move(_panel_factory)];
    if( self ) {
        if( _load_content ) {
            [self restoreDefaultPanelOptions];
            [self loadDefaultPanelContent];
        }
    }
    return self;
}

- (void) restoreDefaultPanelOptions
{
    const auto defaults = StateConfig().Get(g_InitialStatePath);
    if( defaults.GetType() != rapidjson::kObjectType )
        return;
    
    const auto left_it = defaults.FindMember(g_InitialStateLeftDefaults);
    if( left_it != defaults.MemberEnd() )
        ControllerStateJSONDecoder{m_LeftPanelControllers.front()}.Decode(left_it->value);
    
    const auto right_it = defaults.FindMember(g_InitialStateRightDefaults);
    if( right_it != defaults.MemberEnd() )
        ControllerStateJSONDecoder{m_RightPanelControllers.front()}.Decode(right_it->value);
}

- (void) setupNotificationsCallbacks
{
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(frameDidChange)
                                               name:NSViewFrameDidChangeNotification
                                             object:self];
    
    m_ConfigTickets.emplace_back( GlobalConfig().Observe(
        g_ConfigGeneralShowTabs, objc_callback(self, @selector(onShowTabsSettingChanged))));
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)acceptsFirstResponder
{
    return true;
}

- (NSToolbar*)windowStateToolbar
{
    return m_ToolbarDelegate.toolbar;
}

- (NSView*) windowStateContentView
{
    return self;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsUpdateLayer
{
    return true;
}

- (void) updateLayer
{
    self.layer.backgroundColor = CurrentTheme().FilePanelsGeneralOverlayColor().CGColor;
}

- (void) loadDefaultPanelContent
{
    auto &am = ActivationManager::Instance();
    auto left_controller = m_LeftPanelControllers.front();
    auto right_controller = m_RightPanelControllers.front();
    
    vector<string> left_panel_desired_paths, right_panel_desired_paths;
    
    // 1st attempt - load editable default path from config
    if( auto v = GlobalConfig().GetString(g_ConfigInitialLeftPath) )
        left_panel_desired_paths.emplace_back( ExpandPath(*v) );
    if( auto v = GlobalConfig().GetString(g_ConfigInitialRightPath) )
        right_panel_desired_paths.emplace_back( ExpandPath(*v) );
    
    // 2nd attempt - load home path
    left_panel_desired_paths.emplace_back( CommonPaths::Home() );
    right_panel_desired_paths.emplace_back( CommonPaths::Home() );
    
    // 3rd attempt - load first reachable folder in case of sandboxed environment
    if( am.Sandboxed() ) {
        left_panel_desired_paths.emplace_back( SandboxManager::Instance().FirstFolderWithAccess() );
        right_panel_desired_paths.emplace_back( SandboxManager::Instance().FirstFolderWithAccess() );
    }
    
    // 4rth attempt - load dir at startup cwd
    left_panel_desired_paths.emplace_back( CommonPaths::StartupCWD() );
    right_panel_desired_paths.emplace_back( CommonPaths::StartupCWD() );
    
    for( auto &p: left_panel_desired_paths ) {
        if( am.Sandboxed() && !SandboxManager::Instance().CanAccessFolder(p) )
            continue;
        if( [left_controller GoToDir:p vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok )
            break;
    }

    for( auto &p: right_panel_desired_paths ) {
        if( am.Sandboxed() && !SandboxManager::Instance().CanAccessFolder(p) )
            continue;
        if( [right_controller GoToDir:p vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok )
            break;
    }
}

- (void) CreateControls
{
    m_SplitView = [[FilePanelMainSplitView alloc] initWithFrame:NSRect()];
    m_SplitView.translatesAutoresizingMaskIntoConstraints = NO;
    [m_SplitView.leftTabbedHolder addPanel:m_LeftPanelControllers.front().view];
    [m_SplitView.rightTabbedHolder addPanel:m_RightPanelControllers.front().view];
    m_SplitView.leftTabbedHolder.tabBar.delegate = self;
    m_SplitView.rightTabbedHolder.tabBar.delegate = self;
    [self addSubview:m_SplitView];
    
    m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
    m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = NO;
    m_SeparatorLine.boxType = NSBoxSeparator;
    m_SeparatorLine.borderColor = CurrentTheme().FilePanelsGeneralTopSeparatorColor();
    [self addSubview:m_SeparatorLine];
    
    m_ToolbarDelegate = [[MainWindowFilePanelsStateToolbarDelegate alloc] initWithFilePanelsState:self];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_SeparatorLine, m_SplitView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0@250)-[m_SeparatorLine(<=1)]-(==0)-[m_SplitView]" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_SplitView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SeparatorLine]-(==0)-|" options:0 metrics:nil views:views]];
    m_MainSplitViewBottomConstraint = [NSLayoutConstraint constraintWithItem:m_SplitView
                                                                   attribute:NSLayoutAttributeBottom
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1
                                                                    constant:0];
    m_MainSplitViewBottomConstraint.priority = NSLayoutPriorityDragThatCannotResizeWindow;
    [self addConstraint:m_MainSplitViewBottomConstraint];
    
    if( ActivationManager::Instance().HasTerminal() ) {
        m_OverlappedTerminal->terminal = [[FilePanelOverlappedTerminal alloc] initWithFrame:self.bounds];
        m_OverlappedTerminal->terminal.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_OverlappedTerminal->terminal positioned:NSWindowBelow relativeTo:nil];
        
        auto terminal = m_OverlappedTerminal->terminal;
        views = NSDictionaryOfVariableBindings(terminal, m_SeparatorLine);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_SeparatorLine]-(0)-[terminal]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[terminal]-(0)-|" options:0 metrics:nil views:views]];
    }
    else {
        /* Fixing bugs in NSISEngine, kinda */
        NSView *dummy = [[NSView alloc] initWithFrame:self.bounds];
        dummy.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:dummy positioned:NSWindowBelow relativeTo:nil];
        views = NSDictionaryOfVariableBindings(dummy);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==1)-[dummy(>=100)]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[dummy(>=100)]-(0)-|" options:0 metrics:nil views:views]];
    }
    
    if( FeedbackManager::Instance().ShouldShowRatingOverlayView() )
        SetupRatingOverlay( m_ToolbarDelegate.operationsPoolViewController.idleView );
    else if( ActivationManager::Type() == ActivationManager::Distribution::Trial &&
            !ActivationManager::Instance().UserHadRegistered() )
        SetupUnregisteredLabel( m_ToolbarDelegate.operationsPoolViewController.idleView );
}

- (void) windowStateDidBecomeAssigned
{
    NSLayoutConstraint *c = [NSLayoutConstraint constraintWithItem:m_SeparatorLine
                                                         attribute:NSLayoutAttributeTop
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self.window.contentLayoutGuide
                                                         attribute:NSLayoutAttributeTop
                                                        multiplier:1
                                                          constant:0];
    c.active = true;
//    [self layoutSubtreeIfNeeded];

    if( m_LastResponder ) {
        // if we already were active and have some focused view - restore it
        [self.window makeFirstResponder:m_LastResponder];
        m_LastResponder = nil;
    }
    else {
        // if we don't know which view should be active - make left panel a first responder
        [self.window makeFirstResponder:m_SplitView.leftTabbedHolder.current];
    }
    
    [self updateTitle];
    
    [m_ToolbarDelegate notifyStateWasAssigned];
    
    // think it's a bad idea to post messages on every new window created
    GA().PostScreenView("File Panels State");
}

- (void) windowStateDidResign
{
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    if(_wnd == nil) {
        m_LastResponder = nil;
        if( auto resp = objc_cast<NSView>(self.window.firstResponder) )
            if( [resp isDescendantOf:self] )
                m_LastResponder = resp;
    }
}

- (bool) isPanelActive
{
    return self.activePanelController != nil;
}

- (PanelView*) activePanelView
{
    PanelController *pc = self.activePanelController;
    return pc ? pc.view : nil;
}

- (const data::Model*) activePanelData
{
    PanelController *pc = self.activePanelController;
    return pc ? &pc.data : nullptr;
}

- (PanelController*) activePanelController
{
    if( NSResponder *r = self.window.firstResponder ) {
        for(auto &pc: m_LeftPanelControllers)  if(r == pc.view) return pc;
        for(auto &pc: m_RightPanelControllers) if(r == pc.view) return pc;
    }
    return nil;
}

- (PanelController*) oppositePanelController
{
    PanelController* act = self.activePanelController;
    if(!act)
        return nil;
    if(act == self.leftPanelController)
        return self.rightPanelController;
    return self.leftPanelController;
}

- (const data::Model*) oppositePanelData
{
    PanelController* pc = self.oppositePanelController;
    return pc ? &pc.data : nullptr;
}

- (PanelView*) oppositePanelView
{
    PanelController* pc = self.oppositePanelController;
    return pc ? pc.view : nil;
}

- (PanelController*) leftPanelController
{
    return objc_cast<PanelController>(m_SplitView.leftTabbedHolder.current.delegate);
}

- (PanelController*) rightPanelController
{
    return objc_cast<PanelController>(m_SplitView.rightTabbedHolder.current.delegate);
}

- (const vector<PanelController*>&)leftControllers
{
    return m_LeftPanelControllers;
}

- (const vector<PanelController*>&)rightControllers
{
    return m_RightPanelControllers;
}

static bool Has(const vector<PanelController*> &_c, PanelController* _p) noexcept
{
    // this is called very often, so in order to help optimizer I manually removed all
    // Objective-C / ARC related semantics by casting everything to raw void*.
    // the difference between assembly outputs is huge.
    const void** first  = (const void**)(const void*)_c.data();
    const void** last   = first + _c.size();
    const void*  value  = (__bridge const void*)_p;
    return find( first, last, value ) != last;
}

- (bool) isLeftController:(PanelController*)_controller
{
    return Has(m_LeftPanelControllers, _controller);
}

- (bool) isRightController:(PanelController*)_controller
{
    return Has(m_RightPanelControllers, _controller);
}

- (void) changeFocusedSide
{
    if( m_SplitView.anyCollapsedOrOverlayed )
        return;
    if( auto cur = self.activePanelController ) {
        if( [self isLeftController:cur] )
            [self.window makeFirstResponder:m_SplitView.rightTabbedHolder.current];
        else
            [self.window makeFirstResponder:m_SplitView.leftTabbedHolder.current];
    }
}

- (void)ActivatePanelByController:(PanelController *)controller
{
    if([self isLeftController:controller]) {
        if(m_SplitView.leftTabbedHolder.current == controller.view) {
            [self.window makeFirstResponder:m_SplitView.leftTabbedHolder.current];
            return;
        }
        for(NSTabViewItem *it in m_SplitView.leftTabbedHolder.tabView.tabViewItems)
            if(it.view == controller.view) {
                [m_SplitView.leftTabbedHolder.tabView selectTabViewItem:it];
                [self.window makeFirstResponder:controller.view];
                return;
            }
    }
    else if([self isRightController:controller]) {
        if(m_SplitView.rightTabbedHolder.current == controller.view) {
            [self.window makeFirstResponder:m_SplitView.rightTabbedHolder.current];
            return;
        }
        for(NSTabViewItem *it in m_SplitView.rightTabbedHolder.tabView.tabViewItems)
            if(it.view == controller.view) {
                [m_SplitView.rightTabbedHolder.tabView selectTabViewItem:it];
                [self.window makeFirstResponder:controller.view];
                return;
            }
    }
}

- (void)activePanelChangedTo:(PanelController *)controller
{
    [self updateTitle];
    [self updateTabBarButtons];
    m_LastFocusedPanelController = controller;
    [self synchronizeOverlappedTerminalWithPanel:controller];
    [self markRestorableStateAsInvalid];
}

- (void)updateTitle
{
    self.window.title = TrimmedTitleForWindow(TitleForData(self.activePanelData), self.window);
}

static rapidjson::StandaloneValue EncodePanelsStates(
    const vector<PanelController*> &_left,
    const vector<PanelController*> &_right)
{
    using namespace rapidjson;
    StandaloneValue json{kArrayType};
    StandaloneValue left{kArrayType};
    StandaloneValue right{kArrayType};
    
    const auto encoding_opts = ControllerStateEncoding::EncodeEverything;
    
    for( auto pc: _left )
        if( auto v = ControllerStateJSONEncoder{pc}.Encode(encoding_opts) )
            left.PushBack( move(*v), g_CrtAllocator );
    
    for( auto pc: _right )
        if( auto v = ControllerStateJSONEncoder{pc}.Encode(encoding_opts) )
            right.PushBack( move(*v), g_CrtAllocator );
    
    json.PushBack( move(left), g_CrtAllocator );
    json.PushBack( move(right), g_CrtAllocator );
    
    return json;
}

static rapidjson::StandaloneValue EncodeUIState(MainWindowFilePanelState *_state)
{
    using namespace rapidjson;
    StandaloneValue ui{kObjectType};
    
    ui.AddMember(MakeStandaloneString( g_ResorationUISelectedLeftTab ),
                 StandaloneValue( _state.leftTabbedHolder.selectedIndex ),
                 g_CrtAllocator);
    
    ui.AddMember(MakeStandaloneString( g_ResorationUISelectedRightTab ),
                 StandaloneValue( _state.rightTabbedHolder.selectedIndex ),
                 g_CrtAllocator);

    const auto right_side_selected = [_state isRightController:_state.activePanelController];
    ui.AddMember(MakeStandaloneString( g_ResorationUIFocusedSide ),
                 MakeStandaloneString( right_side_selected ? "right" : "left" ),
                 g_CrtAllocator);
    
    return ui;
}

- (optional<rapidjson::StandaloneValue>) encodeRestorableState
{
    using namespace rapidjson;
    StandaloneValue json{kObjectType};
    
    json.AddMember(MakeStandaloneString(g_ResorationPanelsKey),
                   EncodePanelsStates( m_LeftPanelControllers, m_RightPanelControllers ),
                   g_CrtAllocator);
    json.AddMember(MakeStandaloneString(g_ResorationUIKey),
                   EncodeUIState(self),
                   g_CrtAllocator);
    
    return move(json);
}

- (bool) decodeRestorableState:(const rapidjson::StandaloneValue&)_state
{
    if( !_state.IsObject() )
        return false;
    
    if( _state.HasMember(g_ResorationPanelsKey) ) {
        const auto &json_panels = _state[g_ResorationPanelsKey];
        if( json_panels.IsArray() && json_panels.Size() == 2 ) {
            const auto &left = json_panels[0];
            if( left.IsArray() )
                for( auto i = left.Begin(), e = left.End(); i != e; ++i ) {
                    if( i != left.Begin() ) {
                        auto pc = m_PanelFactory();
                        [self attachPanel:pc];
                        [self addNewControllerOnLeftPane:pc];
                        ControllerStateJSONDecoder{pc}.Decode(*i);
                    }
                    else
                        ControllerStateJSONDecoder{m_LeftPanelControllers.front()}.Decode(*i);
                }
            
            const auto &right = json_panels[1];
            if( right.IsArray() )
                for( auto i = right.Begin(), e = right.End(); i != e; ++i ) {
                    if( i != right.Begin() ) {
                        auto pc = m_PanelFactory();
                        [self attachPanel:pc];
                        [self addNewControllerOnRightPane:pc];
                        ControllerStateJSONDecoder{pc}.Decode(*i);
                    }
                    else
                        ControllerStateJSONDecoder{m_RightPanelControllers.front()}.Decode(*i);
                }
        }
    }
    if( _state.HasMember(g_ResorationUIKey) ) {
        const auto &json_ui = _state[g_ResorationUIKey];
        if( json_ui.IsObject() ) {
            // invalid indeces are ok here, they will be discarded by FilePanelsTabbedHolder
            if( auto sel_left = GetOptionalIntFromObject(json_ui, g_ResorationUISelectedLeftTab) )
                [self.leftTabbedHolder selectTabAtIndex:*sel_left];
            if( auto sel_right = GetOptionalIntFromObject(json_ui, g_ResorationUISelectedRightTab) )
                [self.rightTabbedHolder selectTabAtIndex:*sel_right];
            if( auto side = GetOptionalStringFromObject(json_ui, g_ResorationUIFocusedSide) ) {
                const auto focus = [&]()->PanelController*{
                    if( *side == "right"s  )
                        return self.rightPanelController;
                    else if( *side == "left"s )
                        return self.leftPanelController;
                    return nil;
                }();
                if( focus ) {
                    // if we're already assigned to window - set first responder
                    if( self.window )
                        [self ActivatePanelByController:focus];
                    // if not - memorize it, will set on Assigned
                    else
                        m_LastResponder = focus.view;
                }
            }
        }
    }
    
    return m_LeftPanelControllers.front().data.IsLoaded() &&
           m_RightPanelControllers.front().data.IsLoaded();
}

- (void) markRestorableStateAsInvalid
{
    if( auto wc = objc_cast<MainWindowController>(self.window.delegate) )
        [wc invalidateRestorableState];
}

- (void) saveDefaultInitialState
{
    const auto left_panel = self.leftPanelController;
    if( !left_panel )
        return;
    
    const auto right_panel = self.rightPanelController;
    if( !right_panel )
        return;
    
    const auto to_encode = (ControllerStateEncoding::Options)(
                           ControllerStateEncoding::EncodeDataOptions |
                           ControllerStateEncoding::EncodeViewOptions);
    
    auto left_panel_options = ControllerStateJSONEncoder{left_panel}.Encode(to_encode);
    if( !left_panel_options )
        return;
    
    auto right_panel_options = ControllerStateJSONEncoder{right_panel}.Encode(to_encode);
    if( !right_panel_options )
        return;
    
    using namespace rapidjson;
    StandaloneValue json{kObjectType};
    json.AddMember(MakeStandaloneString(g_InitialStateLeftDefaults),
                   move(*left_panel_options),
                   g_CrtAllocator);
    json.AddMember(MakeStandaloneString(g_InitialStateRightDefaults),
                   move(*right_panel_options),
                   g_CrtAllocator);

    StateConfig().Set(g_InitialStatePath, json);
}

- (void)PanelPathChanged:(PanelController*)_panel
{
    if( _panel == nil )
        return;

    if( _panel == self.activePanelController ) {
        [self updateTitle];
        [self synchronizeOverlappedTerminalWithPanel:_panel];
    }
    
    [self updateTabNameForController:_panel];
    
    
    if( _panel.isUniform ) {
        if( m_FavoriteLocationsStorage )
            m_FavoriteLocationsStorage->ReportLocationVisit(*_panel.vfs,
                                                            _panel.currentDirectoryPath );
    }
}

- (void)viewDidMoveToWindow
{
    if( self.window ) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowDidResize)
                                                   name:NSWindowDidResizeNotification
                                                 object:self.window];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSWindowDidResizeNotification
                                                    object:nil];
    }
}

- (void)windowDidResize
{
    [self updateTitle];
}

- (void)windowStateWillClose
{
    [self saveOverlappedTerminalSettings];
  
    for( auto pc: m_LeftPanelControllers )
        [self panelWillBeClosed:pc];
    for( auto pc: m_RightPanelControllers )
        [self panelWillBeClosed:pc];
}

- (bool)windowStateShouldClose:(MainWindowController*)sender
{
    if( self.operationsPool.Empty() && !self.isAnythingRunningInOverlappedTerminal )
        return true;
    
    Alert *dialog = [[Alert alloc] init];
    [dialog addButtonWithTitle:NSLocalizedString(@"Stop and Close", "User action to stop running actions and close window")];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    dialog.messageText = NSLocalizedString(@"The window has running operations. Do you want to stop them and close the window?", "Asking user to close window with some operations running");
    [dialog beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSAlertFirstButtonReturn) {
            self.operationsPool.StopAndWaitForShutdown();
            [self.window close];
        }
    }];
    
    return false;
}

- (void)revealEntries:(const vector<string>&)_filenames inDirectory:(const string&)_path
{
    assert( dispatch_is_main_queue() );
    auto data = self.activePanelData;
    if(!data)
        return;
    
    auto panel = self.activePanelController;
    if(!panel)
        return;
    
    if( [panel GoToDir:_path vfs:VFSNativeHost::SharedHost() select_entry:"" async:false] == VFSError::Ok ) {
        if( !_filenames.empty() ) {
            nc::panel::DelayedFocusing req;
            req.filename = _filenames.front();
            [panel scheduleDelayedFocusing:req];
        }
        
        if( _filenames.size() > 1 )
            [panel selectEntriesWithFilenames:_filenames];
    }
}

- (vector<tuple<string, VFSHostPtr> >)filePanelsCurrentPaths
{
    vector<tuple<string, VFSHostPtr> > r;
    for( auto c: {&m_LeftPanelControllers, &m_RightPanelControllers} )
        for( auto p: *c )
            if( p.isUniform )
                r.emplace_back( p.currentDirectoryPath, p.vfs);
    return r;
}

- (id<NCPanelPreview>)quickLookForPanel:(PanelController*)_panel
                                   make:(bool)_make_if_absent
{
    if( ShowQuickLookAsFloatingPanel() )  {
        if( !_panel.isActive )
            return nil;
        
        if( QLPreviewPanel.sharedPreviewPanelExists && QLPreviewPanel.sharedPreviewPanel.isVisible )
            return [NCPanelQLPanelAdaptor adaptorForState:self];
        
        if( !_make_if_absent )
            return nil;
        
        [QLPreviewPanel.sharedPreviewPanel makeKeyAndOrderFront:nil];
        return [NCPanelQLPanelAdaptor adaptorForState:self];
    }
    else {
        if( [self isLeftController:_panel] )
            if( const auto ql = objc_cast<NCPanelQLOverlay>(m_SplitView.rightOverlay) )
                return ql;
        
        if( [self isRightController:_panel] )
            if( const auto ql = objc_cast<NCPanelQLOverlay>(m_SplitView.leftOverlay)  )
                return ql;
        
        if( _make_if_absent ) {
            if( m_SplitView.anyCollapsed )
                return nil;
            
            const auto rc = NSMakeRect(0, 0, 100, 100);
            const auto view = [[NCPanelQLOverlay alloc] initWithFrame:rc];
            
            if( [self isLeftController:_panel] )
                m_SplitView.rightOverlay = view;
            else if([self isRightController:_panel])
                m_SplitView.leftOverlay = view;
            else
                return nil;
            
            return view;
        }
        
        return nil;
    }
}

- (BriefSystemOverview*)briefSystemOverviewForPanel:(PanelController*)_panel
                                               make:(bool)_make_if_absent
{
    if( [self isLeftController:_panel] )
        if( const auto bso = objc_cast<BriefSystemOverview>(m_SplitView.rightOverlay) )
            return bso;
    
    if( [self isRightController:_panel] )
        if( const auto bso = objc_cast<BriefSystemOverview>(m_SplitView.leftOverlay)  )
            return bso;
    
    if( _make_if_absent ) {
        if( m_SplitView.anyCollapsed )
            return nil;
        
        const auto rc = NSMakeRect(0, 0, 100, 100);
        const auto view = [[BriefSystemOverview alloc] initWithFrame:rc];

        if( [self isLeftController:_panel] )
            m_SplitView.rightOverlay = view;
        else if( [self isRightController:_panel] )
            m_SplitView.leftOverlay = view;
        else
            return nil;
        
        return view;
    }
    
    return nil;
}

- (void)closeAttachedUI:(PanelController*)_panel
{
    if( [self isLeftController:_panel] )
        m_SplitView.rightOverlay = nil;
    else if( [self isRightController:_panel] )
        m_SplitView.leftOverlay = nil;
    
    if( QLPreviewPanel.sharedPreviewPanelExists && QLPreviewPanel.sharedPreviewPanel.isVisible )
        [QLPreviewPanel.sharedPreviewPanel orderOut:nil];
}

- (void)onShowTabsSettingChanged
{
    bool show = GlobalConfig().GetBool(g_ConfigGeneralShowTabs);
    if( show != m_ShowTabs )
        dispatch_to_main_queue_after(1ms, [=]{
            m_ShowTabs = show;
            [self updateTabBarsVisibility];
        });
}

- (void)updateBottomConstraint
{
    auto gap = [m_OverlappedTerminal->terminal bottomGapForLines:m_OverlappedTerminal->bottom_gap];
    m_MainSplitViewBottomConstraint.constant = -gap;
}

- (void)frameDidChange
{
    [self updateBottomConstraint];
}

- (bool)isPanelsSplitViewHidden
{
    return m_SplitView.hidden;
}

- (bool) anyPanelCollapsed
{
    return m_SplitView.anyCollapsed;
}

- (bool) bothPanelsAreVisible
{
    return !m_SplitView.hidden && !m_SplitView.anyCollapsedOrOverlayed;
}

- (void)requestTerminalExecution:(const string&)_filename at:(const string&)_cwd
{
    if( ![self executeInOverlappedTerminalIfPossible:_filename at:_cwd] ) {
        const auto ctrl = (MainWindowController*)self.window.delegate;
        [ctrl requestTerminalExecution:_filename.c_str()
                                    at:_cwd.c_str()];
    }
}

- (void)addNewControllerOnLeftPane:(PanelController*)_pc
{
    m_LeftPanelControllers.emplace_back(_pc);
    [m_SplitView.leftTabbedHolder addPanel:_pc.view];
}

- (void)addNewControllerOnRightPane:(PanelController*)_pc
{
    m_RightPanelControllers.emplace_back(_pc);
    [m_SplitView.rightTabbedHolder addPanel:_pc.view];
}

- (ExternalToolsStorage&)externalToolsStorage
{
    return NCAppDelegate.me.externalTools;
}

- (void)revealPanel:(PanelController *)panel
{
    if( [self isRightController:panel] ) {
        if( m_SplitView.isRightCollapsed )
            [m_SplitView expandRightView];
        m_SplitView.rightOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    }
    else if( [self isLeftController:panel] ) {
    
      if( m_SplitView.isLeftCollapsed )
        [m_SplitView expandLeftView];
    
        m_SplitView.leftOverlay = nil; // may cause bad situations with weak pointers inside panel controller here
    }
}

- (void)panelWillBeClosed:(PanelController*)_pc
{
    if( m_ClosedPanelsHistory ) {
        if( auto *listing_promise = _pc.history.MostRecent() )
            m_ClosedPanelsHistory->AddListing( *listing_promise );
    }
}

- (bool)goToForcesPanelActivation
{
    return GoToForcesPanelActivation();
}

- (nc::ops::Pool&) operationsPool
{
    return *m_OperationsPool;
}

- (MainWindowController*) mainWindowController
{
    return (MainWindowController*)self.window.delegate;
}

- (void) swapPanels
{
    if( m_SplitView.anyCollapsedOrOverlayed )
        return;
    
    swap(m_LeftPanelControllers, m_RightPanelControllers);
    [m_SplitView swapViews];
    [self markRestorableStateAsInvalid];
}

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel
{
    return ShowQuickLookAsFloatingPanel();
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel
{
    [NCPanelQLPanelAdaptor registerQuickLook:panel forState:self];
    if( auto pc = self.activePanelController )
        [pc updateAttachedQuickLook];
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel
{
    [NCPanelQLPanelAdaptor unregisterQuickLook:panel forState:self];
}

- (void)attachPanel:(PanelController*)_pc
{
    _pc.state = self;
    [_pc.view addKeystrokeSink:self withBasePriority:nc::panel::view::BiddingPriority::Default];
}

static bool RouteKeyboardInputIntoTerminal()
{
    static bool route = GlobalConfig().GetBool( g_ConfigRouteKeyboardInputIntoTerminal );
    static auto observe_ticket = GlobalConfig().Observe(g_ConfigRouteKeyboardInputIntoTerminal, []{
        route = GlobalConfig().GetBool( g_ConfigRouteKeyboardInputIntoTerminal );
    });
    return route;
}

- (int)bidForHandlingKeyDown:(NSEvent *)_event forPanelView:(PanelView*)_panel_view
{
    const auto character = _event.charactersIgnoringModifiers;
    if ( character.length == 0 )
        return nc::panel::view::BiddingPriority::Skip;
    const auto unicode = [character characterAtIndex:0];
    
    if( unicode ==  NSTabCharacter ) {
        return nc::panel::view::BiddingPriority::Default;
    }
    
    if( RouteKeyboardInputIntoTerminal() ) {
        const auto terminal_bid = [self bidForHandlingRoutedIntoOTKeyDown:_event];
        if ( terminal_bid > nc::panel::view::BiddingPriority::Skip )
            return terminal_bid;
    }
    
    return nc::panel::view::BiddingPriority::Skip;
}

- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView*)_panel_view
{
    const auto character = _event.charactersIgnoringModifiers;
    if ( character.length == 0 )
        return;
    const auto unicode = [character characterAtIndex:0];
    
    if( unicode ==  NSTabCharacter ) {
        [self changeFocusedSide];
        return;
    }
    
    if( RouteKeyboardInputIntoTerminal() ) {
        [self handleRoutedIntoOTKeyDown:_event];
        return;
    }
}

@end

static NSString *TrimmedTitleForWindow( NSString *_title, NSWindow *_window )
{
    static const auto attributes = @{NSFontAttributeName: [NSFont titleBarFontOfSize:0]};
    
    const auto left = NSMaxX([_window standardWindowButton:NSWindowZoomButton].frame);
    const auto right = _window.frame.size.width;
    const auto padding = 8.;
    const auto width = right - left - 2 * padding;
    return StringByTruncatingToWidth(_title, (float)width, kTruncateAtStart, attributes);
}

static NSString *TitleForData( const data::Model* _data )
{
    if( !_data )
        return @"";
    
    const auto path = [NSString stringWithUTF8StdString:_data->VerboseDirectoryFullPath()];
    if( !path )
        return @"...";
    
    return path;
}
