//
//  MASAppInstalledChecker.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "MASAppInstalledChecker.h"

MASAppInstalledChecker::MASAppInstalledChecker()
{
}

MASAppInstalledChecker &MASAppInstalledChecker::Instance()
{
    static auto inst = make_unique<MASAppInstalledChecker>();
    return *inst;
}

bool MASAppInstalledChecker::Has(const string &_app_name, const string &_app_id)
{
    // almost dummy now, as intended. will bother with whole validation process later.
    // for real implementation: https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW16
    
    string path = "/Applications/"s + _app_name + "/Contents/_MASReceipt/receipt";
    return access(path.c_str(), R_OK) == 0;
}