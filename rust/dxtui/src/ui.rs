//! The DX dialog toolkit on top of `Crt`: dialog stack (ScrSave/Dialogs.OpenDialog), key input with idle
//! work (Status.GetKey: clock), mouse helpers (Mouse unit), message boxes and the line editor
//! (Dialogs.MsgBox, ErrorBox, InputLine, EditLine). Spec: src/dxm/{DIALOGS,STATUS,MOUSE,SCRSAVE}.PAS.

use crate::button::Button;
use crate::keys::*;
use crate::{Cell, Crt, WinState};
use std::time::{Duration, Instant};

pub struct Saved {
    cells: Vec<Cell>,
    win: WinState,
}

/// Clock in the top line (Status unit).
pub struct Clock {
    pub x: i32,
    pub y: i32,
    pub fg: u8,
    pub bg: u8,
    pub clock_hidden: bool,
    pub date_hidden: bool,
    pub last_date: String,
    pub last_time: String,
    /// Four-digit year in the date (DXMAIN).
    pub long_year: bool,
    last_sec: u32,
    blink: bool,
}

pub struct Ui {
    pub crt: Crt,
    stack: Vec<Saved>,
    pub clock: Clock,
    /// Line editor insert mode (DXGlob.InsMode).
    pub ins_mode: bool,
    /// Seconds without input before `idle_hook` reports the screen saver (0 = never).
    pub saver_delay: u32,
    last_input: Instant,
    /// Set when the saver delay has run out; the program decides what to do.
    pub saver_due: bool,
    /// Input history of the command line (DXGlob.History).
    pub history: Vec<String>,
}

impl std::ops::Deref for Ui {
    type Target = Crt;
    fn deref(&self) -> &Crt {
        &self.crt
    }
}

impl std::ops::DerefMut for Ui {
    fn deref_mut(&mut self) -> &mut Crt {
        &mut self.crt
    }
}

/// Day names for the status line date.
const DAYS: [&str; 7] = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];

impl Ui {
    pub fn new(crt: Crt) -> Ui {
        Ui {
            crt,
            stack: vec![],
            clock: Clock {
                x: 75,
                y: 1,
                fg: 0,
                bg: 3,
                clock_hidden: false,
                date_hidden: false,
                last_date: "x".into(),
                last_time: "x".into(),
                long_year: false,
                last_sec: 99,
                blink: true,
            },
            ins_mode: true,
            saver_delay: 0,
            last_input: Instant::now(),
            saver_due: false,
            history: vec![],
        }
    }

    // --- dialog stack ---

    /// OpenDialog / PushScreen: remembers screen, window, cursor and colour.
    pub fn open_dialog(&mut self) {
        let win = self.crt.get_win();
        self.stack.push(Saved { cells: self.crt.save(), win });
    }

    /// PopScreen.
    pub fn pop_screen(&mut self) {
        if let Some(s) = self.stack.pop() {
            self.crt.restore(&s.cells);
            self.crt.restore_win(&s.win);
        }
    }

    /// CloseDialog: PopScreen + WaitRelease.
    pub fn close_dialog(&mut self) {
        self.pop_screen();
        self.wait_release();
    }

    /// DropScreen: forgets the top entry without restoring it.
    pub fn drop_screen(&mut self) {
        self.stack.pop();
    }

    pub fn stack_depth(&self) -> usize {
        self.stack.len()
    }

    // --- input ---

    /// Status.GetKey: 0 when no key is pending (after a short wait), otherwise the DX key code.
    pub fn get_key(&mut self) -> u16 {
        match self.crt.poll_key(15) {
            Some(k) => {
                self.last_input = Instant::now();
                k.code
            }
            None => {
                if self.crt.mouse.idle == 0 && self.crt.mouse.button != 0 {
                    self.last_input = Instant::now();
                }
                self.idle();
                0
            }
        }
    }

    /// Waits for a key (no mouse).
    pub fn read_key(&mut self) -> u16 {
        loop {
            let k = self.get_key();
            if k != 0 {
                return k;
            }
        }
    }

