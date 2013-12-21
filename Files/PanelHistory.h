//
//  PanelHistory.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <list>
#import "VFS.h"

using namespace std;

class PanelHistory
{
public:
    PanelHistory();
    
    bool IsBeyond() const;
    bool IsBack() const;

    void MoveForth();
    void MoveBack();
    void Put(const VFSPathStack& _path);
    const VFSPathStack* Current() const;
        
private:
    list<VFSPathStack>  m_History;
    unsigned            m_Position;
};
