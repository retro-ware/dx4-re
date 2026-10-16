//! A file panel: path box (rows 2-4) and file window (row 5 to rows-2) of one screen half.
//! Spec: ref/dxmain/PANEL.SCR, help page "Bedienung des Hauptbildschirms".

use crate::files::{self, Entry, Sort};
use dxtui::ui::Ui;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum View {
    /// Name, size, date, time.
    Full,
    /// Names in three columns (Alt-3).
    Three,
    /// Names in five columns (Alt-5).
    Five,
    /// Long names with size (Alt-1).
    Long,
}

pub struct Panel {
    pub path: PathBuf,
    pub entries: Vec<Entry>,
    /// Index of the cursor entry.
    pub cur: usize,
    /// Index of the first entry shown.
    pub top: usize,
    pub sort: Sort,
    pub reverse: bool,
    /// Masks of files shown ("*" = all).
    pub filter: String,
    pub hidden: bool,
    pub view: View,
    /// Panel geometry: first column and width (including the frame).
    pub x: i32,
    pub w: i32,
    pub error: Option<String>,
    /// File colours by extension (lower case, without dot).
    pub colors: std::collections::HashMap<String, u8>,
}

pub const MARK_FG: u8 = 14;

impl Panel {
    pub fn new(path: PathBuf) -> Panel {
        Panel {
            path,
            entries: vec![],
            cur: 0,
            top: 0,
            sort: Sort::Ext,
            reverse: false,
            filter: "*".into(),
            hidden: false,
            view: View::Full,
            x: 1,
            w: 40,
            error: None,
            colors: Default::default(),
        }
    }

    pub fn current(&self) -> Option<&Entry> {
        self.entries.get(self.cur)
    }

    pub fn cur_path(&self) -> Option<PathBuf> {
        self.current().map(|e| if e.is_up() { self.path.parent().unwrap_or(&self.path).into() } else { self.path.join(&e.name) })
    }

    /// Reads the directory again, keeping the cursor on the same name and the marks.
    pub fn reload(&mut self) {
        let keep = self.current().map(|e| e.name.clone());
        let marked: Vec<String> = self.entries.iter().filter(|e| e.marked).map(|e| e.name.clone()).collect();
        self.load();
        for e in &mut self.entries {
            e.marked = marked.contains(&e.name);
        }
        if let Some(k) = keep {
            self.select(&k);
        }
    }

    fn load(&mut self) {
        match files::read_dir(&self.path, self.hidden) {
            Ok(mut v) => {
                v.retain(|e| e.is_dir || files::matches_any(&self.filter, &e.name));
                files::sort(&mut v, self.sort, self.reverse);
                self.entries = v;
                self.error = None;
            }
            Err(e) => {
                self.entries = if self.path.parent().is_some() { vec![Entry::up()] } else { vec![] };
                self.error = Some(e.to_string());
            }
        }
        if self.cur >= self.entries.len() {
            self.cur = self.entries.len().saturating_sub(1);
        }
    }

    /// Changes the directory; the cursor goes to `select` (the directory we came from) or the top.
    pub fn chdir(&mut self, p: &Path) -> bool {
        let p = std::fs::canonicalize(p).unwrap_or_else(|_| p.to_path_buf());
        if !p.is_dir() {
            return false;
        }
        let from = self.path.clone();
        self.path = p;
        self.cur = 0;
        self.top = 0;
        self.load();
        if from.parent() == Some(self.path.as_path()) {
            if let Some(n) = from.file_name() {
                self.select(&n.to_string_lossy());
            }
        }
        true
    }

    pub fn up(&mut self) {
        if let Some(p) = self.path.parent().map(Path::to_path_buf) {
            self.chdir(&p);
        }
    }

    pub fn select(&mut self, name: &str) {
        if let Some(i) = self.entries.iter().position(|e| e.name == name) {
            self.cur = i;
        }
    }

    pub fn marked(&self) -> Vec<&Entry> {
        self.entries.iter().filter(|e| e.marked).collect()
    }

    /// The marked entries, or the cursor entry when nothing is marked (never "..").
    pub fn targets(&self) -> Vec<Entry> {
        let m: Vec<Entry> = self.entries.iter().filter(|e| e.marked).cloned().collect();
        if !m.is_empty() {
            return m;
        }
        self.current().filter(|e| !e.is_up()).cloned().into_iter().collect()
    }

