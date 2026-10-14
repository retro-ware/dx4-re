//! Terminal backend: draws the cell grid with crossterm (true colour, DX palette) and turns terminal events
//! into DX keys and mouse state.

use crate::keys::*;
use crate::{Cell, MouseState, PALETTE};
use crossterm::event::{
    self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers, MouseButton, MouseEvent, MouseEventKind,
};
use crossterm::style::{Color, Print, SetBackgroundColor, SetForegroundColor};
use crossterm::{cursor, execute, queue, terminal};
use std::io::{self, Write};
use std::time::{Duration, Instant};

pub struct Term {
    last: Vec<Cell>,
    last_size: (i32, i32),
    last_origin: (i32, i32),
    last_click: Option<(Instant, i32, i32)>,
    active: bool,
}

fn rgb(i: u8) -> Color {
    let (r, g, b) = PALETTE[(i & 15) as usize];
    Color::Rgb { r, g, b }
}

impl Term {
    pub fn open() -> io::Result<Term> {
        let mut t = Term { last: vec![], last_size: (0, 0), last_origin: (0, 0), last_click: None, active: false };
        t.resume();
        Ok(t)
    }

    pub fn resume(&mut self) {
        if self.active {
            return;
        }
        let _ = terminal::enable_raw_mode();
        let _ = execute!(io::stdout(), terminal::EnterAlternateScreen, event::EnableMouseCapture, cursor::Hide);
        self.last.clear();
        self.active = true;
    }

    pub fn suspend(&mut self) {
        if !self.active {
            return;
        }
        let _ = execute!(
            io::stdout(),
            crossterm::style::ResetColor,
            event::DisableMouseCapture,
            terminal::LeaveAlternateScreen,
            cursor::Show
        );
        let _ = terminal::disable_raw_mode();
        self.active = false;
    }

    pub fn size(&self) -> (i32, i32) {
        terminal::size().map_or((80, 25), |(w, h)| (w as i32, h as i32))
    }

    /// Where the logical screen's top-left cell is (0-based terminal coordinates).
    fn origin(&self, cols: i32, rows: i32) -> (i32, i32) {
        let (w, h) = self.size();
        (((w - cols) / 2).max(0), ((h - rows) / 2).max(0))
    }

    pub fn draw(&mut self, cells: &[Cell], cols: i32, rows: i32, cur: Option<(i32, i32)>) -> io::Result<()> {
        if !self.active {
            return Ok(());
        }
        let size = self.size();
        let origin = self.origin(cols, rows);
        let mut out = io::stdout().lock();
        if size != self.last_size || origin != self.last_origin || self.last.len() != cells.len() {
            queue!(out, SetBackgroundColor(rgb(0)), terminal::Clear(terminal::ClearType::All))?;
            self.last = vec![0xFFFF; cells.len()];
            self.last_size = size;
            self.last_origin = origin;
        }
        let (w, h) = size;
        let mut attr = None;
        for y in 0..rows.min(h - origin.1) {
            let mut x = 0;
            while x < cols.min(w - origin.0) {
                let i = (y * cols + x) as usize;
                if self.last[i] == cells[i] {
                    x += 1;
                    continue;
                }
                queue!(out, cursor::MoveTo((origin.0 + x) as u16, (origin.1 + y) as u16))?;
                let mut s = String::new();
                while x < cols.min(w - origin.0) {
                    let i = (y * cols + x) as usize;
                    if self.last[i] == cells[i] {
                        break;
                    }
                    let a = (cells[i] >> 8) as u8;
                    if attr != Some(a) {
                        if !s.is_empty() {
                            queue!(out, Print(std::mem::take(&mut s)))?;
                        }
                        let bg = (a >> 4) & 7 | if a & 0x80 != 0 { 8 } else { 0 };
                        queue!(out, SetForegroundColor(rgb(a & 15)), SetBackgroundColor(rgb(bg)))?;
                        attr = Some(a);
                    }
                    s.push(crate::glyph::glyph(cells[i] as u8));
                    self.last[i] = cells[i];
                    x += 1;
                }
                queue!(out, Print(s))?;
            }
        }
        match cur {
            Some((x, y)) => queue!(out, cursor::MoveTo((origin.0 + x - 1) as u16, (origin.1 + y - 1) as u16), cursor::Show)?,
            None => queue!(out, cursor::Hide)?,
        }
        out.flush()
    }

