//! Menu bar with pull-down menus (the DXMAIN top line). Items carry a command number; 0 is a separator.

use crate::keys::*;
use crate::ui::Ui;

pub struct Item {
    /// Text with '~' before the hotkey letter.
    pub text: String,
    /// Shortcut shown right-aligned ("F3", "Alt-X").
    pub key: String,
    pub cmd: u16,
}

impl Item {
    pub fn new(text: &str, key: &str, cmd: u16) -> Item {
        Item { text: text.into(), key: key.into(), cmd }
    }

    pub fn sep() -> Item {
        Item { text: String::new(), key: String::new(), cmd: 0 }
    }
}

pub struct Menu {
    /// Title with '~' before the hotkey letter (also the Alt+letter that opens it).
    pub title: String,
    pub items: Vec<Item>,
}

/// Lower-case hotkey letter of a '~' text.
pub fn hot(s: &str) -> Option<char> {
    let p = s.find('~')?;
    s[p + 1..].chars().next().map(crate::lo_case)
}

/// Writes a '~' text at the cursor: hotkey letter in `hot_fg`.
pub fn write_hot(ui: &mut Ui, s: &str, hot_fg: u8) {
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c == '~' {
            if let Some(h) = chars.next() {
                ui.write_f(hot_fg, &h.to_string());
            }
        } else {
            ui.write(&c.to_string());
        }
    }
}

fn plain_len(s: &str) -> i32 {
    s.chars().filter(|&c| c != '~').count() as i32
}

pub struct MenuBar {
    pub menus: Vec<Menu>,
    /// Column of each title (1-based, the text starts there).
    pub xs: Vec<i32>,
    /// Remembered selection per menu (1-based).
    pub sel: Vec<usize>,
    pub fg: u8,
    pub bg: u8,
    pub hot_fg: u8,
}

impl MenuBar {
    /// Titles start at column `x0` with two spaces between them.
    pub fn new(menus: Vec<Menu>, x0: i32) -> MenuBar {
        let mut xs = vec![];
        let mut x = x0;
        for m in &menus {
            xs.push(x);
            x += plain_len(&m.title) + 2;
        }
        let n = menus.len();
        MenuBar { menus, xs, sel: vec![1; n], fg: 0, bg: 3, hot_fg: 4 }
    }

    /// Draws the titles in row 1 (`hi` = index drawn highlighted).
    pub fn draw(&self, ui: &mut Ui, hi: Option<usize>) {
        let w = ui.save_win();
        let c = ui.cols();
        ui.window(1, 1, c, 1);
        for (i, m) in self.menus.iter().enumerate() {
            let bg = if hi == Some(i) { 2 } else { self.bg };
            ui.set_color(self.fg, bg);
            ui.goto_xy(self.xs[i] - 1, 1);
            ui.write(" ");
            write_hot(ui, &m.title, self.hot_fg);
            ui.write(" ");
        }
        ui.restore_win(&w);
    }

    /// Menu whose title is under column `x` of row 1.
    pub fn title_at(&self, x: i32) -> Option<usize> {
        (0..self.menus.len()).find(|&i| self.xs[i] - 1 <= x && x <= self.xs[i] + plain_len(&self.menus[i].title))
    }

    /// Menu opened by Alt+letter `code`.
    pub fn by_alt(&self, code: u16) -> Option<usize> {
        let c = alt_letter_of(code)?;
        self.menus.iter().position(|m| hot(&m.title) == Some(c))
    }

    fn width(m: &Menu) -> i32 {
        m.items.iter().map(|i| plain_len(&i.text) + i.key.chars().count() as i32 + 4).max().unwrap_or(10).max(12)
    }

