//! Text-mode screen shared by the DOS-Expander ports.
//!
//! `Crt` holds a grid of (character, attribute) cells like VGA text memory and offers the Turbo Pascal Crt
//! calls the original code is written against (Window, GotoXY, Write, TextColor, ...) plus the helpers of
//! the DX `Screen` unit. Characters are code page 437 bytes; attributes are DOS attributes (bits 0-3
//! foreground, 4-6 background, bit 7 bright background, as DX switches blinking off). The terminal backend
//! (`term`) draws the grid with the DX palette and maps the bytes to Unicode (`glyph`).
//!
//! Coordinates are 1-based like in Pascal. The logical screen is normally 80x25; a program may resize it
//! to the terminal size. A terminal larger than the logical screen shows it centred.

pub mod button;
pub mod cp437;
pub mod glyph;
pub mod help;
pub mod keys;
pub mod list;
pub mod saver;
pub mod menubar;
pub mod settings;
pub mod term;
pub mod time;
pub mod ui;

pub use keys::*;

/// A cell: attribute in the high byte, character in the low byte (as a word in B800).
pub type Cell = u16;

/// RGB of the 16 DX colours (Palette.Pal1, 6-bit DAC values scaled to 8 bit).
pub const PALETTE: [(u8, u8, u8); 16] = {
    const P: [(u8, u8, u8); 16] = [
        (0, 0, 0), (0, 0, 42), (63, 63, 63), (0, 42, 42), (42, 0, 0), (51, 41, 31), (0, 38, 36), (42, 42, 42),
        (21, 21, 21), (21, 21, 63), (21, 63, 21), (21, 63, 63), (63, 21, 21), (63, 21, 63), (63, 63, 21),
        (63, 63, 63),
    ];
    let mut out = [(0, 0, 0); 16];
    let mut i = 0;
    while i < 16 {
        out[i] = (scale(P[i].0), scale(P[i].1), scale(P[i].2));
        i += 1;
    }
    out
};

