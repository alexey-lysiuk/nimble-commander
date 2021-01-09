// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <catch2/catch.hpp>
#include <filesystem>

//#define GTEST_DONT_DEFINE_FAIL 1
//#define GTEST_DONT_DEFINE_SUCCEED 1
//#include <gmock/gmock.h>

struct TempTestDir
{
    TempTestDir();
    ~TempTestDir();
    std::filesystem::path directory;
    operator const std::filesystem::path&() const noexcept { return directory;}
    operator const std::string&() const noexcept { return directory.native(); }
};

#ifndef NCE
    #if __has_include(<.nc_sensitive.h>)
        #include <.nc_sensitive.h>
        #define NCE( v ) (v)
    #else
        #define NCE( v ) ("")
    #endif
#endif
