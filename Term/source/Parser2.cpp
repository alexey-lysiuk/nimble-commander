// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Parser2.h"
#include <type_traits>
#include <magic_enum.hpp>

namespace nc::term::input {

static_assert( std::is_nothrow_default_constructible_v<Command> );
static_assert( std::is_nothrow_move_constructible_v<Command> );

static std::string ToString(Type _type)
{
    return std::string{magic_enum::enum_name(_type)};
}

template<class> inline constexpr bool always_false_v = false;

static std::string ToString(const Command::Payload &_payload)
{
    return std::visit([](auto&& arg){
        using T = std::decay_t<decltype(arg)>;
        using namespace std::string_literals;
        if constexpr( std::is_same_v<T, None> )
            return ""s;
        else if constexpr( std::is_same_v<T, signed> )
            return std::to_string(arg);
        else if constexpr( std::is_same_v<T, unsigned> )
            return std::to_string(arg);
        else if constexpr( std::is_same_v<T, UTF8Text> )
            return "'" + arg.characters + "'";
        else if constexpr( std::is_same_v<T, Title> )
            return arg.title; // + kind
        else if constexpr( std::is_same_v<T, CursorMovement> )
            return "positioning="s + std::string(magic_enum::enum_name(arg.positioning)) +
            ", x="s + (arg.x ? std::to_string(*arg.x) : "none"s) +
            ", y="s + (arg.y ? std::to_string(*arg.y) : "none"s) ;
        else if constexpr( std::is_same_v<T, DisplayErasure> )
            return "what_to_erase="s + std::string(magic_enum::enum_name(arg.what_to_erase));
        else if constexpr( std::is_same_v<T, LineErasure> )
            return "what_to_erase="s + std::string(magic_enum::enum_name(arg.what_to_erase));
        else if constexpr( std::is_same_v<T, ModeChange> )
            return "mode="s + std::string(magic_enum::enum_name(arg.mode)) +
            ", status=" + (arg.status ? "on" : "off");
        else if constexpr( std::is_same_v<T, DeviceReport> )
            return "mode="s + std::string(magic_enum::enum_name(arg.mode));
        else if constexpr( std::is_same_v<T, ScrollingRegion> )
            return "range=" + (arg.range ?
                ( std::to_string(arg.range->top) + "," + std::to_string(arg.range->bottom)) :
                "none" );
        else if constexpr( std::is_same_v<T, TabClear> )
            return "mode="s + std::string(magic_enum::enum_name(arg.mode));
        else if constexpr( std::is_same_v<T, CharacterAttributes> )
            return "mode="s + std::string(magic_enum::enum_name(arg.mode));
        else if constexpr( std::is_same_v<T, CharacterSetDesignation> )
            return "target="s = std::to_string(arg.target) +
                ", set=" + std::string(magic_enum::enum_name(arg.set));        
        else
            static_assert(always_false_v<T>, "non-exhaustive visitor!");
    }, _payload);
}

std::string VerboseDescription(const Command & _command)
{
    auto type = ToString(_command.type);
    auto payload = ToString(_command.payload);
    if( payload.empty() )
        return type;
    else
        return type + ", " + payload;
}

void PrintCommands(std::span<const Command> _commands, std::ostream &_out)
{
    for( auto &cmd: _commands )
        _out << VerboseDescription(cmd) << "\n";
    _out.flush();
}

std::string FormatRawInput(std::span<const std::byte>  _input)
{
    std::string formatted;
    formatted.reserve(_input.size());
    for( const auto c : _input ) {
        const auto byte = static_cast<unsigned char>(c);
        if( byte < 32 ) {
            constexpr const char h[16] = {
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
            formatted += "\\x";
            formatted += h[(byte & 0xF0) >> 4];
            formatted += h[byte & 0xF];
        } else {
            formatted += byte;
        }
    }
    return formatted;
}

}
