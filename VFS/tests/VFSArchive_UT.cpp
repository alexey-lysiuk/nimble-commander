// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/ArcLA.h>
#include <Habanero/WriteAtomically.h>

using namespace nc::vfs;

#define PREFIX "VFSArchive "

TEST_CASE(PREFIX "Can unzip an archive with Chinese symbols")
{
    // These two archives have a single file named "中文测试", which is 4byte long: "123\x0A"
    static const unsigned char __chineese_name_zip_a[] = {
        0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x08, 0x00, 0x08, 0x00, 0x50, 0x04, 0xf8, 0x54, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x20, 0x00, 0xe4, 0xb8, 0xad, 0xe6, 0x96, 0x87,
        0xe6, 0xb5, 0x8b, 0xe8, 0xaf, 0x95, 0x55, 0x54, 0x0d, 0x00, 0x07, 0x18, 0x23, 0xdc, 0x62, 0x19, 0x23, 0xdc,
        0x62, 0x18, 0x23, 0xdc, 0x62, 0x75, 0x78, 0x0b, 0x00, 0x01, 0x04, 0xf5, 0x01, 0x00, 0x00, 0x04, 0x14, 0x00,
        0x00, 0x00, 0x33, 0x34, 0x32, 0xe6, 0x02, 0x00, 0x50, 0x4b, 0x07, 0x08, 0x08, 0xfd, 0x82, 0x5a, 0x06, 0x00,
        0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x50, 0x4b, 0x01, 0x02, 0x14, 0x03, 0x14, 0x00, 0x08, 0x00, 0x08, 0x00,
        0x50, 0x04, 0xf8, 0x54, 0x08, 0xfd, 0x82, 0x5a, 0x06, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x0c, 0x00,
        0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xa4, 0x81, 0x00, 0x00, 0x00, 0x00, 0xe4, 0xb8,
        0xad, 0xe6, 0x96, 0x87, 0xe6, 0xb5, 0x8b, 0xe8, 0xaf, 0x95, 0x55, 0x54, 0x0d, 0x00, 0x07, 0x18, 0x23, 0xdc,
        0x62, 0x19, 0x23, 0xdc, 0x62, 0x18, 0x23, 0xdc, 0x62, 0x75, 0x78, 0x0b, 0x00, 0x01, 0x04, 0xf5, 0x01, 0x00,
        0x00, 0x04, 0x14, 0x00, 0x00, 0x00, 0x50, 0x4b, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x5a, 0x00, 0x00, 0x00, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00};
    static const unsigned int __chineese_name_zip_a_len = 208;

    static const unsigned char __chineese_name_zip_b[] = {
        0x50, 0x4b, 0x03, 0x04, 0x0a, 0x00, 0x00, 0x08, 0x00, 0x00, 0x51, 0x04, 0xf8, 0x54, 0x08, 0xfd, 0x82, 0x5a,
        0x04, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x00, 0xe4, 0xb8, 0xad, 0xe6, 0x96, 0x87,
        0xe6, 0xb5, 0x8b, 0xe8, 0xaf, 0x95, 0x31, 0x32, 0x33, 0x0a, 0x50, 0x4b, 0x01, 0x02, 0x3f, 0x03, 0x0a, 0x00,
        0x00, 0x08, 0x00, 0x00, 0x51, 0x04, 0xf8, 0x54, 0x08, 0xfd, 0x82, 0x5a, 0x04, 0x00, 0x00, 0x00, 0x04, 0x00,
        0x00, 0x00, 0x0c, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x80, 0xa4, 0x81, 0x00, 0x00,
        0x00, 0x00, 0xe4, 0xb8, 0xad, 0xe6, 0x96, 0x87, 0xe6, 0xb5, 0x8b, 0xe8, 0xaf, 0x95, 0x0a, 0x00, 0x20, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x18, 0x00, 0x29, 0xf5, 0x28, 0x16, 0xb2, 0x9e, 0xd8, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x50, 0x4b, 0x05, 0x06,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x5e, 0x00, 0x00, 0x00, 0x2e, 0x00, 0x00, 0x00, 0x00, 0x00};
    static const unsigned int __chineese_name_zip_b_len = 162;

    auto check = [](std::span<const std::byte> _bytes) {
        TestDir dir;
        const auto path = std::filesystem::path(dir.directory) / "tmp.zip";
        REQUIRE(nc::base::WriteAtomically(path, _bytes));

        std::shared_ptr<ArchiveHost> host;
        REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(path.c_str(), TestEnv().vfs_native));

        CHECK(host->StatTotalFiles() == 1);
        CHECK(host->StatTotalDirs() == 0);
        CHECK(host->StatTotalRegs() == 1);

        VFSFilePtr file;
        REQUIRE(host->CreateFile(reinterpret_cast<const char *>(u8"/中文测试"), file, 0) == 0);
        REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

        auto bytes = file->ReadFile();
        REQUIRE(bytes);
        REQUIRE(bytes->size() == 4);
        CHECK(std::memcmp(bytes->data(), "123\x0A", 4) == 0);
    };
    check({reinterpret_cast<const std::byte *>(__chineese_name_zip_a), __chineese_name_zip_a_len});
    check({reinterpret_cast<const std::byte *>(__chineese_name_zip_b), __chineese_name_zip_b_len});
}