    /// Processes pending terminal events for the mouse state; keys are kept for the next `get_key`.
    pub fn pump(&mut self) {
        if let Some(k) = self.crt.poll_key(10) {
            self.crt.queue.push_back(k);
        }
        self.idle();
    }

    /// Status.Idle: clock and screen saver timing.
    pub fn idle(&mut self) {
        self.update_clock();
        if self.saver_delay > 0 && self.last_input.elapsed() >= Duration::from_secs(self.saver_delay as u64) {
            self.saver_due = true;
            self.last_input = Instant::now();
        }
    }

    pub fn reset_idle(&mut self) {
        self.last_input = Instant::now();
        self.saver_due = false;
    }

    /// WaitRelease.
    pub fn wait_release(&mut self) {
        while self.crt.mouse.button != 0 {
            self.pump();
            if self.crt.term.is_none() {
                self.crt.mouse.button = 0;
            }
        }
    }

    /// Dialogs.IsCancel: Esc, F10 or right mouse button.
    pub fn is_cancel(&mut self, key: u16) -> bool {
        if key == ESC || key == F10 || self.crt.mouse.button == 2 {
            self.wait_release();
            return true;
        }
        false
    }

    /// Mouse.MouseOn: left button held on row `y` between `x1` and `x2`.
    pub fn mouse_on(&self, y: i32, x1: i32, x2: i32) -> bool {
        let m = &self.crt.mouse;
        m.button == 1 && m.y == y && x1 <= m.x && x2 >= m.x
    }

    /// Mouse.MouseOutside: left button held outside the rectangle.
    pub fn mouse_outside(&self, x1: i32, x2: i32, y1: i32, y2: i32) -> bool {
        let m = &self.crt.mouse;
        m.button == 1 && (y2 < m.y || y1 > m.y || x2 < m.x || x1 > m.x)
    }

    /// Mouse.DoubleClick: the left button is down at (x, y) and this press is the second of a double click,
    /// or a second press follows within the double-click time.
    pub fn double_click(&mut self, x: i32, y: i32) -> bool {
        let m = self.crt.mouse;
        if !(m.x == x && m.y == y && m.button == 1) {
            return false;
        }
        if std::mem::take(&mut self.crt.mouse.double) {
            return true;
        }
        let t = Instant::now();
        let mut released = false;
        while t.elapsed() < Duration::from_millis(400) && self.crt.term.is_some() {
            self.pump();
            if self.crt.mouse.button == 0 {
                released = true;
            } else if released && std::mem::take(&mut self.crt.mouse.double) {
                return true;
            }
        }
        false
    }

    // --- clock ---

    fn time_str(&mut self) -> String {
        let (h, m, s) = crate::time::now_hms();
        if s != self.clock.last_sec {
            self.clock.blink = !self.clock.blink;
        }
        self.clock.last_sec = s;
        format!("{h:2}{}{m:02} ", if self.clock.blink { ':' } else { ' ' })
    }

    fn date_str(&self) -> String {
        let (y, mo, d, wd) = crate::time::today();
        if self.clock.long_year {
            format!("{} {d:2}.{mo:02}.{y}", DAYS[wd as usize])
        } else {
            format!("{} {d:2}.{mo:02}.{:02}", DAYS[wd as usize], y % 100)
        }
    }

    /// Status.UpdateClock.
    pub fn update_clock(&mut self) {
        let w = self.crt.get_win();
        let s = self.date_str();
        let (x, y, fg, bg) = (self.clock.x, self.clock.y, self.clock.fg, self.clock.bg);
        if self.clock.last_date != s && !self.clock.clock_hidden && !self.clock.date_hidden {
            self.crt.window(1, 1, self.crt.cols(), self.crt.rows());
            let a = self.crt.text_attr;
            self.crt.set_color(fg, bg);
            self.crt.write_xy(x - s.chars().count() as i32 - 1, y, &format!("{s} "));
            self.crt.text_attr = a;
            self.crt.set_win(&w);
        }
        self.clock.last_date = s;
        let t = self.time_str();
        if self.clock.last_time != t && !self.clock.clock_hidden {
            self.crt.window(1, 1, self.crt.cols(), self.crt.rows());
            let a = self.crt.text_attr;
            self.crt.set_color(fg, bg);
            self.crt.write_xy(x, y, &t);
            self.crt.text_attr = a;
            self.crt.set_win(&w);
        }
        self.clock.last_time = t;
        self.crt.text_attr = w.attr;
    }

