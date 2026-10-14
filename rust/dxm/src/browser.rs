//! File browser for choosing programs (Browser.TBrowser) and the "choose program" dialog
//! (AddProg.SelectProgram). Shows directories and programs (executable files and scripts).

use crate::Dxm;
use dxtui::button::Buttons;
use dxtui::keys::*;
use dxtui::ui::Ui;
use std::path::{Path, PathBuf};

pub struct Entry {
    pub name: String,
    pub dir: bool,
    /// Display columns: name(12) size(9) date(8) time(6)
    line: String,
}

pub struct Browser {
    hi_fg: u8,
    hi_bg: u8,
    x: i32,
    y: i32,
    height: i32,
    title: u8,
    rows: i32,
    cur: i32,
    top: i32,
    pub dir: PathBuf,
    items: Vec<Entry>,
}

const PROG_EXT: [&str; 9] = ["exe", "com", "bat", "sh", "py", "pl", "rb", "appimage", "command"];

fn is_program(p: &Path, md: &std::fs::Metadata) -> bool {
    let ext = p.extension().and_then(|e| e.to_str()).map(str::to_ascii_lowercase);
    if ext.is_some_and(|e| PROG_EXT.contains(&e.as_str())) {
        return true;
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        return md.is_file() && md.permissions().mode() & 0o111 != 0;
    }
    #[allow(unreachable_code)]
    false
}

/// File name in 12 columns ("…" marks a cut name).
pub fn name12(s: &str) -> String {
    let n = s.chars().count();
    if n <= 12 { dxtui::pad_right(s, 12) } else { s.chars().take(11).collect::<String>() + "…" }
}

/// Shorten (Dialogs.Shorten) for paths.
pub fn shorten(s: &str, n: usize) -> String {
    crate::usermenu::shorten(s, n)
}

impl Browser {
    /// TBrowser.Init: the list area is (x, y)..(x+39, y+height+1); row 1 holds the directory name.
    #[allow(clippy::too_many_arguments)]
    pub fn new(ui: &mut Ui, fg: u8, bg: u8, hi_fg: u8, hi_bg: u8, x: i32, y: i32, height: i32, title: u8) -> Browser {
        let dir = std::env::current_dir().unwrap_or_else(|_| "/".into());
        let mut b = Browser { hi_fg, hi_bg, x, y, height, title, rows: 0, cur: 1, top: 0, dir, items: vec![] };
        ui.window(x, y, x + 39, y + height + 1);
        ui.text_color(fg);
        ui.text_background(bg);
        b.read_dir();
        b.draw_frame(ui);
        b.redraw(ui);
        b
    }

    fn read_dir(&mut self) {
        let mut v = vec![];
        if let Some(_p) = self.dir.parent() {
            v.push(Entry { name: "..".into(), dir: true, line: String::new() });
        }
        if let Ok(rd) = std::fs::read_dir(&self.dir) {
            for e in rd.flatten() {
                let name = e.file_name().to_string_lossy().to_string();
                if name.starts_with('.') {
                    continue;
                }
                let Ok(md) = std::fs::metadata(e.path()) else { continue };
                if md.is_dir() || is_program(&e.path(), &md) {
                    let mut ent = Entry { name, dir: md.is_dir(), line: String::new() };
                    ent.line = Self::line_of(&ent, Some(&md));
                    v.push(ent);
                }
            }
        }
        if let Some(up) = v.first_mut().filter(|e| e.name == "..") {
            up.line = Self::line_of(up, std::fs::metadata(self.dir.join("..")).ok().as_ref());
        }
        v.sort_by(|a, b| {
            (a.name != "..", !a.dir, a.name.to_lowercase()).cmp(&(b.name != "..", !b.dir, b.name.to_lowercase()))
        });
        self.items = v;
    }

    fn line_of(e: &Entry, md: Option<&std::fs::Metadata>) -> String {
        let size = if e.name == ".." {
            "\u{25ba}UP--DIR\u{25c4}".to_string()
        } else if e.dir {
            "\u{25ba}SUB-DIR\u{25c4}".to_string()
        } else {
            format!("{:9}", md.map_or(0, |m| m.len()))
        };
        let (date, time) = match md.and_then(|m| m.modified().ok()) {
            Some(t) => {
                let (y, mo, d, h, mi, _) = dxtui::time::local_of(t);
                (format!("{d:2}.{mo:02}.{:02}", y % 100), format!(" {h:2}:{mi:02}"))
            }
            None => (" ".repeat(8), " ".repeat(6)),
        };
        let size = if size.chars().count() > 9 { format!("{:>9}", "big") } else { size };
        format!("{}│{size}│{date}│{time}", name12(&e.name))
    }

