// Copyright (C) 2015-2021 Michael G. Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CFString.h>

CFStringRef CFStringCreateWithUTF8StdString(const std::string &_s) noexcept
{
    return CFStringCreateWithBytes(
        0, reinterpret_cast<const UInt8 *>(_s.data()), _s.length(), kCFStringEncodingUTF8, false);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(std::string_view _s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         reinterpret_cast<const UInt8 *>(_s.data()),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StdStringNoCopy(const std::string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         reinterpret_cast<const UInt8 *>(_s.data()),
                                         _s.length(),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         reinterpret_cast<const UInt8 *>(_s),
                                         std::strlen(_s),
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithUTF8StringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         reinterpret_cast<const UInt8 *>(_s),
                                         _len,
                                         kCFStringEncodingUTF8,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStdStringNoCopy(const std::string &_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         reinterpret_cast<const UInt8 *>(_s.data()),
                                         _s.length(),
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         reinterpret_cast<const UInt8 *>(_s),
                                         strlen(_s),
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}

CFStringRef CFStringCreateWithMacOSRomanStringNoCopy(const char *_s, size_t _len) noexcept
{
    return CFStringCreateWithBytesNoCopy(0,
                                         reinterpret_cast<const UInt8 *>(_s),
                                         _len,
                                         kCFStringEncodingMacRoman,
                                         false,
                                         kCFAllocatorNull);
}

std::string CFStringGetUTF8StdString(CFStringRef _str)
{
    if( const char *cstr = CFStringGetCStringPtr(_str, kCFStringEncodingUTF8) )
        return std::string(cstr);

    CFIndex length = CFStringGetLength(_str);
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
    auto buffer = std::make_unique<char[]>(maxSize);
    if( CFStringGetCString(_str, &buffer[0], maxSize, kCFStringEncodingUTF8) )
        return std::string(buffer.get());

    return "";
}

CFString::CFString(const std::string &_str) noexcept
    : p(CFStringCreateWithBytes(0,
                                reinterpret_cast<const UInt8 *>(_str.data()),
                                _str.length(),
                                kCFStringEncodingUTF8,
                                false))
{
}

CFString::CFString(const std::string &_str, CFStringEncoding _encoding) noexcept
    : p(CFStringCreateWithBytes(0,
                                reinterpret_cast<const UInt8 *>(_str.data()),
                                _str.length(),
                                _encoding,
                                false))
{
}

CFString::CFString(const char *_str) noexcept
    : p(_str ? CFStringCreateWithBytes(0,
                                       reinterpret_cast<const UInt8 *>(_str),
                                       std::strlen(_str),
                                       kCFStringEncodingUTF8,
                                       false)
             : nullptr)
{
}