    /// Waits up to `wait_ms` for an event. Keys are returned; mouse events update `m`.
    pub fn poll(&mut self, wait_ms: u64, m: &mut MouseState, cols: i32, rows: i32) -> Option<Key> {
        if !event::poll(Duration::from_millis(wait_ms)).ok()? {
            return None;
        }
        match event::read().ok()? {
            Event::Key(k) if k.kind != KeyEventKind::Release => translate(k),
            Event::Mouse(e) => {
                self.mouse(e, m, cols, rows);
                None
            }
            Event::Resize(..) => {
                self.last.clear();
                None
            }
            _ => None,
        }
    }

    fn mouse(&mut self, e: MouseEvent, m: &mut MouseState, cols: i32, rows: i32) {
        let (ox, oy) = self.origin(cols, rows);
        m.x = (e.column as i32 - ox + 1).clamp(1, cols);
        m.y = (e.row as i32 - oy + 1).clamp(1, rows);
        m.idle = 0;
        match e.kind {
            MouseEventKind::Down(b) => {
                m.button = if b == MouseButton::Right { 2 } else { 1 };
                if b == MouseButton::Left {
                    let now = Instant::now();
                    m.double = matches!(self.last_click, Some((t, x, y))
                        if x == m.x && y == m.y && now.duration_since(t) < Duration::from_millis(400));
                    self.last_click = Some((now, m.x, m.y));
                }
            }
            MouseEventKind::Up(_) => m.button = 0,
            _ => {}
        }
    }
}

impl Drop for Term {
    fn drop(&mut self) {
        self.suspend();
    }
}

/// A crossterm key as DX key code.
pub fn translate(k: KeyEvent) -> Option<Key> {
    let alt = k.modifiers.contains(KeyModifiers::ALT);
    let ctrl = k.modifiers.contains(KeyModifiers::CONTROL);
    let shift = k.modifiers.contains(KeyModifiers::SHIFT);
    let nav = |plain: u16, c: u16| if ctrl { c } else { plain };
    let code = match k.code {
        KeyCode::Esc => ESC,
        KeyCode::Enter if ctrl => 10,
        KeyCode::Enter => ENTER,
        KeyCode::Tab => TAB,
        KeyCode::BackTab => SHIFT_TAB,
        KeyCode::Backspace => BKSP,
        KeyCode::Up => UP,
        KeyCode::Down => DOWN,
        KeyCode::Left => nav(LEFT, CTRL_LEFT),
        KeyCode::Right => nav(RIGHT, CTRL_RIGHT),
        KeyCode::Home => nav(HOME, CTRL_HOME),
        KeyCode::End => nav(END, CTRL_END),
        KeyCode::PageUp => nav(PGUP, CTRL_PGUP),
        KeyCode::PageDown => nav(PGDN, CTRL_PGDN),
        KeyCode::Insert => INS,
        KeyCode::Delete => DEL,
        KeyCode::F(n @ 1..=10) => f_key(n as u16, shift, ctrl, alt),
        KeyCode::F(11) => F11,
        KeyCode::F(12) => F12,
        KeyCode::Char(c) if alt && c.is_ascii_alphabetic() => alt_letter(c)?,
        KeyCode::Char(c) if alt && c.is_ascii_digit() => alt_digit(c as u8 - b'0'),
        KeyCode::Char(c) if ctrl && c.is_ascii_alphabetic() => (c.to_ascii_lowercase() as u8 - b'a' + 1) as u16,
        KeyCode::Char(c) => *crate::cp437::encode(&c.to_string()).first()? as u16,
        _ => return None,
    };
    Some(Key { code, alt, shift, ctrl })
}