    fn draw_frame(&mut self, ui: &mut Ui) {
        self.top = 0;
        self.cur = 1;
        self.rows = self.height.min(self.items.len() as i32);
        let t = shorten(&self.dir.display().to_string(), 38);
        ui.write_center_xyfb(1, 1, 40, 0, self.title, &t);
        ui.write_xy(14, 2, "┬─────────┬────────┬──────");
        for i in self.rows + 1..=self.height {
            ui.write_xy(2, i + 2, "            │         │        │      ");
        }
    }

    fn draw_line(&self, ui: &mut Ui, n: i32) {
        if let Some(e) = self.items.get((n + self.top - 1) as usize) {
            ui.write_xy(2, n + 2, &e.line);
        }
    }

    fn hi_line(&self, ui: &mut Ui, n: i32) {
        let a = ui.text_attr;
        ui.set_color(self.hi_fg, self.hi_bg);
        self.draw_line(ui, n);
        ui.text_attr = a;
    }

    fn redraw(&self, ui: &mut Ui) {
        for i in 1..=self.rows {
            if i != self.cur {
                self.draw_line(ui, i);
            }
        }
        self.hi_line(ui, self.cur);
    }

    fn count(&self) -> i32 {
        self.items.len() as i32
    }

    fn line_down(&mut self, ui: &mut Ui) {
        if self.cur + self.top >= self.count() {
            return;
        }
        self.cur += 1;
        if self.cur == self.rows + 1 {
            self.cur = self.rows;
            self.top += 1;
            self.redraw(ui);
        } else {
            self.draw_line(ui, self.cur - 1);
        }
        self.hi_line(ui, self.cur);
    }

    fn line_up(&mut self, ui: &mut Ui) {
        if self.cur + self.top <= 1 {
            return;
        }
        self.cur -= 1;
        if self.cur == 0 {
            self.cur = 1;
            self.top -= 1;
            self.redraw(ui);
        } else {
            self.draw_line(ui, self.cur + 1);
        }
        self.hi_line(ui, self.cur);
    }

    fn page(&mut self, ui: &mut Ui, down: bool) {
        let c = self.cur;
        let mut d = self.height - 1;
        if down {
            if c + self.top >= self.count() {
                return;
            }
            if c + self.top + d > self.count() {
                d = self.count() - c - self.top;
            }
            self.cur = c + d;
            if self.cur > self.rows {
                self.cur = self.rows;
                self.top = d + self.top - (self.rows - c);
                self.redraw(ui);
            } else {
                self.draw_line(ui, c);
            }
        } else {
            if c + self.top <= 1 {
                return;
            }
            if c + self.top - d < 1 {
                d = c + self.top - 1;
            }
            self.cur = c - d;
            if self.cur < 1 {
                self.cur = 1;
                self.top = self.top - d + c - 1;
                self.redraw(ui);
            } else {
                self.draw_line(ui, c);
            }
        }
        self.hi_line(ui, self.cur);
    }