    fn draw_items(&self, ui: &mut Ui, m: &Menu, w: i32, sel: usize) {
        for (i, it) in m.items.iter().enumerate() {
            ui.goto_xy(1, i as i32 + 1);
            if it.cmd == 0 {
                ui.set_color(0, self.bg);
                ui.write(&"─".repeat(w as usize));
                continue;
            }
            let bg = if i + 1 == sel { 2 } else { self.bg };
            ui.set_color(self.fg, bg);
            ui.write(" ");
            write_hot(ui, &it.text, self.hot_fg);
            let used = plain_len(&it.text) + 1;
            let k = it.key.chars().count() as i32;
            ui.write(&" ".repeat((w - used - k - 1).max(1) as usize));
            ui.write(&it.key);
            ui.write(" ");
        }
    }

    /// Runs the bar starting with menu `start` open. Returns the chosen command.
    pub fn run(&mut self, ui: &mut Ui, start: usize) -> Option<u16> {
        let mut cur = start;
        ui.wait_release();
        loop {
            self.draw(ui, Some(cur));
            ui.open_dialog();
            let m = &self.menus[cur];
            let n = m.items.len();
            let w = Self::width(m);
            let cols = ui.cols();
            let x = (self.xs[cur] - 1).min(cols - w - 3).max(1);
            ui.frame(x, 2, w, n as i32, 11, 3, false, true);
            let mut sel = self.sel[cur].clamp(1, n.max(1));
            if m.items.get(sel - 1).is_some_and(|i| i.cmd == 0) {
                sel = 1;
            }
            self.draw_items(ui, m, w, sel);
            let mut result: Option<Option<u16>> = None;
            let mut switch: Option<usize> = None;
            loop {
                let key = ui.get_key();
                let ms = ui.mouse;
                let m = &self.menus[cur];
                let mut choose = false;
                match key {
                    0 => {}
                    ESC | F10 => result = Some(None),
                    LEFT => switch = Some((cur + self.menus.len() - 1) % self.menus.len()),
                    RIGHT => switch = Some((cur + 1) % self.menus.len()),
                    DOWN | UP => loop {
                        sel = if key == DOWN { sel % n + 1 } else if sel <= 1 { n } else { sel - 1 };
                        if m.items[sel - 1].cmd != 0 {
                            break;
                        }
                    },
                    HOME => sel = 1,
                    END => sel = n,
                    ENTER => choose = true,
                    k => {
                        if let Some(i) = self.by_alt(k) {
                            switch = Some(i);
                        } else if let Some(c) = Key::new(k).char().map(crate::lo_case) {
                            if let Some(i) = m.items.iter().position(|it| it.cmd != 0 && hot(&it.text) == Some(c)) {
                                sel = i + 1;
                                choose = true;
                            }
                        }
                    }
                }
                if ms.button == 1 {
                    let inside = ms.x > x && ms.x <= x + w && ms.y > 2 && ms.y <= 2 + n as i32;
                    if inside {
                        let s = (ms.y - 2) as usize;
                        if m.items[s - 1].cmd != 0 {
                            sel = s;
                            self.draw_items(ui, m, w, sel);
                            ui.wait_release();
                            choose = true;
                        }
                    } else if ms.y == 1 {
                        match self.title_at(ms.x) {
                            Some(i) if i != cur => switch = Some(i),
                            Some(_) => {}
                            None => result = Some(None),
                        }
                        ui.wait_release();
                    } else {
                        ui.wait_release();
                        result = Some(None);
                    }
                } else if ms.button == 2 {
                    ui.wait_release();
                    result = Some(None);
                }
                if choose {
                    self.sel[cur] = sel;
                    result = Some(Some(m.items[sel - 1].cmd));
                }
                if result.is_some() || switch.is_some() {
                    break;
                }
                if key != 0 {
                    self.draw_items(ui, m, w, sel);
                }
            }
            self.sel[cur] = sel;
            ui.pop_screen();
            if let Some(r) = result {
                self.draw(ui, None);
                return r;
            }
            if let Some(s) = switch {
                cur = s;
            }
        }
    }
}