    pub fn clock_off(&mut self) {
        let w = self.crt.save_win();
        self.clock.clock_hidden = true;
        let (x, y, bg) = (self.clock.x, self.clock.y, self.clock.bg);
        self.crt.write_xyb(x, y, bg, "      ");
        self.crt.restore_win(&w);
    }

    pub fn clock_on(&mut self) {
        self.clock.clock_hidden = false;
        self.clock.last_time.clear();
        self.update_clock();
    }

    pub fn date_off(&mut self) {
        let w = self.crt.save_win();
        self.clock.date_hidden = true;
        let (x, y, bg) = (self.clock.x, self.clock.y, self.clock.bg);
        self.crt.write_xyb(x - 17, y, bg, &" ".repeat(17));
        self.crt.restore_win(&w);
    }

    pub fn date_on(&mut self) {
        self.clock.date_hidden = false;
        self.clock.last_date.clear();
        self.update_clock();
    }

    // --- boxes ---

    /// Dialogs.MsgBox: red box with a "Continue" button.
    pub fn msg_box(&mut self, s1: &str, s2: &str) {
        self.open_dialog();
        self.crt.frame(13, 7, 55, 8, 2, 4, false, true);
        self.crt.write_center_xyf(1, 2, 55, 2, s1);
        self.crt.write_center_xyf(1, 4, 55, 14, s2);
        let mut b = Button::new(true, 19, 6, 2, 2, 2, 4, "     Continue   ");
        b.draw(&mut self.crt);
        loop {
            let k = self.get_key();
            if k != 0 || b.mouse_button(self) || self.crt.mouse.button == 2 {
                break;
            }
        }
        self.close_dialog();
    }

    /// Dialogs.ErrorBox: beige box with a wide OK button.
    pub fn error_box(&mut self, s1: &str, s2: &str) {
        self.open_dialog();
        self.crt.frame(13, 7, 55, 8, 2, 5, false, true);
        self.crt.write_center_xyfb(1, 2, 55, 0, 5, s1);
        self.crt.write_center_xyfb(1, 4, 55, 4, 5, s2);
        let cap = format!("{}OK{}", " ".repeat(23), " ".repeat(22));
        let mut b = Button::new(true, 3, 6, 0, 2, 2, 5, &cap);
        b.draw(&mut self.crt);
        self.wait_release();
        loop {
            let k = self.get_key();
            if k != 0 || b.mouse_button(self) || self.crt.mouse.button == 2 || self.mouse_outside(13, 69, 7, 16) {
                break;
            }
        }
        self.close_dialog();
    }

    /// Dialogs.InputLine: draws the field (green on white, a separator line above) at absolute (x, y)
    /// and edits `s` unless `max_len` is 0. Returns the key that ended editing (13, 9, SHIFT_TAB, ...).
    #[allow(clippy::too_many_arguments)]
    pub fn input_line(&mut self, x: i32, y: i32, left_x: i32, right_x: i32, s: &mut String, width: i32, max_len: i32,
        line: bool) -> u16 {
        let t = s.clone();
        let (c, r) = (self.crt.cols(), self.crt.rows());
        self.crt.window(1, 1, c, r);
        let save = self.crt.text_attr;
        self.crt.goto_xy(x, y - 1);
        self.crt.write_b(&vec![if line { 0xC4 } else { b' ' }; (width + 2) as usize]);
        self.crt.set_color(0, 2);
        self.crt.write_xy(x, y, " ");
        self.crt.write_xy(x + 1, y, &" ".repeat((width + 1) as usize));
        if max_len == 0 {
            let v: String = t.chars().take(width as usize).collect();
            self.crt.write_xy(x + 1, y, &v);
            self.crt.text_attr = save;
            0
        } else {
            self.crt.cursor_visible = true;
            let mut t = t;
            let k = self.edit_line(x + 1, y, &mut t, width, max_len, save, left_x, right_x, false);
            self.crt.cursor_visible = false;
            *s = t;
            self.crt.text_attr = save;
            k
        }
    }

