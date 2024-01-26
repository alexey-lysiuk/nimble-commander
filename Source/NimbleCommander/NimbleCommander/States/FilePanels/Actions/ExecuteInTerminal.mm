// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExecuteInTerminal.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelAux.h"
#include "../MainWindowFilePanelState.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <VFS/VFS.h>

namespace nc::panel::actions {

ExecuteInTerminal::ExecuteInTerminal(nc::bootstrap::ActivationManager &_am)
    : m_ActivationManager(_am)
{
}

bool ExecuteInTerminal::Predicate(PanelController *_target) const
{
    if( !m_ActivationManager.HasTerminal() )
        return false;

    const auto item = _target.view.item;
    if( !item || !item.Host()->IsNativeFS() )
        return false;

    return IsEligbleToTryToExecuteInConsole(item);
}

bool ExecuteInTerminal::ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const
{
    if( auto vfs_item = _target.view.item ) {
        _item.title = [NSString
            stringWithFormat:NSLocalizedString(@"Execute \u201c%@\u201d", "Execute a binary"),
                             vfs_item.DisplayNameNS()];
    }
    return Predicate(_target);
}

void ExecuteInTerminal::Perform(PanelController *_target, id) const
{
    if( !Predicate(_target) )
        return;

    const auto item = _target.view.item;
    [_target.state requestTerminalExecution:item.Filename() at:item.Directory()];
}

}