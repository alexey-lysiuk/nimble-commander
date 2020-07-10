// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <InterpreterImpl.h>
#include "Tests.h"

using namespace nc::term;
using namespace nc::term::input;
#define PREFIX "nc::term::Interpreter "

TEST_CASE(PREFIX"does call the Bell callback")
{        
    Screen screen(10, 6);
    InterpreterImpl interpreter(screen);
    bool did_bell = false;
    interpreter.SetBell([&]{ did_bell = true; });

    const Command cmd{input::Type::bell};
    interpreter.Interpret( {&cmd, 1} );
    CHECK( did_bell == true ); 
}

TEST_CASE(PREFIX"resizes screen only when allowed")
{
    Screen screen(10, 6);
    InterpreterImpl interpreter(screen);
    SECTION("Allowed - default") {
        SECTION("80") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, false}};
            interpreter.Interpret( {&cmd, 1} );
            CHECK( screen.Width() == 80 );
            CHECK( screen.Height() == 6 );
        }
        SECTION("132") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, true}};
            interpreter.Interpret( {&cmd, 1} );
            CHECK( screen.Width() == 132 );
            CHECK( screen.Height() == 6 );
        }
    }
    SECTION("Disabled") {
        interpreter.SetScreenResizeAllowed(false);
        SECTION("80") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, false}};
            interpreter.Interpret( {&cmd, 1} );
        }
        SECTION("132") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, true}};
            interpreter.Interpret( {&cmd, 1} );
        }
        CHECK( screen.Width() == 10 );
        CHECK( screen.Height() == 6 );
    }
}

TEST_CASE(PREFIX"setting normal attributes")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Faint}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::ForegroundRed}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::BackgroundBlue}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Inverse}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Bold}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Italicized}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Invisible}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Blink}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Underlined}));
    
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Normal}));
    interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
    
    const auto c = screen.Buffer().At(0, 0);
    CHECK( c.foreground == ScreenColors::Default );
    CHECK( c.background == ScreenColors::Default );
    CHECK( c.intensity == true );
    CHECK( c.reverse == false );
    CHECK( c.bold == false );
    CHECK( c.italic == false );
    CHECK( c.invisible == false );
    CHECK( c.blink == false );
    CHECK( c.underline == false );
}

TEST_CASE(PREFIX"setting foreground colors")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, std::uint8_t _color) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).foreground == _color );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).foreground == ScreenColors::Default );
    }
    SECTION("Black") {
        verify(CA::ForegroundBlack, ScreenColors::Black);
    }
    SECTION("Red") {
        verify(CA::ForegroundRed, ScreenColors::Red);
    }
    SECTION("Green") {
        verify(CA::ForegroundGreen, ScreenColors::Green);
    }
    SECTION("Yellow") {
        verify(CA::ForegroundYellow, ScreenColors::Yellow);
    }
    SECTION("Blue") {
        verify(CA::ForegroundBlue, ScreenColors::Blue);
    }
    SECTION("Magenta") {
        verify(CA::ForegroundMagenta, ScreenColors::Magenta);
    }
    SECTION("Cyan") {
        verify(CA::ForegroundCyan, ScreenColors::Cyan);
    }
    SECTION("White") {
        verify(CA::ForegroundWhite, ScreenColors::White);
    }
    SECTION("Default") {
        verify(CA::ForegroundDefault, ScreenColors::Default);
    }
}

TEST_CASE(PREFIX"setting background colors")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, std::uint8_t _color) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).background == _color );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).background == ScreenColors::Default );
    }
    SECTION("Black") {
        verify(CA::BackgroundBlack, ScreenColors::Black);
    }
    SECTION("Red") {
        verify(CA::BackgroundRed, ScreenColors::Red);
    }
    SECTION("Green") {
        verify(CA::BackgroundGreen, ScreenColors::Green);
    }
    SECTION("Yellow") {
        verify(CA::BackgroundYellow, ScreenColors::Yellow);
    }
    SECTION("Blue") {
        verify(CA::BackgroundBlue, ScreenColors::Blue);
    }
    SECTION("Magenta") {
        verify(CA::BackgroundMagenta, ScreenColors::Magenta);
    }
    SECTION("Cyan") {
        verify(CA::BackgroundCyan, ScreenColors::Cyan);
    }
    SECTION("White") {
        verify(CA::BackgroundWhite, ScreenColors::White);
    }
    SECTION("Default") {
        verify(CA::BackgroundDefault, ScreenColors::Default);
    }
}

TEST_CASE(PREFIX"setting faint")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _intensity) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).intensity == _intensity );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).intensity == true );
    }
    SECTION("Normal") {
        verify(CA::Normal, true);
    }
    SECTION("Faint") {
        verify(CA::Faint, false);
    }
    SECTION("Not Bold Not Faint") {
        verify(CA::NotBoldNotFaint, true);
    }
}

TEST_CASE(PREFIX"setting inverse")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _inverse) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).reverse == _inverse );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).reverse == false );
    }
    SECTION("Inverse") {
        verify(CA::Inverse, true);
    }
    SECTION("Not inverse") {
        verify(CA::NotInverse, false);
    }
}

TEST_CASE(PREFIX"setting bold")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _bold) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).bold == _bold );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).bold == false );
    }
    SECTION("Bold") {
        verify(CA::Bold, true);
    }
    SECTION("Not bold") {
        verify(CA::NotBoldNotFaint, false);
    }
}

TEST_CASE(PREFIX"setting italic")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _italic) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).italic == _italic );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).italic == false );
    }
    SECTION("Italic") {
        verify(CA::Italicized, true);
    }
    SECTION("Not italic") {
        verify(CA::NotItalicized, false);
    }
}

TEST_CASE(PREFIX"setting invisible")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _invisible) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).invisible == _invisible );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).invisible == false );
    }
    SECTION("Invisible") {
        verify(CA::Invisible, true);
    }
    SECTION("Not invsible") {
        verify(CA::NotInvisible, false);
    }
}

TEST_CASE(PREFIX"setting blink")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _blink) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).blink == _blink );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).blink == false );
    }
    SECTION("Blink") {
        verify(CA::Blink, true);
    }
    SECTION("Not blink") {
        verify(CA::NotBlink, false);
    }
}

TEST_CASE(PREFIX"setting underline")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _underline) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).underline == _underline );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).underline == false );
    }
    SECTION("Underline") {
        verify(CA::Underlined, true);
    }
    SECTION("Doubly Underline") {
        verify(CA::DoublyUnderlined, true);
    }
    SECTION("Not underlined") {
        verify(CA::NotUnderlined, false);
    }
}