    /// TBrowser.Select: returns the chosen entry, or None on Esc/F10/"Done"; Some("") when a place was
    /// chosen with "Drive" (the browser then shows it).
    fn select(&mut self, ui: &mut Ui, mut b: Option<&mut Buttons>) -> Option<usize> {
        self.redraw(ui);
        let (x, y, h) = (self.x, self.y, self.height);
        loop {
            let w = ui.get_win();
            ui.window(1, 1, 80, 25);
            let mut key = 0;
            let (mut ins, mut drive, mut done) = (false, false, false);
            match b.as_deref_mut() {
                None => key = ui.get_key(),
                Some(bb) => match bb.handle(ui, &mut key) {
                    Some(0) => ins = true,
                    Some(1) => drive = true,
                    Some(2) => done = true,
                    _ => {}
                },
            }
            match dxtui::Key::new(key).char().map(dxtui::lo_case) {
                Some('i') => ins = true,
                Some('o') => done = true,
                Some('d') => drive = true,
                _ => {}
            }
            ui.set_win(&w);
            if done {
                key = F10;
            }
            if ins {
                key = ENTER;
            }
            let m = ui.mouse;
            let dn_area = m.button == 1 && x < m.x && x + 40 > m.x && y + h + 2 == m.y;
            let up_area = m.button == 1 && x < m.x && x + 40 > m.x && (y == m.y || y + 1 == m.y);
            if key == DOWN || dn_area {
                self.line_down(ui);
            }
            if key == UP || up_area {
                self.line_up(ui);
            }
            match key {
                PGDN => self.page(ui, true),
                PGUP => self.page(ui, false),
                HOME => {
                    self.cur = 1;
                    self.top = 0;
                    self.redraw(ui);
                }
                END => {
                    self.cur = self.rows;
                    self.top = self.count() - self.rows;
                    self.redraw(ui);
                }
                _ => {}
            }
            if dn_area || up_area {
                ui.flush();
                std::thread::sleep(std::time::Duration::from_millis(40));
            }
            if key == ALT_F1 || key == ALT_F1 + 1 || drive {
                let w = ui.get_win();
                ui.window(1, 1, 80, 25);
                if let Some(bb) = b.as_deref_mut() {
                    bb.reset(ui);
                }
                let place = ui.select_place(20, 8, &self.dir);
                if let Some(bb) = b.as_deref_mut() {
                    bb.set(ui, 0);
                }
                ui.set_win(&w);
                if let Some(p) = place {
                    self.dir = p;
                    self.read_dir();
                    self.draw_frame(ui);
                    self.redraw(ui);
                }
                continue;
            }
            let m = ui.mouse;
            let in_list = m.button == 1 && x < m.x && x + 40 > m.x && y + self.rows + 2 > m.y && y + 1 < m.y;
            if in_list {
                let row = m.y - y - 1;
                if self.cur == row {
                    if ui.double_click(m.x, m.y) {
                        key = ENTER;
                    }
                } else {
                    self.draw_line(ui, self.cur);
                    self.cur = row;
                    self.hi_line(ui, self.cur);
                }
            }
            if m.button == 2 {
                key = F10;
            }
            match key {
                ENTER if self.count() > 0 => return Some((self.cur + self.top - 1) as usize),
                ESC | F10 => return None,
                _ => {}
            }
        }
    }

    /// TBrowser.Execute: browses until a program is chosen (its full path) or the user cancels.
    pub fn execute(&mut self, ui: &mut Ui, mut b: Option<&mut Buttons>) -> Option<String> {
        ui.window(self.x, self.y, self.x + 39, self.y + self.height + 1);
        let t = shorten(&self.dir.display().to_string(), 38);
        ui.write_center_xyfb(1, 1, 40, 0, self.title, &t);
        let res = loop {
            let i = self.select(ui, b.as_deref_mut())?;
            let e = &self.items[i];
            if !e.dir {
                break self.dir.join(&e.name).display().to_string();
            }
            let old = self.dir.clone();
            let new = if e.name == ".." { old.parent().map(Path::to_path_buf).unwrap_or(old.clone()) } else { old.join(&e.name) };
            if std::fs::read_dir(&new).is_err() {
                continue;
            }
            self.dir = new;
            self.read_dir();
            self.draw_frame(ui);
            if e_is_up(&old, &self.dir) {
                let name = old.file_name().map(|n| n.to_string_lossy().to_string()).unwrap_or_default();
                if let Some(p) = self.items.iter().position(|x| x.name == name) {
                    self.cur = p as i32 + 1;
                    while self.cur > self.rows {
                        self.top += 1;
                        self.cur -= 1;
                    }
                }
            }
        };
        ui.window(1, 1, 80, 25);
        Some(res)
    }
}

fn e_is_up(old: &Path, new: &Path) -> bool {
    old.parent() == Some(new)
}

impl Dxm {
    /// AddProg.SelectProgram: the "choose program" dialog. Returns the full path.
    pub fn select_program(&mut self) -> Option<String> {
        let ui = &mut self.ui;
        ui.open_dialog();
        ui.frame(17, 3, 44, 20, 11, 6, false, true);
        ui.write_center_xy(1, 17, 44, "Shown are: programs and scripts");
        ui.window(1, 1, 80, 25);
        let mut b = Buttons::new(ui, true, &[(19, 21), (34, 21), (49, 21)], 14, 0, 11, 6,
            &[" Insert ", " Drive  ", "  Done  "]);
        ui.frame(19, 5, 40, 13, 11, 1, false, false);
        let mut br = Browser::new(ui, 11, 1, 0, 3, 20, 4, 13, 6);
        let s = br.execute(ui, Some(&mut b));
        ui.close_dialog();
        s
    }
}