    pub fn mark_all(&mut self, mask: &str, on: bool, dirs: bool) {
        for e in &mut self.entries {
            if !e.is_up() && (dirs || !e.is_dir) && files::matches_any(mask, &e.name) {
                e.marked = on;
            }
        }
    }

    pub fn invert(&mut self) {
        for e in &mut self.entries {
            if !e.is_up() && !e.is_dir {
                e.marked = !e.marked;
            }
        }
    }

    // --- geometry ---

    /// Rows of the file window (between the frame's top and the separator above the status line).
    pub fn list_rows(rows: i32) -> i32 {
        (rows - 10).max(1)
    }

    /// Inner width.
    fn iw(&self) -> i32 {
        self.w - 2
    }

    fn name_w(&self) -> i32 {
        self.iw() - 26
    }

    /// Entries per screen and columns of the current view.
    pub fn layout(&self, rows: i32) -> (usize, usize) {
        let r = Self::list_rows(rows).max(1) as usize;
        let c = match self.view {
            View::Three => 3,
            View::Five => 5,
            _ => 1,
        };
        (r, c)
    }

    pub fn page(&self, rows: i32) -> usize {
        let (r, c) = self.layout(rows);
        r * c
    }

    /// Keeps the cursor on screen.
    pub fn fix_top(&mut self, rows: i32) {
        let page = self.page(rows);
        let (r, _) = self.layout(rows);
        if self.cur < self.top {
            self.top = if page > r { self.cur / r * r } else { self.cur };
        }
        if self.cur >= self.top + page {
            self.top = if page > r { (self.cur / r + 1) * r - page } else { self.cur + 1 - page };
        }
        let n = self.entries.len();
        if self.top > 0 && self.top + page > n && page <= r {
            self.top = n.saturating_sub(page);
        }
    }

    /// Mouse wheel: moves the view by `delta` lines (whole columns in the column views); the cursor stays
    /// on the same entry while it is visible, else it is pulled to the nearest visible one.
    pub fn scroll(&mut self, rows: i32, delta: i32) {
        let n = self.entries.len();
        let (r, c) = self.layout(rows);
        let page = r * c;
        if n <= page {
            return;
        }
        let (step, max) = if c > 1 { (r as i64, (n.div_ceil(r) - c) * r) } else { (1, n - page) };
        self.top = (self.top as i64 + step * delta as i64).clamp(0, max as i64) as usize;
        self.cur = self.cur.clamp(self.top, (self.top + page).min(n) - 1);
    }

    // --- drawing ---

    /// Name in the DOS 8.3 look ("dx       bat") when it fits, else the plain name, cut to `w`.
    pub fn name_field(e: &Entry, w: usize) -> String {
        let (stem, ext) = e.split();
        let sl = stem.chars().count();
        let el = ext.chars().count();
        let s = if !e.is_dir && w >= 12 && el > 0 && el <= 3 && sl <= w - 4 {
            format!("{}{} {:<3}", stem, " ".repeat(w - 4 - sl), ext)
        } else {
            e.name.clone()
        };
        fit(&s, w)
    }

    fn line(&self, e: &Entry, width: usize) -> String {
        let nw = self.name_w().max(1) as usize;
        let mut name = Self::name_field(e, nw);
        if e.read_only() && !e.is_dir || e.hidden() {
            let mark = if e.hidden() { '░' } else { '°' };
            let mut v: Vec<char> = name.chars().collect();
            let last = v.len() - 1;
            if v[last] == ' ' {
                v[last] = mark;
            }
            name = v.into_iter().collect();
        }
        let size = if e.is_up() {
            "►UP--DIR◄".to_string()
        } else if e.is_dir {
            "►SUB-DIR◄".to_string()
        } else {
            format!("{:>9}", files::human(e.size))
        };
        let (d, t) = files::date_time(e.mtime);
        let s = format!("{name}│{size}│{d}│{t:>6}");
        fit(&s, width)
    }

    /// Draws the path box; `active` highlights the path.
    pub fn draw_path(&self, ui: &mut Ui) {
        let w = self.iw();
        ui.frame(self.x, 2, w, 1, 11, 3, false, false);
        let r = ui.rows();
        let c = ui.cols();
        ui.window(1, 1, c, r);
        let p = shorten(&self.path.display().to_string(), (w - 2) as usize);
        let s = format!(" {p} ");
        let x = self.x + 1 + (w - s.chars().count() as i32) / 2;
        ui.write_xyfb(x, 3, 0, 3, &s);
    }

