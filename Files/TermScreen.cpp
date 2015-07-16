//
//  TermScreen.cpp
//  TermPlays
//
//  Created by Michael G. Kazakov on 17.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "TermScreen.h"
#include "FontCache.h"
#include "OrthodoxMonospace.h"

TermScreen::TermScreen(unsigned _w, unsigned _h):
    m_Buffer(_w, _h)
{
    GoToDefaultPosition();
}

void TermScreen::PutString(const string &_str)
{
    for(auto c:_str)
        PutCh(c);
}

void TermScreen::PutCh(uint32_t _char)
{
//    if(_char >= 32 && _char < 127)
//        printf("%c", _char);
    
    auto line = m_Buffer.LineFromNo(m_PosY);
    if( !line )
        return;
    
    auto chars = begin(line);
    
    if( !oms::IsUnicodeCombiningCharacter(_char) ) {
        if( chars + m_PosX < end(line) ) {
            auto sp = m_EraseChar;
            sp.l = _char;
            // sp.c1 == 0
            // sp.c2 == 0
            chars[m_PosX++] = sp;
            
            if(oms::WCWidthMin1(_char) == 2 &&
               chars + m_PosX < end(line) ) {
                sp.l = MultiCellGlyph;
                chars[m_PosX++] = sp;
            }
        }
    }
    else { // combining characters goes here
        if(m_PosX > 0 &&
           chars + m_PosX < end(line) ) {
            int target_pos = m_PosX - 1;
            if((chars[target_pos].l == MultiCellGlyph) && (target_pos > 0)) target_pos--;
            if(chars[target_pos].c1 == 0) chars[target_pos].c1 = _char;
            else if(chars[target_pos].c2 == 0) chars[target_pos].c2 = _char;
        }
    }
    
    m_Buffer.SetLineWrapped(m_PosY, false); // do we need it EVERY time?????
}

void TermScreen::PutWrap()
{
    // TODO: optimize it out
//    assert(m_PosY < m_Screen.size());
//    GetLineRW(m_PosY)->wrapped = true;
    m_Buffer.SetLineWrapped(m_PosY, true);
}

// ED – Erase Display	Clears part of the screen.
//    If n is zero (or missing), clear from cursor to end of screen.
//    If n is one, clear from beginning of the screen to cursor.
//    If n is two, clear entire screen (and moves cursor to upper left on DOS ANSI.SYS).
void TermScreen::DoEraseScreen(int _mode)
{
    if(_mode == 1) {
        for(int i = 0; i < Height(); ++i) {
            auto l = m_Buffer.LineFromNo(i);
            if(i != m_PosY)
                fill(begin(l), end(l), m_EraseChar);
            else {
                fill(begin(l), min( begin(l)+m_PosX, end(l) ), m_EraseChar);
                return;
            }
            m_Buffer.SetLineWrapped(i, false);
        }
    } else if(_mode == 2)
    { // clear all screen
        for(int i = 0; i < Height(); ++i) {
            auto l = m_Buffer.LineFromNo(i);
            fill(begin(l), end(l), m_EraseChar);
            m_Buffer.SetLineWrapped(i, false);
        }
    } else {
        for(int i = m_PosY; i < Height(); ++i) {
            m_Buffer.SetLineWrapped(i, false);
            auto chars = m_Buffer.LineFromNo(i).first;
            for(int j = (i == m_PosY ? m_PosX : 0); j < Width(); ++j)
                chars[j] = m_EraseChar;
        }
    }
}

void TermScreen::GoTo(int _x, int _y)
{
    // any cursor movement which change Y should end here!
    
    m_PosX = _x;
    m_PosY = _y;
    if(m_PosX < 0) m_PosX = 0;
    if(m_PosX >= Width()) m_PosX = Width() - 1;
    if(m_PosY < 0) m_PosY = 0;
    if(m_PosY >= Height()) m_PosY = Height() - 1;
}

void TermScreen::DoCursorUp(int _n)
{
    GoTo(m_PosX, m_PosY-_n);
}

void TermScreen::DoCursorDown(int _n)
{
    GoTo(m_PosX, m_PosY+_n);
}

void TermScreen::DoCursorLeft(int _n)
{
    GoTo(m_PosX-_n, m_PosY);
}

void TermScreen::DoCursorRight(int _n)
{
    GoTo(m_PosX+_n, m_PosY);
}

//void TermScreen::DoLineFeed()
//{
//    if(m_PosY == m_Height - 1)
//        ScrollBufferUp();
//    else
//        DoCursorDown(1);
    
    /*
#define lf() do { \
if (y+1==bottom) \
{ \
scrup(foo,top,bottom,1,(top==0 && bottom==height)?YES:NO); \
} \
else if (y<height-1) \
{ \
y++; \
[ts ts_goto: x:y]; \
} \
} while (0)
*/

    
//}

/*void TermScreen::DoCarriageReturn()
{
    GoTo(0, m_PosY);
}*/

void TermScreen::EraseInLine(int _mode)
{
    // If n is zero (or missing), clear from cursor to the end of the line.
    // If n is one, clear from cursor to beginning of the line.
    // If n is two, clear entire line.
    // Cursor position does not change.
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto i = begin(line);
    auto e = end(line);
    if(_mode == 0)
        i = min( i + m_PosX, e );
    else if(_mode == 1)
        e = min( i + m_PosX + 1, e );
    fill(i, e, m_EraseChar);
}

void TermScreen::EraseInLineCount(unsigned _n)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto i = begin(line) + m_PosX;
    auto e = min( i + _n, end(line) );
    fill(i, e, m_EraseChar);
}