const fn scale(v: u8) -> u8 {
    ((v as u16 * 255 + 31) / 63) as u8
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct WinState {
    pub x1: i32,
    pub y1: i32,
    pub x2: i32,
    pub y2: i32,
    pub attr: u8,
    pub cx: i32,
    pub cy: i32,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct MouseState {
    /// 1-based cell position on the logical screen.
    pub x: i32,
    pub y: i32,
    /// 0 none, 1 left, 2 right (as the DX Mouse unit).
    pub button: i32,
    /// Seconds-ish idle counter, reset by any input (Mouse.MouseMoved).
    pub idle: i32,
    /// Set by a double click (left button) until read.
    pub double: bool,
    /// Wheel notches not yet handled (negative up, positive down).
    pub wheel: i32,
}

pub struct Crt {
    cols: i32,
    rows: i32,
    cells: Vec<Cell>,
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
    cx: i32,
    cy: i32,
    pub text_attr: u8,
    pub cursor_visible: bool,
    pub mouse: MouseState,
    pub alt: bool,
    pub shift: bool,
    pub ctrl: bool,
    pub term: Option<term::Term>,
    /// Keys queued for tests (and script playback); consumed before the terminal is asked.
    pub queue: std::collections::VecDeque<Key>,
    /// Screens recorded by queued `SNAPSHOT` keys (scripted tests).
    pub snaps: Vec<Vec<Cell>>,
}

impl Crt {
    /// A screen without terminal (tests, screen dumps).
    pub fn new(cols: i32, rows: i32) -> Crt {
        Crt {
            cols,
            rows,
            cells: vec![0x0720; (cols * rows) as usize],
            x1: 1,
            y1: 1,
            x2: cols,
            y2: rows,
            cx: 1,
            cy: 1,
            text_attr: 7,
            cursor_visible: false,
            mouse: MouseState { x: cols / 2 + 1, y: rows / 2 + 1, ..Default::default() },
            alt: false,
            shift: false,
            ctrl: false,
            term: None,
            queue: Default::default(),
            snaps: vec![],
        }
    }

    /// A screen shown in the terminal (alternate screen, raw mode, mouse capture).
    pub fn open(cols: i32, rows: i32) -> std::io::Result<Crt> {
        let mut c = Crt::new(cols, rows);
        c.term = Some(term::Term::open()?);
        Ok(c)
    }

    pub fn cols(&self) -> i32 {
        self.cols
    }

    pub fn rows(&self) -> i32 {
        self.rows
    }

    /// Changes the logical screen size; contents are kept where they fit, the window is reset.
    pub fn resize(&mut self, cols: i32, rows: i32) {
        let mut n = vec![0x0720; (cols * rows) as usize];
        for y in 0..rows.min(self.rows) {
            for x in 0..cols.min(self.cols) {
                n[(y * cols + x) as usize] = self.cells[(y * self.cols + x) as usize];
            }
        }
        self.cells = n;
        self.cols = cols;
        self.rows = rows;
        self.window(1, 1, cols, rows);
    }

    // --- raw cell access (Mem[$B800:...]) ---

    fn idx(&self, x: i32, y: i32) -> Option<usize> {
        (x >= 1 && y >= 1 && x <= self.cols && y <= self.rows).then(|| ((y - 1) * self.cols + x - 1) as usize)
    }

    pub fn peek(&self, x: i32, y: i32) -> Cell {
        self.idx(x, y).map_or(0, |i| self.cells[i])
    }

    pub fn poke(&mut self, x: i32, y: i32, c: Cell) {
        if let Some(i) = self.idx(x, y) {
            self.cells[i] = c;
        }
    }

    pub fn poke_attr(&mut self, x: i32, y: i32, a: u8) {
        if let Some(i) = self.idx(x, y) {
            self.cells[i] = (self.cells[i] & 0xFF) | (a as u16) << 8;
        }
    }

    pub fn poke_char(&mut self, x: i32, y: i32, ch: u8) {
        if let Some(i) = self.idx(x, y) {
            self.cells[i] = (self.cells[i] & 0xFF00) | ch as u16;
        }
    }

    pub fn cells(&self) -> &[Cell] {
        &self.cells
    }

    /// The whole screen (ScrSave).
    pub fn save(&self) -> Vec<Cell> {
        self.cells.clone()
    }

    pub fn restore(&mut self, s: &[Cell]) {
        if s.len() == self.cells.len() {
            self.cells.copy_from_slice(s);
        }
    }

    /// A rectangle of cells (1-based, inclusive), for popups that restore what they covered.
    pub fn save_rect(&self, x1: i32, y1: i32, x2: i32, y2: i32) -> Vec<Cell> {
        let mut v = vec![];
        for y in y1..=y2 {
            for x in x1..=x2 {
                v.push(self.peek(x, y));
            }
        }
        v
    }

    pub fn restore_rect(&mut self, x1: i32, y1: i32, x2: i32, y2: i32, v: &[Cell]) {
        let mut it = v.iter();
        for y in y1..=y2 {
            for x in x1..=x2 {
                if let Some(&c) = it.next() {
                    self.poke(x, y, c);
                }
            }
        }
    }

    // --- Crt ---

    pub fn window(&mut self, x1: i32, y1: i32, x2: i32, y2: i32) {
        let (x2, y2) = (x2.min(self.cols), y2.min(self.rows));
        if x1 < 1 || y1 < 1 || x1 > x2 || y1 > y2 {
            return;
        }
        (self.x1, self.y1, self.x2, self.y2) = (x1, y1, x2, y2);
        self.cx = 1;
        self.cy = 1;
    }

    /// WindMin/WindMax as 1-based (x1, y1, x2, y2).
    pub fn win(&self) -> (i32, i32, i32, i32) {
        (self.x1, self.y1, self.x2, self.y2)
    }

    pub fn goto_xy(&mut self, x: i32, y: i32) {
        if x >= 1 && y >= 1 && x <= self.x2 - self.x1 + 1 && y <= self.y2 - self.y1 + 1 {
            self.cx = x;
            self.cy = y;
        }
    }

    pub fn where_x(&self) -> i32 {
        self.cx
    }

    pub fn where_y(&self) -> i32 {
        self.cy
    }

    pub fn clr_scr(&mut self) {
        let c = self.blank();
        for y in self.y1..=self.y2 {
            for x in self.x1..=self.x2 {
                self.poke(x, y, c);
            }
        }
        self.cx = 1;
        self.cy = 1;
    }

    pub fn clr_eol(&mut self) {
        let c = self.blank();
        let y = self.y1 + self.cy - 1;
        for x in self.x1 + self.cx - 1..=self.x2 {
            self.poke(x, y, c);
        }
    }

    fn blank(&self) -> Cell {
        (self.text_attr as u16) << 8 | 0x20
    }

    pub fn text_color(&mut self, c: u8) {
        let c = if c & 0xF0 != 0 { c & 0x0F | 0x80 } else { c };
        self.text_attr = self.text_attr & 0x70 | c;
    }

    pub fn text_background(&mut self, c: u8) {
        self.text_attr = self.text_attr & 0x8F | (c & 7) << 4;
    }

    fn scroll_up(&mut self) {
        for y in self.y1..self.y2 {
            for x in self.x1..=self.x2 {
                let c = self.peek(x, y + 1);
                self.poke(x, y, c);
            }
        }
        let c = self.blank();
        for x in self.x1..=self.x2 {
            self.poke(x, self.y2, c);
        }
    }

    fn newline(&mut self) {
        self.cx = 1;
        if self.y1 + self.cy - 1 >= self.y2 {
            self.scroll_up();
        } else {
            self.cy += 1;
        }
    }

    /// Write of CP437 bytes with Crt semantics (wrap at the window edge, scroll at its bottom).
    pub fn write_b(&mut self, s: &[u8]) {
        for &b in s {
            match b {
                7 => {}
                8 => self.cx = (self.cx - 1).max(1),
                10 => {
                    if self.y1 + self.cy - 1 >= self.y2 {
                        self.scroll_up();
                    } else {
                        self.cy += 1;
                    }
                }
                13 => self.cx = 1,
                _ => {
                    // The wrap is deferred to the next character, so filling the last cell of a window does not
                    // scroll it (DOS would; DX avoided that by poking the corner).
                    if self.x1 + self.cx - 1 > self.x2 {
                        self.newline();
                    }
                    let a = self.text_attr as u16;
                    self.poke(self.x1 + self.cx - 1, self.y1 + self.cy - 1, a << 8 | b as u16);
                    self.cx += 1;
                }
            }
        }
    }

    /// Write of a Unicode string (encoded to CP437).
    pub fn write(&mut self, s: &str) {
        self.write_b(&cp437::encode(s));
    }

    // --- DX Screen unit ---

    pub fn set_color(&mut self, fg: u8, bg: u8) {
        self.text_color(fg);
        self.text_background(bg);
    }

    pub fn write_xy(&mut self, x: i32, y: i32, s: &str) {
        self.goto_xy(x, y);
        self.write(s);
    }

    pub fn write_xy_b(&mut self, x: i32, y: i32, s: &[u8]) {
        self.goto_xy(x, y);
        self.write_b(s);
    }

    pub fn write_f(&mut self, fg: u8, s: &str) {
        let a = self.text_attr;
        self.text_color(fg);
        self.write(s);
        self.text_attr = a;
    }

    pub fn write_fb(&mut self, fg: u8, bg: u8, s: &str) {
        let a = self.text_attr;
        self.set_color(fg, bg);
        self.write(s);
        self.text_attr = a;
    }

    pub fn write_xyf(&mut self, x: i32, y: i32, fg: u8, s: &str) {
        let a = self.text_attr;
        self.text_color(fg);
        self.write_xy(x, y, s);
        self.text_attr = a;
    }

    pub fn write_xyb(&mut self, x: i32, y: i32, bg: u8, s: &str) {
        let a = self.text_attr;
        self.text_background(bg);
        self.write_xy(x, y, s);
        self.text_attr = a;
    }

    pub fn write_xyfb(&mut self, x: i32, y: i32, fg: u8, bg: u8, s: &str) {
        let a = self.text_attr;
        self.set_color(fg, bg);
        self.write_xy(x, y, s);
        self.text_attr = a;
    }

    pub fn write_center_xy(&mut self, x: i32, y: i32, w: i32, s: &str) {
        self.goto_xy(x, y);
        self.write(&center(s, w));
    }

    pub fn write_center_xyf(&mut self, x: i32, y: i32, w: i32, fg: u8, s: &str) {
        let a = self.text_attr;
        self.text_color(fg);
        self.write_center_xy(x, y, w, s);
        self.text_attr = a;
    }

    pub fn write_center_xyfb(&mut self, x: i32, y: i32, w: i32, fg: u8, bg: u8, s: &str) {
        let a = self.text_attr;
        self.set_color(fg, bg);
        self.write_center_xy(x, y, w, s);
        self.text_attr = a;
    }

    // --- Windows unit ---

    /// SaveWin: remembers window, colour and cursor, then switches to the full screen.
    pub fn save_win(&mut self) -> WinState {
        let w = self.get_win();
        self.window(1, 1, self.cols, self.rows);
        w
    }

    pub fn get_win(&self) -> WinState {
        WinState { x1: self.x1, y1: self.y1, x2: self.x2, y2: self.y2, attr: self.text_attr, cx: self.cx, cy: self.cy }
    }

    pub fn restore_win(&mut self, w: &WinState) {
        self.window(w.x1, w.y1, w.x2, w.y2);
        self.text_attr = w.attr;
        self.goto_xy(w.cx, w.cy);
    }

    /// SetWin: window and cursor, colour unchanged.
    pub fn set_win(&mut self, w: &WinState) {
        self.window(w.x1, w.y1, w.x2, w.y2);
        self.goto_xy(w.cx, w.cy);
    }

    /// Windows.Frame: a box of inner size `wd`x`ht` whose top-left corner is at (x, y); left and top edge
    /// in `fg`, right and bottom in black (or the other way round with `bright`), optional shadow. Leaves the
    /// window set to the inside, cleared, colour black on `bg`.
    pub fn frame(&mut self, x: i32, y: i32, wd: i32, ht: i32, fg: u8, bg: u8, bright: bool, shadow: bool) {
        let (mut c1, mut c2) = (fg, fg);
        if bright {
            c1 = 0
        } else {
            c2 = 0
        }
        if bg >= 0x80 {
            c1 += 0x80;
            c2 += 0x80;
        }
        self.set_color(c1, bg);
        self.window(x, y, self.cols, self.rows);
        let (tl, tr, bl, br, v, v2) = (0xDA, 0xBF, 0xC0, 0xD9, 0xB3, 0xB3);
        let mut top = vec![tl];
        top.extend(std::iter::repeat_n(0xC4, wd.max(0) as usize));
        self.write_xy_b(1, 1, &top);
        self.write_fb_b(c2, &[tr]);
        for i in 2..=ht + 1 {
            self.write_xy_b(1, i, &[v]);
            let a = self.text_attr;
            self.text_color(c2);
            self.write_xy_b(wd + 2, i, &[v2]);
            self.text_attr = a;
        }
        self.write_xy_b(1, ht + 2, &[bl]);
        self.text_color(c2);
        self.write_b(&vec![0xC4; wd.max(0) as usize]);
        // The corner is poked so that a frame touching the bottom right does not scroll.
        let a = self.text_attr as u16;
        self.poke(x + wd + 1, y + ht + 1, a << 8 | br as u16);
        self.window(x + 1, y + 1, x + wd, y + ht);
        self.clr_scr();
        if shadow {
            self.shadow(x, y, wd, ht);
        }
        self.set_color(0, bg);
    }

    /// The shadow of Frame: attribute 7 under the bottom edge and two columns right of the box.
    pub fn shadow(&mut self, x: i32, y: i32, wd: i32, ht: i32) {
        for i in x + 2..x + wd + 4 {
            self.poke_attr(i, y + ht + 2, 7);
        }
        for i in y + 1..=y + ht + 2 {
            self.poke_attr(x + wd + 2, i, 7);
            self.poke_attr(x + wd + 3, i, 7);
        }
    }

    fn write_fb_b(&mut self, fg: u8, s: &[u8]) {
        let a = self.text_attr;
        self.text_color(fg);
        self.write_b(s);
        self.text_attr = a;
    }

    // --- output and input ---

    /// Draws the screen to the terminal (no-op without one).
    pub fn flush(&mut self) {
        if let Some(t) = self.term.as_mut() {
            let _ = t.draw(&self.cells, self.cols, self.rows, self.cursor_visible.then(|| {
                (self.x1 + self.cx - 1, self.y1 + self.cy - 1)
            }));
        }
    }

    /// Status.GetKey without the idle work: shows the screen, returns a pending key or `None` after a short
    /// wait. Mouse events update `mouse` and return `None`.
    pub fn poll_key(&mut self, wait_ms: u64) -> Option<Key> {
        while self.queue.front().is_some_and(|k| k.code == SNAPSHOT) {
            self.queue.pop_front();
            self.snaps.push(self.cells.clone());
        }
        if let Some(k) = self.queue.pop_front() {
            self.set_mods(&k);
            self.mouse.idle = 0;
            return Some(k);
        }
        self.flush();
        let k = self.term.as_mut().and_then(|t| t.poll(wait_ms, &mut self.mouse, self.cols, self.rows))?;
        self.set_mods(&k);
        self.mouse.idle = 0;
        Some(k)
    }

    fn set_mods(&mut self, k: &Key) {
        self.alt = k.alt;
        self.shift = k.shift;
        self.ctrl = k.ctrl;
    }

    /// Size of the terminal, or of the logical screen without one.
    pub fn term_size(&self) -> (i32, i32) {
        self.term.as_ref().map_or((self.cols, self.rows), |t| t.size())
    }

    /// Leaves the full-screen mode to run another program; `resume` returns.
    pub fn suspend(&mut self) {
        if let Some(t) = self.term.as_mut() {
            t.suspend();
        }
    }

    pub fn resume(&mut self) {
        if let Some(t) = self.term.as_mut() {
            t.resume();
        }
    }

    /// The screen as text, one line per row (tests).
    pub fn text(&self) -> String {
        let mut s = String::new();
        for y in 1..=self.rows {
            for x in 1..=self.cols {
                s.push(glyph::glyph(self.peek(x, y) as u8));
            }
            s.push('\n');
        }
        s
    }
}

/// Screen.Center: `s` centred in `w` columns (extra space on the right).
pub fn center(s: &str, w: i32) -> String {
    let l = s.chars().count() as i32;
    let a = ((w - l) / 2).max(0) as usize;
    let b = ((w - l) % 2).max(0) as usize + a;
    format!("{}{s}{}", " ".repeat(a), " ".repeat(b))
}

/// Screen.PadRight: `s` cut or padded to `n` columns.
pub fn pad_right(s: &str, n: usize) -> String {
    let mut o: String = s.chars().take(n).collect();
    let l = o.chars().count();
    o.extend(std::iter::repeat_n(' ', n - l));
    o
}

/// Screen.LoCase: ASCII and the German umlauts.
pub fn lo_case(c: char) -> char {
    match c {
        'Ä' => 'ä',
        'Ö' => 'ö',
        'Ü' => 'ü',
        _ => c.to_ascii_lowercase(),
    }
}

pub fn up_case(c: char) -> char {
    match c {
        'ä' => 'Ä',
        'ö' => 'Ö',
        'ü' => 'Ü',
        _ => c.to_ascii_uppercase(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frame_matches_original_message_box() {
        // ref/dxm/MAIN.SCR: the message box frame at column 13, row 7, attribute $52 / $50 inside.
        let mut c = Crt::new(80, 25);
        c.frame(13, 7, 55, 8, 2, 5, false, false);
        assert_eq!(c.peek(13, 7), 0x52DA);
        assert_eq!(c.peek(14, 7), 0x52C4);
        assert_eq!(c.peek(69, 7), 0x50BF);
        assert_eq!(c.peek(14, 8), 0x5020);
        assert_eq!(c.peek(13, 16), 0x52C0);
        assert_eq!(c.peek(14, 16), 0x50C4);
    }

    #[test]
    fn write_wraps_and_scrolls() {
        let mut c = Crt::new(10, 3);
        c.window(1, 1, 4, 2);
        c.write("abcdefghij");
        assert_eq!(&c.text()[..4], "efgh");
        assert_eq!(&c.text()[11..15], "ij  ");
    }
}
