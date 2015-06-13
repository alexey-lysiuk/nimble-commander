//
//  IdleSleepPreventer.cpp
//  Files
//
//  Created by Michael G. Kazakov on 16/04/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <IOKit/pwr_mgt/IOPMLib.h>
#include "IdleSleepPreventer.h"

IdleSleepPreventer::Promise::Promise()
{
    IdleSleepPreventer::Instance().Add();
}

IdleSleepPreventer::Promise::~Promise()
{
    IdleSleepPreventer::Instance().Release();
}

IdleSleepPreventer &IdleSleepPreventer::Instance()
{
    static auto i = new IdleSleepPreventer;
    return *i;
}

unique_ptr<IdleSleepPreventer::Promise> IdleSleepPreventer::GetPromise()
{
    return unique_ptr<IdleSleepPreventer::Promise>(new Promise);
}

void IdleSleepPreventer::Add()
{
    lock_guard<mutex> lock(m_Lock);
    m_Promises++;
    
    if( m_ID == kIOPMNullAssertionID ) {
        static CFStringRef reason = CFSTR("Files is performing an operation");
        IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep,
                                    kIOPMAssertionLevelOn,
                                    reason,
                                    &m_ID);
    }
}

void IdleSleepPreventer::Release()
{
    lock_guard<mutex> lock(m_Lock);
    m_Promises--;

    if( m_Promises == 0 && m_ID != kIOPMNullAssertionID ) {
        IOPMAssertionRelease(m_ID);
        m_ID = kIOPMNullAssertionID;
    }
}
