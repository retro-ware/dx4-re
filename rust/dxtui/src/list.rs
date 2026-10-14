//! Scrolling list with optional scroll bar (Lists.TList). The text of each entry comes from a closure
//! (the virtual DrawLine of the original); entry numbers are 1-based.

use crate::keys::*;
use crate::ui::Ui;
use std::time::{Duration, Instant};

pub struct List {
    pub count: i32,
    pub rows: i32,
    pub width: i32,
    /// Row of the cursor, 1..=rows
    pub cur: i32,
    pub top: i32,
    pub scroll: bool,
    thumb: i32,
    last_row: i32,
    pub fg: u8,
    pub bg: u8,
    pub sel_fg: u8,
    pub sel_bg: u8,
    /// Screen position of the first row (absolute, 1-based); the list sets the window to start there.
    pub x: i32,
    pub y: i32,
    /// Double click needed to choose an entry by mouse (DXGlob.DblClickSelect).
    pub dbl_click_select: bool,
}

pub type Lines<'a> = &'a dyn Fn(i32) -> String;

impl List {
    /// TList.Init: sets the window to (x, y)-.., draws the entries and the scroll bar.
    #[allow(clippy::too_many_arguments)]
    pub fn new(ui: &mut Ui, fg: u8, bg: u8, sel_fg: u8, sel_bg: u8, x: i32, y: i32, rows: i32, count: i32,
        width: i32, scroll: bool, lines: Lines) -> List {
        let mut l = List {
            count,
            rows,
            width,
            cur: 1,
            top: 0,
            scroll,
            thumb: 0,
            last_row: 0,
            fg,
            bg,
            sel_fg,
            sel_bg,
            x,
            y,
            dbl_click_select: false,
        };
        let (c, r) = (ui.cols(), ui.rows());
        ui.window(x, y, c, r);
        ui.set_color(fg, bg);
        l.draw_all(ui, lines);
        if scroll {
            ui.write_xyfb(width + 1, 1, 2, 0, "\u{2191}");
            ui.write_xyfb(width + 1, 2, 2, 0, "▓");
            for i in 3..rows {
                ui.write_xy(width + 1, i, "░");
            }
            ui.write_xyfb(width + 1, rows, 2, 0, "\u{2193}");
        }
        l
    }

    pub fn pos(&self) -> i32 {
        self.cur + self.top
    }

    pub fn draw_line(&mut self, ui: &mut Ui, line: i32, lines: Lines) {
        let mut w = self.width;
        if self.scroll {
            w -= 1;
        }
        let n = line + self.top;
        let s = if n > 0 && n <= self.count { lines(n) } else { String::new() };
        let line = line.max(1);
        ui.write_xy(1, line, &crate::pad_right(&s, w.max(0) as usize));
        if self.scroll {
            ui.write_f(0, " ");
        }
        self.last_row = 255;
    }

    pub fn show_cur(&mut self, ui: &mut Ui, line: i32, lines: Lines) {
        let a = ui.text_attr;
        ui.text_color(self.sel_fg);
        ui.text_background(self.sel_bg);
        self.draw_line(ui, line, lines);
        ui.text_attr = a;
    }

    fn update_thumb(&mut self, ui: &mut Ui) {
        let mut p = (self.rows - 2) * self.pos() / (self.count + 1) + 1;
        if self.pos() == 1 {
            p = 1;
        }
        if self.pos() >= self.count {
            p = self.rows - 2;
        }
        if self.thumb == p {
            return;
        }
        for i in 2..self.rows {
            ui.write_xy(self.width + 1, i, "░");
        }
        ui.write_xyfb(self.width + 1, p + 1, 2, 0, "▓");
        self.thumb = p;
    }

    fn thumb_mouse(&mut self, ui: &mut Ui, lines: Lines) {
        let m = ui.mouse;
        if m.button == 1 && self.width + self.x == m.x && self.y < m.y && self.y + self.rows - 1 > m.y {
            let mut n = if self.rows != 2 { self.count * (m.y - self.y) / (self.rows - 2) } else { 1 };
            if m.y - self.y == 1 || n <= 1 {
                n = 1;
            }
            if self.last_row != m.y - self.y {
                self.set_pos(ui, n, self.rows / 2, lines);
            }
            self.last_row = m.y - self.y;
        }
    }

    pub fn draw_all(&mut self, ui: &mut Ui, lines: Lines) {
        for i in 1..=self.rows {
            if self.cur != i {
                self.draw_line(ui, i, lines);
            }
        }
        self.show_cur(ui, self.cur, lines);
    }

    /// TList.SetPos: entry `pos` at screen row `row` (as far as possible).
    pub fn set_pos(&mut self, ui: &mut Ui, mut pos: i32, mut row: i32, lines: Lines) {
        if row == 0 && self.count > 0 {
            row = 1;
            pos = 1;
        }
        if self.rows < row {
            row = self.rows;
        }
        self.cur = row;
        if self.cur > self.count {
            self.cur = self.count;
        }
        if pos > self.count {
            pos = self.count;
        }
        if pos < self.cur {
            self.cur = pos;
        }
        self.top = pos - self.cur;
        if self.rows > self.count {
            self.cur = pos;
            self.top = 0;
        } else if self.rows + self.top > self.count {
            self.top = self.count - self.rows;
            self.cur = pos - self.top;
        }
        self.cur = self.cur.max(1);
        self.draw_all(ui, lines);
    }