    /// Dialogs.EditLine (without the DXMAIN-only history and name insertion): edits `s` in a field of
    /// `width` columns at (x, y); `attr` is used for the scroll arrows at `left_x`/`right_x`.
    #[allow(clippy::too_many_arguments)]
    pub fn edit_line(&mut self, x: i32, y: i32, s: &mut String, width: i32, max_len: i32, attr: u8, left_x: i32,
        right_x: i32, hist: bool) -> u16 {
        let mut ed = Editor {
            buf: s.chars().collect(),
            cur: 0,
            ofs: 0,
            width: width as usize,
            max_len: max_len as usize,
            x,
            y,
            attr,
            left_x,
            right_x,
            hist_idx: self.history.len(),
        };
        let orig = s.clone();
        let save_attr = self.crt.text_attr;
        let mut key: u16 = 0;
        if hist && s == "\u{ff}" {
            ed.buf.clear();
            key = UP;
        }
        ed.cur = ed.buf.len() + 1;
        if ed.cur > ed.width + 1 {
            ed.cur = ed.width + 1;
            ed.arrows(self, false, true);
        }
        let first: String = ed.buf.iter().take(ed.width).collect();
        self.crt.write_xyfb(x, y, 2, 4, &first);
        if !hist {
            self.wait_release();
            loop {
                key = self.get_key();
                if key != 0 || self.crt.mouse.button != 0 {
                    break;
                }
            }
        }
        if self.crt.mouse.button == 2 {
            key = ESC;
        }
        if self.crt.mouse.button == 1 && x - 1 <= self.crt.mouse.x && x + width >= self.crt.mouse.x && y == self.crt.mouse.y
        {
            self.wait_release();
            key = RIGHT;
        }
        match key {
            0 | RIGHT | LEFT | DOWN | UP | ESC | ENTER | TAB | SHIFT_TAB | BKSP | HOME | END | 1018 | F1 | DEL | INS => {
                let v: String = ed.buf.iter().take(ed.width).collect();
                self.crt.write_xy(x, y, &pad(&v, ed.width));
            }
            _ => {
                self.crt.write_xy(x, y, &" ".repeat(ed.width));
                ed.buf.clear();
                ed.cur = 1;
                self.crt.goto_xy(x, y);
            }
        }
        loop {
            match key {
                RIGHT => {
                    if ed.cur + ed.ofs <= ed.buf.len() {
                        if ed.cur <= ed.width {
                            ed.cur += 1;
                        } else {
                            ed.ofs += 1;
                            ed.redraw(self, 1, ed.width);
                        }
                    }
                }
                LEFT => {
                    if ed.cur + ed.ofs > 1 {
                        if ed.cur > 1 {
                            ed.cur -= 1;
                        } else {
                            ed.ofs -= 1;
                            ed.redraw(self, 1, ed.width);
                        }
                    }
                }
                HOME => {
                    ed.cur = 1;
                    ed.ofs = 0;
                    ed.redraw(self, 1, ed.width);
                }
                END => {
                    let l = ed.buf.len();
                    if l - ed.ofs > ed.width {
                        ed.cur = ed.width + 1;
                        ed.ofs = l - ed.width;
                        ed.redraw(self, 1, ed.width);
                    } else {
                        ed.cur = l - ed.ofs + 1;
                    }
                }
                BKSP => {
                    if ed.cur > 1 || ed.ofs > 0 {
                        let p = ed.cur + ed.ofs - 1; // 1-based position of the char before the cursor
                        if p >= 1 && p <= ed.buf.len() {
                            ed.buf.remove(p - 1);
                        }
                        if ed.ofs > 0 {
                            ed.ofs -= 1;
                        } else {
                            ed.cur -= 1;
                        }
                        ed.redraw(self, 1, ed.width);
                    }
                }
                DEL => {
                    let p = ed.cur + ed.ofs;
                    if p <= ed.buf.len() {
                        ed.buf.remove(p - 1);
                        ed.redraw(self, 1, ed.width);
                    }
                }
                INS => self.ins_mode = !self.ins_mode,
                UP | DOWN if hist && !self.crt.shift => {
                    ed.history_key(self, key);
                    key = 0;
                }
                DOWN => key = TAB,
                UP => key = SHIFT_TAB,
                ENTER | ESC | F10 | TAB | SHIFT_TAB | F1 => {}
                1093 => {
                    // Ctrl-F10 in the original; here Ctrl-K style "clear to end"
                    let p = ed.cur + ed.ofs - 1;
                    ed.buf.truncate(p);
                    ed.redraw(self, 1, ed.width);
                }
                k if (1..1000).contains(&k) && k != 10 && k != 13 && k >= 32 => {
                    let c = crate::cp437::decode(&[k as u8]).chars().next().unwrap();
                    let p = ed.cur + ed.ofs - 1; // 0-based insert position
                    let l = ed.buf.len();
                    if l < ed.max_len || !self.ins_mode && p < l {
                        if self.ins_mode || p >= l {
                            ed.buf.insert(p.min(l), c);
                        } else {
                            ed.buf[p] = c;
                        }
                        if ed.cur <= ed.width {
                            ed.cur += 1;
                        } else {
                            ed.ofs += 1;
                        }
                        ed.redraw(self, 1, ed.width);
                    }
                }
                _ => {}
            }
            let l = ed.buf.len();
            ed.arrows(self, ed.ofs > 0, ed.ofs + ed.width < l);
            self.crt.goto_xy(x + ed.cur as i32 - 1, y);
            self.crt.cursor_visible = true;
            if self.mouse_on(y, x - 1, x + width) {
                let mx = self.crt.mouse.x - x;
                ed.cur = if mx > l as i32 { l + 1 } else if mx < 1 { 1 } else { (mx + 1) as usize };
                self.crt.goto_xy(x + ed.cur as i32 - 1, y);
                self.wait_release();
            }
            if ![ENTER, ESC, F10, TAB, SHIFT_TAB].contains(&key) {
                loop {
                    key = self.get_key();
                    if key != 0 || self.crt.mouse.button != 0 {
                        break;
                    }
                }
            }
            let done = [TAB, SHIFT_TAB, ESC, ENTER, F10].contains(&key)
                || self.crt.mouse.button == 2
                || self.crt.mouse.button == 1 && self.mouse_outside(x - 1, x + width, y, y);
            if done {
                break;
            }
        }
        self.crt.cursor_visible = false;
        if key == ESC || key == F10 || self.crt.mouse.button == 2 {
            self.wait_release();
            let v = pad(&orig, ed.width);
            if hist {
                self.crt.write_xyfb(x, y, 2, 0, &v);
            } else {
                self.crt.write_xyfb(x, y, 0, 2, &v);
            }
            ed.arrows(self, false, false);
            *s = orig;
            self.crt.goto_xy(x, y);
            self.crt.text_attr = save_attr;
            ESC
        } else {
            *s = ed.buf.iter().collect();
            self.crt.text_attr = save_attr;
            if key == TAB || key == SHIFT_TAB { key } else { ENTER }
        }
    }
}