    pub fn highlight_path(&self, ui: &mut Ui, on: bool) {
        let w = self.iw();
        let p = shorten(&self.path.display().to_string(), (w - 2) as usize);
        let s = format!(" {p} ");
        let x = self.x + 1 + (w - s.chars().count() as i32) / 2;
        ui.write_xyfb(x, 3, 0, if on { 2 } else { 3 }, &s);
    }

    /// Frame, column heads and click points of the file window.
    pub fn draw_frame(&self, ui: &mut Ui) {
        let rows = ui.rows();
        let iw = self.iw();
        let lr = Self::list_rows(rows);
        ui.frame(self.x, 5, iw, lr + 2, 11, 1, false, false);
        let c = ui.cols();
        ui.window(1, 1, c, rows);
        let x = self.x;
        // menu dots 1 2 3, and ▲ ↨ \ at the right
        for i in 0..3 {
            ui.poke(x + 2 + 2 * i, 5, 0x1E07); // • (CP437 7 is BEL for write)
        }
        ui.write_xyfb(x + iw - 5, 5, 14, 1, "▲");
        ui.write_xyfb(x + iw - 3, 5, 14, 1, "↨");
        ui.write_xyfb(x + iw - 1, 5, 14, 1, "\\");
        let seps = self.seps();
        for &s in &seps {
            ui.write_xyfb(x + s, 5, 11, 1, "┬");
        }
        // separator above the status line
        let y = 5 + lr + 1;
        ui.set_color(11, 1);
        ui.goto_xy(x, y);
        let mut line = String::from("├");
        for i in 1..=iw {
            line.push(if seps.contains(&i) { '┴' } else { '─' });
        }
        ui.write(&line);
        ui.write_xyfb(x + iw + 1, y, 0, 1, "│");
    }

    /// Columns (relative to the frame's left edge) of the vertical separators.
    fn seps(&self) -> Vec<i32> {
        let iw = self.iw();
        match self.view {
            View::Full => {
                let n = self.name_w();
                vec![n + 1, n + 11, n + 20]
            }
            View::Long => vec![iw - 9],
            View::Three | View::Five => {
                let c = if self.view == View::Three { 3 } else { 5 };
                let cw = (iw - (c - 1)) / c;
                (1..c).map(|i| i * (cw + 1)).collect()
            }
        }
    }

    /// Text of entry `i` for its cell in the current view.
    fn cell(&self, e: &Entry) -> (String, usize) {
        let iw = self.iw() as usize;
        match self.view {
            View::Full => (self.line(e, iw), iw),
            View::Long => {
                let size = if e.is_up() {
                    "►UP--DIR◄".to_string()
                } else if e.is_dir {
                    "►SUB-DIR◄".to_string()
                } else {
                    format!("{:>9}", files::human(e.size))
                };
                let nw = iw - 10;
                (format!("{}│{size}", fit(&e.name, nw)), iw)
            }
            View::Three | View::Five => {
                let c = if self.view == View::Three { 3 } else { 5 };
                let cw = (iw - (c - 1)) / c;
                let n = if cw >= 12 { Self::name_field(e, cw) } else { fit(&e.name, cw) };
                (n, cw)
            }
        }
    }

    fn colors(&self, e: &Entry, cursor: bool, active: bool) -> (u8, u8) {
        let fg = if e.marked {
            MARK_FG
        } else if e.is_dir {
            11
        } else {
            self.colors.get(&e.ext().to_lowercase()).copied().unwrap_or(11)
        };
        if cursor && active { (if e.marked { MARK_FG } else { 0 }, 3) } else { (fg, 1) }
    }