    pub fn line_down(&mut self, ui: &mut Ui, lines: Lines) {
        if self.pos() >= self.count {
            return;
        }
        self.cur += 1;
        if self.cur == self.rows + 1 {
            self.cur = self.rows;
            self.top += 1;
            self.draw_all(ui, lines);
        } else {
            self.draw_line(ui, self.cur - 1, lines);
            self.show_cur(ui, self.cur, lines);
        }
    }

    pub fn line_up(&mut self, ui: &mut Ui, lines: Lines) {
        if self.pos() <= 1 {
            return;
        }
        self.cur -= 1;
        if self.cur == 0 {
            self.cur = 1;
            self.top -= 1;
            self.draw_all(ui, lines);
        } else {
            self.draw_line(ui, self.cur + 1, lines);
            self.show_cur(ui, self.cur, lines);
        }
    }

    fn page_down(&mut self, ui: &mut Ui, lines: Lines) {
        if self.pos() >= self.count {
            return;
        }
        let oc = self.cur;
        let mut r = self.rows - 1;
        if oc + self.top + r > self.count {
            r = self.count - oc - self.top;
        }
        self.cur = oc + r;
        if self.cur > self.rows {
            self.cur = self.rows;
            self.top = r + self.top - (self.rows - oc);
            self.draw_all(ui, lines);
        } else {
            self.draw_line(ui, oc, lines);
            self.show_cur(ui, self.cur, lines);
        }
    }

    fn page_up(&mut self, ui: &mut Ui, lines: Lines) {
        if self.pos() <= 1 {
            return;
        }
        let oc = self.cur;
        let mut r = self.rows - 1;
        if oc + self.top - r < 1 {
            r = oc + self.top - 1;
        }
        self.cur = oc - r;
        if self.cur < 1 {
            self.cur = 1;
            self.top = self.top - r + oc - 1;
            self.draw_all(ui, lines);
        } else {
            self.draw_line(ui, oc, lines);
            self.show_cur(ui, self.cur, lines);
        }
    }

    fn home(&mut self, ui: &mut Ui, lines: Lines) {
        if self.cur <= 1 && self.top == 0 {
            return;
        }
        self.cur = 1;
        self.top = 0;
        self.draw_all(ui, lines);
    }

    fn end(&mut self, ui: &mut Ui, lines: Lines) {
        let l = self.rows.min(self.count);
        if self.count <= 1 || self.cur >= l && self.count - l == self.top {
            return;
        }
        self.cur = l;
        self.top = self.count - l;
        self.draw_all(ui, lines);
    }

    /// TList.Handle: cursor keys, scroll bar and mouse. A click on the current entry (or a double click
    /// with `dbl_click_select`) turns `key` into Enter. Returns the current entry.
    pub fn handle(&mut self, ui: &mut Ui, key: &mut u16, lines: Lines) -> i32 {
        if self.scroll {
            self.update_thumb(ui);
            self.thumb_mouse(ui, lines);
        }
        let m = ui.mouse;
        let held = m.button & 1 != 0;
        let mut up = held && self.x <= m.x && self.x + self.width >= m.x && self.y - 1 == m.y;
        let mut down = held && self.x <= m.x && self.x + self.width >= m.x && self.y + self.rows == m.y;
        if self.scroll && held && self.y + self.rows - 1 == m.y && self.width + self.x == m.x {
            down = true;
        }
        if self.scroll && held && self.y == m.y && self.width + self.x == m.x {
            up = true;
        }
        if *key == DOWN || down {
            self.line_down(ui, lines);
        }
        if *key == UP || up {
            self.line_up(ui, lines);
        }
        match *key {
            PGDN => self.page_down(ui, lines),
            PGUP => self.page_up(ui, lines),
            HOME => self.home(ui, lines),
            END => self.end(ui, lines),
            _ => {}
        }
        if (up || down) && ui.term.is_some() {
            ui.flush();
            let t = Instant::now();
            while t.elapsed() < Duration::from_millis(60) && ui.mouse.button == 1 {
                ui.pump();
            }
        }
        let m = ui.mouse;
        let in_list = m.button == 1
            && self.x < m.x
            && self.x + self.width > m.x
            && self.y + self.rows > m.y
            && self.y + self.count > m.y
            && self.y <= m.y;
        if in_list {
            self.mouse_select(ui, key, lines);
        }
        self.pos()
    }

    fn mouse_select(&mut self, ui: &mut Ui, key: &mut u16, lines: Lines) {
        let m = ui.mouse;
        if self.cur == m.y - self.y + 1 {
            if self.dbl_click_select {
                if ui.double_click(m.x, m.y) {
                    *key = ENTER;
                }
                return;
            }
            let c = m.x;
            ui.wait_release();
            let m = ui.mouse;
            if self.cur == m.y - self.y + 1 && c == m.x {
                *key = ENTER;
            }
            return;
        }
        self.draw_line(ui, self.cur, lines);
        self.cur = m.y - self.y + 1;
        self.show_cur(ui, self.cur, lines);
    }

    /// TList.SetData.
    pub fn set_data(&mut self, ui: &mut Ui, count: i32, rows: i32, cur: i32, top: i32, lines: Lines) {
        self.count = count;
        self.cur = cur;
        self.top = top;
        self.rows = rows;
        self.draw_all(ui, lines);
    }
}