fn pad(s: &str, w: usize) -> String {
    crate::pad_right(s, w)
}

struct Editor {
    buf: Vec<char>,
    /// 1-based cursor column in the field
    cur: usize,
    ofs: usize,
    width: usize,
    max_len: usize,
    x: i32,
    y: i32,
    attr: u8,
    left_x: i32,
    right_x: i32,
    hist_idx: usize,
}

impl Editor {
    fn redraw(&self, ui: &mut Ui, _from: usize, _to: usize) {
        let v: String = self.buf.iter().skip(self.ofs).take(self.width).collect();
        ui.crt.write_xy(self.x, self.y, &pad(&v, self.width));
        ui.crt.goto_xy(self.x + self.cur as i32 - 1, self.y);
    }

    fn arrows(&self, ui: &mut Ui, left: bool, right: bool) {
        if self.width == self.max_len || self.right_x == 0 {
            return;
        }
        let a = ui.crt.text_attr;
        ui.crt.text_attr = self.attr;
        ui.crt.write_xy_b(self.left_x, self.y, &[if left { 27 } else { b' ' }]);
        ui.crt.write_xy_b(self.right_x, self.y, &[if right { 26 } else { b' ' }]);
        ui.crt.text_attr = a;
    }

    fn history_key(&mut self, ui: &mut Ui, key: u16) {
        let h = &ui.history;
        if key == UP && self.hist_idx > 0 {
            self.hist_idx -= 1;
            self.buf = h[self.hist_idx].chars().collect();
        } else if key == DOWN && self.hist_idx < h.len() {
            self.hist_idx += 1;
            self.buf = h.get(self.hist_idx).map_or(vec![], |s| s.chars().collect());
        } else {
            return;
        }
        self.ofs = 0;
        self.cur = self.buf.len() + 1;
        if self.cur > self.width + 1 {
            self.ofs = self.cur - self.width - 1;
            self.cur = self.width + 1;
        }
        self.redraw(ui, 1, self.width);
    }
}