void TermScreen::SetFgColor(int _color)
{
    m_EraseChar.foreground = _color;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void TermScreen::SetBgColor(int _color)
{
    m_EraseChar.background = _color;
    m_Buffer.SetEraseChar(m_EraseChar);    
}

void TermScreen::SetIntensity(bool _intensity)
{
    m_EraseChar.intensity = _intensity;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void TermScreen::SetUnderline(bool _is_underline)
{
    m_EraseChar.underline = _is_underline;
    m_Buffer.SetEraseChar(m_EraseChar);
}

void TermScreen::SetReverse(bool _is_reverse)
{
    m_EraseChar.reverse = _is_reverse;
    m_Buffer.SetEraseChar(m_EraseChar);    
}

void TermScreen::SetAlternateScreen(bool _is_alternate)
{
    m_AlternateScreen = _is_alternate;
}

void TermScreen::DoShiftRowLeft(int _chars)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto chars = line.first;
    
    // TODO: write as an algo
    
    for(int x = m_PosX + _chars; x < Width(); ++x)
        chars[x-_chars] = chars[x];
    
    for(int i = 0; i < _chars; ++i)
        chars[Width()-i-1] = m_EraseChar; // why m_Width here???
    
}

void TermScreen::DoShiftRowRight(int _chars)
{
    auto line = m_Buffer.LineFromNo(m_PosY);
    if(!line)
        return;
    auto chars = line.first;
    
    // TODO: write as an algo
    
    for(int x = Width()-1; x >= m_PosX + _chars; --x)
        chars[x] = chars[x - _chars];
    
    for(int i = 0; i < _chars; ++i)
        chars[m_PosX + i] = m_EraseChar;
}

void TermScreen::EraseAt(unsigned _x, unsigned _y, unsigned _count)
{
    if( auto line = m_Buffer.LineFromNo(_y) ) {
        auto i = begin(line) + _x;
        auto e = min( i + _count, end(line) );
        fill(i, e, m_EraseChar);
    }
}

void TermScreen::CopyLineChars(int _from, int _to)
{
    auto src = m_Buffer.LineFromNo(_from);
    auto dst = m_Buffer.LineFromNo(_to);
    if(src && dst)
        copy_n(begin(src),
               min(end(src) - begin(src), end(dst) - begin(dst)),
               begin(dst));
}

void TermScreen::ClearLine(int _ind)
{
    if( auto line = m_Buffer.LineFromNo(_ind) ) {
        fill( begin(line), end(line), m_EraseChar );
        m_Buffer.SetLineWrapped(_ind, false);
    }
}

void TermScreen::ScrollDown(unsigned _top, unsigned _bottom, unsigned _lines)
{
    if(_bottom > Height())
        _bottom = Height();
    if(_top >= Height())
        return;
    if(_top >= _bottom)
        return;
    if(_lines<1)
        return;
    
    for( int n_dst = _bottom - 1, n_src = _bottom - 1 - _lines;
        n_dst > 0 && n_src >= 0;
        --n_dst, --n_src) {
        CopyLineChars(n_src, n_dst);
        m_Buffer.SetLineWrapped(n_dst, m_Buffer.LineWrapped(n_src));        
    }
    
    for(int i = _top; i < min(_top + _lines, _bottom); ++i)
        ClearLine(i);
}

void TermScreen::DoScrollUp(unsigned _top, unsigned _bottom, unsigned _lines)
{
    if(_bottom > Height())
        _bottom = Height();
    if(_top >= Height())
        return;
    if(_top >= _bottom)
        return;
    if(_lines<1)
        return;

    if(_top == 0 && _bottom == Height() && !m_AlternateScreen)
        for(int i = 0; i < min(_lines, (unsigned)Height()); ++i) {
            // we're scrolling up the whole screen - let's feed scrollback with leftover
            auto line = m_Buffer.LineFromNo(i);
            assert(line);
            m_Buffer.FeedBackscreen(begin(line),
                                    end(line),
                                    m_Buffer.LineWrapped(i));
        }
    
    for( int n_src = _top + _lines, n_dst = _top;
        n_src < _bottom && n_dst < _bottom;
        ++n_src, ++n_dst ) {
        CopyLineChars(n_src, n_dst);
        m_Buffer.SetLineWrapped(n_dst, m_Buffer.LineWrapped(n_src));
    }
    
    for( int i = _bottom - 1; i >= max( (int)_bottom-(int)_lines, 0); --i)
        ClearLine(i);
}

void TermScreen::SaveScreen()
{
    m_Buffer.MakeSnapshot();
}

void TermScreen::RestoreScreen()
{
    m_Buffer.RevertToSnapshot();
}

void TermScreen::ResizeScreen(unsigned _new_sx, unsigned _new_sy)
{
    if(Width() == _new_sx && Height() == _new_sy)
        return;
    if( _new_sx == 0 || _new_sy == 0 )
        throw invalid_argument("TermScreen::ResizeScreen sizes can't be zero");
    
    Lock();

    bool feed_from_bs = m_PosY == Height() - 1; // questionable!
    
    m_Buffer.ResizeScreen(_new_sx, _new_sy, feed_from_bs && !m_AlternateScreen);
    
    // adjust cursor Y if it was at the bottom prior to resizing
    GoTo(CursorX(), feed_from_bs ? Height() - 1 : CursorY()); // will clip if necessary
    
    Unlock();
}

void TermScreen::SetTitle(const char *_t)
{
    m_Title = _t;
}

void TermScreen::GoToDefaultPosition()
{
    GoTo(0, 0);
}