    pub fn draw_files(&mut self, ui: &mut Ui, active: bool) {
        let rows = ui.rows();
        self.fix_top(rows);
        let (r, c) = self.layout(rows);
        let iw = self.iw();
        let seps = self.seps();
        for col in 0..c {
            for row in 0..r {
                let i = self.top + col * r + row;
                let y = 6 + row as i32;
                let (x, w) = if c == 1 {
                    (self.x + 1, iw as usize)
                } else {
                    let cw = (iw - (c as i32 - 1)) / c as i32;
                    (self.x + 1 + col as i32 * (cw + 1), cw as usize)
                };
                match self.entries.get(i) {
                    Some(e) => {
                        let (s, _) = self.cell(e);
                        let (fg, bg) = self.colors(e, i == self.cur, active);
                        ui.write_xyfb(x, y, fg, bg, &fit(&s, w));
                        if i == self.cur && active && c == 1 {
                            // the bar spans the separators too
                        }
                    }
                    None => {
                        let mut s = " ".repeat(w);
                        if c == 1 {
                            let mut v: Vec<char> = s.chars().collect();
                            for &sp in &seps {
                                if let Some(ch) = v.get_mut(sp as usize - 1) {
                                    *ch = '│';
                                }
                            }
                            s = v.into_iter().collect();
                        }
                        ui.write_xyfb(x, y, 11, 1, &s);
                    }
                }
            }
            if col + 1 < c {
                let cw = (iw - (c as i32 - 1)) / c as i32;
                for row in 0..r {
                    ui.write_xyfb(self.x + 1 + (col as i32 + 1) * (cw + 1) - 1, 6 + row as i32, 11, 1, "│");
                }
            }
        }
        if let Some(err) = &self.error {
            let s = fit(&format!(" {err} "), iw as usize - 2);
            ui.write_xyfb(self.x + 2, 6 + r as i32 - 1, 15, 4, &s);
        }
        self.draw_status(ui);
    }

    /// The line under the file window: the cursor entry, or the sum of the marked files.
    pub fn draw_status(&self, ui: &mut Ui) {
        let rows = ui.rows();
        let y = rows - 3;
        let iw = self.iw() as usize;
        let marked = self.marked();
        let s = if !marked.is_empty() {
            let bytes: u64 = marked.iter().map(|e| e.size).sum();
            let n = marked.len();
            format!("{} in {n} marked file{}", files::human(bytes), if n == 1 { "" } else { "s" })
        } else if let Some(e) = self.current() {
            let nw = self.name_w().max(1) as usize;
            let size = if e.is_up() {
                "►UP--DIR◄".to_string()
            } else if e.is_dir {
                "►SUB-DIR◄".to_string()
            } else {
                files::human(e.size)
            };
            let (d, t) = files::date_time(e.mtime);
            let name = fit(&e.name, nw);
            format!("{name}{size:>10} {d}{t:>7}")
        } else {
            String::new()
        };
        let fg = if marked.is_empty() { 11 } else { MARK_FG };
        ui.write_xyfb(self.x + 1, y, fg, 1, &fit(&s, iw));
    }

    pub fn draw(&mut self, ui: &mut Ui, active: bool) {
        self.draw_path(ui);
        self.highlight_path(ui, active);
        self.draw_frame(ui);
        self.draw_files(ui, active);
    }

    /// Entry index under screen position (x, y), if any.
    pub fn hit(&self, rows: i32, x: i32, y: i32) -> Option<usize> {
        let (r, c) = self.layout(rows);
        if y < 6 || y >= 6 + r as i32 || x <= self.x || x >= self.x + self.w - 1 {
            return None;
        }
        let col = if c == 1 {
            0
        } else {
            let cw = (self.iw() - (c as i32 - 1)) / c as i32;
            ((x - self.x - 1) / (cw + 1)) as usize
        };
        let i = self.top + col.min(c - 1) * r + (y - 6) as usize;
        (i < self.entries.len()).then_some(i)
    }
}

/// Pads or cuts `s` to exactly `w` characters.
pub fn fit(s: &str, w: usize) -> String {
    let n = s.chars().count();
    if n <= w {
        format!("{s}{}", " ".repeat(w - n))
    } else if w > 1 {
        let mut t: String = s.chars().take(w - 1).collect();
        t.push('»');
        t
    } else {
        s.chars().take(w).collect()
    }
}

/// Shortens a path in the middle ("/Us...ix/Projects") to `w` characters.
pub fn shorten(s: &str, w: usize) -> String {
    let n = s.chars().count();
    if n <= w || w < 8 {
        return s.chars().take(w.max(n.min(w))).collect();
    }
    let keep = w - 3;
    let head = keep / 3;
    let tail = keep - head;
    let a: String = s.chars().take(head).collect();
    let b: String = s.chars().skip(n - tail).collect();
    format!("{a}...{b}")
}