/// Places offered instead of DOS drives: the root, the home directory and mounted volumes.
pub fn places() -> Vec<std::path::PathBuf> {
    use std::path::PathBuf;
    let mut v: Vec<PathBuf> = vec!["/".into()];
    if let Some(h) = std::env::var_os("HOME") {
        v.push(h.into());
    }
    let user = std::env::var("USER").unwrap_or_default();
    for base in ["/Volumes".to_string(), "/mnt".into(), "/media".into(), format!("/media/{user}"), format!("/run/media/{user}")] {
        if let Ok(rd) = std::fs::read_dir(&base) {
            let mut sub: Vec<PathBuf> = rd.flatten().map(|e| e.path()).filter(|p| p.is_dir()).collect();
            sub.sort();
            for p in sub {
                if !v.contains(&p) && p.to_str() != Some(&format!("/media/{user}")) {
                    v.push(p);
                }
            }
        }
    }
    v
}

impl Ui {
    /// Dialogs.SelectDrive for a Unix system: a list of places at (x, y). None when cancelled.
    pub fn select_place(&mut self, x: i32, y: i32, cur: &std::path::Path) -> Option<std::path::PathBuf> {
        use crate::list::List;
        let p = places();
        let names: Vec<String> = p.iter().map(|d| format!(" {}", d.display())).collect();
        let n = p.len() as i32;
        let w = (names.iter().map(|s| s.chars().count()).max().unwrap_or(5) as i32 + 2).clamp(6, 40);
        let rows = n.max(3).min(self.crt.rows() - y - 2);
        let cur_sel = p.iter().rposition(|d| cur.starts_with(d)).map_or(1, |i| i as i32 + 1);
        self.open_dialog();
        self.crt.frame(x, y, w, rows, 2, 5, false, true);
        let lines = |i: i32| names[i as usize - 1].clone();
        let mut l = List::new(self, 0, 5, 0, 2, x + 1, y + 1, rows, n, w - 1, true, &lines);
        l.set_pos(self, cur_sel, rows / 2, &lines);
        let r = loop {
            let mut key = self.get_key();
            let sel = l.handle(self, &mut key, &lines);
            if self.is_cancel(key) || self.mouse_outside(x, x + w + 1, y, y + rows + 1) {
                break None;
            }
            if key == ENTER {
                break p.get(sel as usize - 1).cloned();
            }
        };
        self.close_dialog();
        r
    }
}
