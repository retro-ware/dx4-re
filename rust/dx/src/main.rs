//! dx — the DOS-Expander main program (DXMAIN.EXE) for modern terminals: two file panels, menu bar, function
//! key bar, command line and the DX tools. Spec: src/dxmain/, ref/dxmain/*.SCR, ref/help/dxhelp.de.txt.

mod cmds;
mod cmdline;
mod dlg;
mod files;
mod hexedit;
mod ops;
mod panel;
mod tools;
mod viewer;

use cmds::*;
use dxtui::keys::*;
use dxtui::menubar::MenuBar;
use dxtui::settings::{home_dir, Settings};
use dxtui::ui::Ui;
use dxtui::Crt;
use files::Sort;
use panel::{Panel, View};
use std::path::{Path, PathBuf};
use std::process::Command;

pub struct App {
    pub ui: Ui,
    pub p: [Panel; 2],
    /// Active panel.
    pub act: usize,
    pub bar: MenuBar,
    pub conf: Settings,
    pub home: PathBuf,
    /// Modifier set shown in the function key bar (0 none, 1 Shift, 2 Ctrl, 3 Alt).
    pub fmod: usize,
    pub history: Vec<String>,
    pub quickview: bool,
    pub last_menu_cmd: u16,
    pub password: String,
    pub quit: bool,
}

const HIST_MAX: usize = 25;

/// Returned by `App::mouse` for a double click on a file.
const DOUBLE_CLICK: u16 = 0xFFFE;

impl App {
    fn new(ui: Ui, conf: Settings, home: PathBuf) -> App {
        let cwd = std::env::current_dir().unwrap_or_else(|_| files::home());
        let mut p = [Panel::new(cwd.clone()), Panel::new(cwd)];
        for (i, side) in ["left", "right"].iter().enumerate() {
            if let Some(d) = conf.get(&format!("{side}.path")) {
                if Path::new(d).is_dir() && std::env::args().len() < 2 {
                    p[i].path = d.into();
                }
            }
            p[i].sort = Sort::from_str(&conf.str_or(&format!("{side}.sort"), "ext"));
            p[i].reverse = conf.flag(&format!("{side}.reverse"), false);
            p[i].filter = conf.str_or(&format!("{side}.filter"), "*");
            p[i].hidden = conf.flag("hidden", false);
            p[i].view = match conf.str_or(&format!("{side}.view"), "full").as_str() {
                "three" => View::Three,
                "five" => View::Five,
                "long" => View::Long,
                _ => View::Full,
            };
        }
        if let Some(a) = std::env::args().nth(1) {
            p[0].path = std::fs::canonicalize(&a).unwrap_or(a.into());
        }
        let colors = file_colors(&conf);
        for q in &mut p {
            q.colors = colors.clone();
        }
        let history = std::fs::read_to_string(home.join("dxhist.txt"))
            .map(|s| s.lines().map(String::from).collect())
            .unwrap_or_default();
        let password = conf.str_or("password", "");
        let act = conf.num("active", 0usize).min(1);
        let mut a = App {
            ui,
            p,
            act,
            bar: cmds::menu_bar(),
            conf,
            home,
            fmod: 0,
            history,
            quickview: false,
            last_menu_cmd: 0,
            password,
            quit: false,
        };
        for i in 0..2 {
            let path = a.p[i].path.clone();
            if !a.p[i].chdir(&path) {
                a.p[i].chdir(&files::home());
            }
        }
        a
    }

    pub fn save_state(&mut self) {
        for (i, side) in ["left", "right"].iter().enumerate() {
            let p = &self.p[i];
            self.conf.set(&format!("{side}.path"), p.path.display());
            self.conf.set(&format!("{side}.sort"), p.sort.as_str());
            self.conf.set(&format!("{side}.reverse"), p.reverse);
            self.conf.set(&format!("{side}.filter"), &p.filter);
            let v = match p.view {
                View::Full => "full",
                View::Three => "three",
                View::Five => "five",
                View::Long => "long",
            };
            self.conf.set(&format!("{side}.view"), v);
        }
        self.conf.set("hidden", self.p[0].hidden);
        self.conf.set("active", self.act);
        let _ = self.conf.save();
        let _ = std::fs::create_dir_all(&self.home);
        let _ = std::fs::write(self.home.join("dxhist.txt"), self.history.join("\n"));
    }

    pub fn other(&self) -> usize {
        1 - self.act
    }

    pub fn cur(&mut self) -> &mut Panel {
        &mut self.p[self.act]
    }

    // --- screen ---

    /// Matches the logical screen to the terminal and places the panels.
    fn layout(&mut self) {
        let (w, h) = self.ui.term_size();
        let (w, h) = (w.max(80), h.max(25));
        if (w, h) != (self.ui.cols(), self.ui.rows()) {
            self.ui.resize(w, h);
        }
        let half = w / 2;
        self.p[0].x = 1;
        self.p[0].w = half;
        self.p[1].x = half + 1;
        self.p[1].w = w - half;
        self.ui.clock.x = w - 5;
    }

    pub fn redraw(&mut self) {
        self.layout();
        let (c, r) = (self.ui.cols(), self.ui.rows());
        self.ui.window(1, 1, c, r);
        self.ui.set_color(0, 3);
        self.ui.clr_scr();
        self.draw_top();
        for i in 0..2 {
            self.draw_panel(i);
        }
        self.draw_places();
        self.draw_fkeys();
    }

    fn draw_top(&mut self) {
        let c = self.ui.cols();
        self.ui.window(1, 1, c, 1);
        self.ui.set_color(0, 3);
        self.ui.clr_eol();
        self.ui.write_xyf(1, 1, 4, "*");
        self.bar.draw(&mut self.ui, None);
        self.ui.clock.last_date.clear();
        self.ui.clock.last_time.clear();
        self.ui.update_clock();
    }

    pub fn draw_panel(&mut self, i: usize) {
        let active = i == self.act;
        if self.quickview && i != self.act {
            self.draw_quickview(i);
            return;
        }
        let ui = &mut self.ui;
        self.p[i].draw(ui, active);
    }

    /// Redraws the file lists only (cursor moves).
    pub fn draw_files(&mut self) {
        for i in 0..2 {
            if self.quickview && i != self.act {
                self.draw_quickview(i);
            } else {
                let a = i == self.act;
                self.p[i].draw_files(&mut self.ui, a);
                self.p[i].highlight_path(&mut self.ui, a);
            }
        }
    }

    /// Quickview (Alt-2): the start of the cursor file in the other panel.
    fn draw_quickview(&mut self, i: usize) {
        let src = self.p[self.act].cur_path();
        let rows = self.ui.rows();
        let (x, w) = (self.p[i].x, self.p[i].w);
        self.ui.frame(x, 2, w - 2, rows - 5, 11, 1, false, false);
        let c = self.ui.cols();
        self.ui.window(1, 1, c, rows);
        let title = " Quickview ";
        self.ui.write_xyfb(x + (w - title.len() as i32) / 2, 2, 14, 1, title);
        let lines = (rows - 5) as usize;
        let text = match &src {
            Some(p) if p.is_file() => {
                let mut buf = vec![0u8; 16384];
                let n = std::fs::File::open(p).and_then(|mut f| std::io::Read::read(&mut f, &mut buf)).unwrap_or(0);
                buf.truncate(n);
                String::from_utf8_lossy(&buf).into_owned()
            }
            Some(p) if p.is_dir() => {
                let mut v: Vec<String> = std::fs::read_dir(p)
                    .map(|r| r.flatten().map(|e| e.file_name().to_string_lossy().into_owned()).collect())
                    .unwrap_or_default();
                v.sort();
                v.join("\n")
            }
            _ => String::new(),
        };
        for (n, l) in text.lines().chain(std::iter::repeat("")).take(lines).enumerate() {
            let l = l.replace('\t', "    ");
            self.ui.write_xyfb(x + 1, 3 + n as i32, 11, 1, &panel::fit(&l, (w - 2) as usize));
        }
    }

    /// The places bar under the panels (the drive line of the original).
    fn draw_places(&mut self) {
        let r = self.ui.rows() - 1;
        let places = dxtui::ui::places();
        for i in 0..2 {
            let (x, w) = (self.p[i].x, self.p[i].w);
            self.ui.write_xyfb(x, r, 14, 1, &" ".repeat(w as usize));
            self.ui.write_xyfb(x + 1, r, 14, 1, "◄");
            let cur = places.iter().rposition(|d| self.p[i].path.starts_with(d));
            let mut col = x + 2;
            for (k, pl) in places.iter().enumerate() {
                let name = place_name(pl);
                let n = name.chars().count() as i32 + 2;
                if col + n > x + w - 2 {
                    break;
                }
                if Some(k) == cur {
                    self.ui.write_xyfb(col, r, 14, 1, &format!("[{name}]"));
                } else {
                    self.ui.write_xyfb(col, r, 3, 1, ".");
                    self.ui.write_xyfb(col + 1, r, 11, 1, &name);
                    self.ui.write_xyfb(col + n - 1, r, 3, 1, ".");
                }
                col += n;
            }
            self.ui.write_xyfb(x + w - 2, r, 14, 1, "►");
        }
    }

    fn fkey_layout(&self) -> Vec<(i32, i32)> {
        let labels = &FKEYS[self.fmod];
        let c = self.ui.cols();
        let total: i32 = labels.iter().enumerate().map(|(i, l)| (i + 1).to_string().len() as i32 + l.len() as i32 + 2).sum();
        let extra = ((c - 1 - total) / 10).max(0);
        let mut x = 2;
        let mut v = vec![];
        for (i, l) in labels.iter().enumerate() {
            let w = (i + 1).to_string().len() as i32 + l.len() as i32 + 2 + extra;
            v.push((x, w));
            x += w;
        }
        v
    }

    pub fn draw_fkeys(&mut self) {
        let r = self.ui.rows();
        let c = self.ui.cols();
        self.ui.window(1, 1, c, r);
        self.ui.set_color(0, 3);
        self.ui.goto_xy(1, r);
        self.ui.clr_eol();
        self.ui.poke(1, r, 0x3E07); // •
        let lay = self.fkey_layout();
        for (i, l) in FKEYS[self.fmod].iter().enumerate() {
            let (x, _) = lay[i];
            self.ui.write_xyf(x, r, 4, &(i + 1).to_string());
            self.ui.write_xyf(x + (i + 1).to_string().len() as i32, r, 0, &format!(" {l} "));
        }
        let m = ["", "Shift", "Ctrl", "Alt"][self.fmod];
        if !m.is_empty() {
            self.ui.write_xyfb(c - m.len() as i32, r, 15, 3, m);
        }
    }

    fn fkey_at(&self, x: i32) -> Option<usize> {
        self.fkey_layout().iter().position(|&(a, w)| x >= a && x < a + w).map(|i| i + 1)
    }

    // --- running programs ---

    /// Runs a shell command in the active panel's directory, then waits for a key.
    pub fn run(&mut self, cmd: &str, wait: bool) {
        let dir = self.p[self.act].path.clone();
        self.ui.suspend();
        println!("{}$ {cmd}", dir.display());
        let shell = std::env::var("SHELL").unwrap_or_else(|_| "/bin/sh".into());
        let st = Command::new(&shell).arg("-c").arg(cmd).current_dir(&dir).status();
        if let Err(e) = st {
            println!("dx: {e}");
        }
        if wait {
            wait_key();
        }
        self.ui.resume();
        self.after_shell();
    }

    /// Runs a program directly (editor, viewer, dxm).
    pub fn run_prog(&mut self, prog: &str, args: &[&str]) -> Option<std::process::ExitStatus> {
        let dir = self.p[self.act].path.clone();
        self.ui.suspend();
        let mut parts = prog.split_whitespace();
        let exe = parts.next().unwrap_or(prog);
        let r = Command::new(exe).args(parts).args(args).current_dir(&dir).status();
        if let Err(e) = &r {
            println!("dx: {prog}: {e}");
            wait_key();
        }
        self.ui.resume();
        self.after_shell();
        r.ok()
    }

    fn after_shell(&mut self) {
        for i in 0..2 {
            self.p[i].reload();
        }
        self.ui.reset_idle();
        self.redraw();
    }

    pub fn add_history(&mut self, cmd: &str) {
        if cmd.trim().is_empty() {
            return;
        }
        self.history.retain(|h| h != cmd);
        self.history.push(cmd.to_string());
        if self.history.len() > HIST_MAX {
            self.history.remove(0);
        }
    }

    /// Return on a file: a directory is entered, an executable started, else the association runs.
    fn enter(&mut self) {
        let Some(e) = self.p[self.act].current().cloned() else { return };
        if e.is_dir {
            let path = self.p[self.act].path.join(&e.name);
            if e.is_up() {
                self.p[self.act].up();
            } else if !self.p[self.act].chdir(&path) {
                dlg::info(&mut self.ui, "Change directory", &[format!("{} cannot be opened.", path.display())]);
            }
            self.redraw_panel(self.act);
            return;
        }
        if let Some(cmd) = tools::association(self, &e.name) {
            self.add_history(&cmd);
            self.run(&cmd, true);
            return;
        }
        if e.executable() {
            let cmd = format!("./{}", shell_quote(&e.name));
            self.add_history(&cmd);
            self.run(&cmd, true);
        } else {
            let p = self.p[self.act].path.join(&e.name);
            viewer::view(&mut self.ui, &p);
        }
    }

    pub fn redraw_panel(&mut self, i: usize) {
        self.draw_panel(i);
        if self.quickview {
            self.draw_panel(1 - i);
        }
        self.draw_places();
    }

    fn switch(&mut self) {
        self.act = self.other();
        if self.quickview {
            self.redraw();
        } else {
            self.draw_files();
        }
    }

    pub fn reload_all(&mut self) {
        for i in 0..2 {
            self.p[i].reload();
        }
        self.redraw();
    }

    // --- commands ---

    pub fn command(&mut self, c: u16) {
        if c != AGAIN && c != 0 {
            self.last_menu_cmd = c;
        }
        let a = self.act;
        match c {
            0 => {}
            HELP => dxtui::help::show_help(&mut self.ui, 0),
            QUIT => {
                if !self.conf.flag("confirm_quit", true)
                    || dlg::confirm(&mut self.ui, "Quit", &["Quit the DOS-Expander?"], true)
                {
                    self.quit = true;
                }
            }
            VIEW | INT_VIEW => {
                if let Some(p) = self.p[a].cur_path().filter(|p| p.is_file()) {
                    viewer::view(&mut self.ui, &p);
                }
            }
            EXT_VIEW => {
                if let Some(e) = self.p[a].current().filter(|e| !e.is_dir).cloned() {
                    let v = self.conf.str_or("viewer", "less");
                    self.run_prog(&v, &[&e.name]);
                }
            }
            EDIT => {
                if let Some(e) = self.p[a].current().filter(|e| !e.is_dir).cloned() {
                    let ed = editor(&self.conf);
                    self.run_prog(&ed, &[&e.name]);
                }
            }
            EDIT_NEW => {
                let mut s = String::new();
                if dlg::ask(&mut self.ui, "Edit new file", "Name of the file:", &mut s, 255) && !s.trim().is_empty() {
                    let ed = editor(&self.conf);
                    self.run_prog(&ed, &[s.trim()]);
                    self.p[a].reload();
                    self.p[a].select(s.trim());
                    self.redraw();
                }
            }
            COPY | RENMOV => {
                let items = self.p[a].targets();
                let src = self.p[a].path.clone();
                let dst = self.p[1 - a].path.clone();
                let changed = if c == COPY {
                    ops::copy(&mut self.ui, &src, &items, &dst)
                } else {
                    ops::rename_move(&mut self.ui, &src, &items, &dst)
                };
                if changed {
                    for e in &mut self.p[a].entries {
                        e.marked = false;
                    }
                    self.reload_all();
                }
            }
            MKDIR => {
                let dir = self.p[a].path.clone();
                if let Some(n) = ops::mkdir(&mut self.ui, &dir) {
                    self.p[a].reload();
                    self.p[a].select(&n);
                    if self.p[1 - a].path == dir {
                        self.p[1 - a].reload();
                    }
                    self.redraw();
                }
            }
            DELETE => {
                let items = self.p[a].targets();
                let dir = self.p[a].path.clone();
                let ask = self.conf.flag("confirm_delete", true);
                if ops::delete(&mut self.ui, &dir, &items, ask) {
                    self.reload_all();
                }
            }
            SWAP => {
                self.p.swap(0, 1);
                self.act = 1 - self.act;
                self.redraw();
            }
            HIDDEN => {
                let h = !self.p[0].hidden;
                for i in 0..2 {
                    self.p[i].hidden = h;
                }
                self.reload_all();
            }
            LONG_NAMES | VIEW3 | VIEW5 => {
                let v = match c {
                    LONG_NAMES => View::Long,
                    VIEW3 => View::Three,
                    _ => View::Five,
                };
                let p = &mut self.p[a];
                p.view = if p.view == v { View::Full } else { v };
                self.redraw_panel(a);
            }
            QUICKVIEW => {
                self.quickview = !self.quickview;
                self.redraw();
            }
            LEFT_PLACE | RIGHT_PLACE => {
                let i = if c == LEFT_PLACE { 0 } else { 1 };
                self.choose_place(i);
            }
            FULL_SHELL => {
                let sh = std::env::var("SHELL").unwrap_or_else(|_| "/bin/sh".into());
                self.ui.suspend();
                println!("Type 'exit' to return to the DOS-Expander.");
                let _ = Command::new(&sh).current_dir(&self.p[a].path).status();
                self.ui.resume();
                self.after_shell();
            }
            SHELL_SCREEN => {
                self.ui.suspend();
                wait_key();
                self.ui.resume();
                self.redraw();
            }
            LAST_CMD => {
                let last = self.history.last().cloned().unwrap_or_default();
                cmdline::command_line(self, &last);
            }
            HISTORY => cmdline::history_list(self),
            USER_MENU => self.user_menu(),
            SAVER_NOW => {
                let pw = self.password.clone();
                dxtui::saver::screen_saver(&mut self.ui, &pw);
            }
            LOAD => {
                let path = self.conf.path().to_path_buf();
                let ui = std::mem::replace(&mut self.ui, Ui::new(Crt::new(80, 25)));
                let mut a = App::new(ui, Settings::load(&path), self.home.clone());
                a.ui.saver_delay = a.conf.num("saver_delay", 0u32);
                *self = a;
                self.redraw();
            }
            SAVE => {
                self.save_state();
                dlg::info(&mut self.ui, "Settings", &[format!("Saved to {}", self.home.join("dx.conf").display())]);
            }
            AGAIN => {
                let c = self.last_menu_cmd;
                if c != 0 {
                    self.command(c);
                }
            }
            _ => tools::command(self, c),
        }
    }

    fn user_menu(&mut self) {
        let exe = std::env::current_exe().ok().and_then(|p| p.parent().map(|d| d.join("dxm")));
        let prog = exe.filter(|p| p.exists()).map(|p| p.display().to_string()).unwrap_or_else(|| "dxm".into());
        self.run_prog(&prog, &[]);
    }

    pub fn choose_place(&mut self, i: usize) {
        let x = self.p[i].x + 2;
        let cur = self.p[i].path.clone();
        if let Some(p) = self.ui.select_place(x, 4, &cur) {
            self.p[i].chdir(&p);
            self.act = i;
            self.redraw();
        }
    }

    // --- panel menus 1, 2, 3 ---

    fn panel_menu(&mut self, n: u8) {
        let a = self.act;
        let x = self.p[a].x + 1;
        let items: Vec<(&str, u16)> = match n {
            1 => vec![
                ("Sort by ~name", 1),
                ("Sort by ~extension", 2),
                ("Sort by ~size", 3),
                ("Sort by ~time", 4),
                ("~Unsorted", 5),
                ("~Reverse order", 6),
                ("~Filter...", 7),
                ("~All files", 8),
            ],
            2 => vec![
                ("~Mark files...", 11),
                ("~Unmark files...", 12),
                ("~Invert marks", 13),
                ("Unmark ~all", 14),
                ("~Same directory as other panel", 15),
                ("~Home directory", 16),
            ],
            _ => vec![("~Add current directory", 21u16), ("~Remove current directory", 22)],
        };
        let mut bm: Vec<String> = vec![];
        let mut texts: Vec<String> = items.iter().map(|(t, _)| t.to_string()).collect();
        let mut codes: Vec<u16> = items.iter().map(|&(_, c)| c).collect();
        if n == 3 {
            bm = self.bookmarks();
            for (k, b) in bm.iter().enumerate() {
                texts.push(format!("~{} {}", (b'a' + k as u8) as char, panel::shorten(b, 40)));
                codes.push(100 + k as u16);
            }
        }
        let mut menu = MenuBar::new(
            vec![dxtui::menubar::Menu {
                title: String::new(),
                items: texts.iter().zip(&codes).map(|(t, &c)| dxtui::menubar::Item::new(t, "", c)).collect(),
            }],
            x,
        );
        menu.xs[0] = x + 1;
        let Some(c) = run_popup(&mut self.ui, &mut menu) else {
            self.redraw();
            return;
        };
        let p = &mut self.p[a];
        match c {
            1..=5 => {
                p.sort = [Sort::Name, Sort::Ext, Sort::Size, Sort::Time, Sort::None][(c - 1) as usize];
                p.reload();
            }
            6 => {
                p.reverse = !p.reverse;
                p.reload();
            }
            7 => {
                let mut f = p.filter.clone();
                if dlg::ask(&mut self.ui, "Filter", "Show files matching (e.g. *.txt;*.md):", &mut f, 80) {
                    let p = &mut self.p[a];
                    p.filter = if f.trim().is_empty() { "*".into() } else { f.trim().into() };
                    p.reload();
                }
            }
            8 => {
                p.filter = "*".into();
                p.reload();
            }
            11 | 12 => {
                let mut m = "*".to_string();
                let t = if c == 11 { "Mark files" } else { "Unmark files" };
                if dlg::ask(&mut self.ui, t, "Files matching:", &mut m, 80) {
                    self.p[a].mark_all(&m, c == 11, false);
                }
            }
            13 => p.invert(),
            14 => p.mark_all("*", false, true),
            15 => {
                let o = self.p[1 - a].path.clone();
                self.p[a].chdir(&o);
            }
            16 => {
                self.p[a].chdir(&files::home());
            }
            21 => {
                let s = p.path.display().to_string();
                bm.retain(|b| *b != s);
                bm.push(s);
                bm.truncate(16);
                self.conf.set("bookmarks", bm.join("\t"));
            }
            22 => {
                if let Some(i) = bm.iter().position(|b| Path::new(b) == p.path) {
                    bm.remove(i);
                    self.conf.set("bookmarks", bm.join("\t"));
                }
            }
            k if k >= 100 => {
                if let Some(b) = bm.get((k - 100) as usize) {
                    let b = PathBuf::from(b);
                    self.p[a].chdir(&b);
                }
            }
            _ => {}
        }
        self.redraw();
    }

    fn bookmarks(&self) -> Vec<String> {
        self.conf.str_or("bookmarks", "").split('\t').filter(|s| !s.is_empty()).map(String::from).collect()
    }

    // --- quick search (Space) ---

    fn quick_search(&mut self, first: Option<char>) {
        let a = self.act;
        let rows = self.ui.rows();
        let (x, w) = (self.p[a].x, self.p[a].w);
        let y = rows - 3;
        let mut s: String = first.map(String::from).unwrap_or_default();
        self.ui.open_dialog();
        loop {
            let t = format!(" Search: {s}");
            self.ui.write_xyfb(x + 1, y, 0, 3, &panel::fit(&t, (w - 2) as usize));
            if !s.is_empty() {
                let low = s.to_lowercase();
                let p = &mut self.p[a];
                let start = p.cur;
                let n = p.entries.len();
                if let Some(i) = (0..n).map(|k| (start + k) % n).find(|&i| p.entries[i].name.to_lowercase().starts_with(&low)) {
                    p.cur = i;
                }
                self.p[a].draw_files(&mut self.ui, true);
                self.ui.write_xyfb(x + 1, y, 0, 3, &panel::fit(&t, (w - 2) as usize));
            }
            let k = self.ui.read_key();
            match k {
                BKSP => {
                    s.pop();
                }
                ESC | ENTER | TAB => break,
                UP | DOWN => {
                    let p = &mut self.p[a];
                    let low = s.to_lowercase();
                    let n = p.entries.len();
                    let step = |i: usize| if k == DOWN { (i + 1) % n } else { (i + n - 1) % n };
                    let mut i = step(p.cur);
                    for _ in 0..n {
                        if p.entries[i].name.to_lowercase().starts_with(&low) {
                            p.cur = i;
                            break;
                        }
                        i = step(i);
                    }
                }
                k => match Key::new(k).char() {
                    Some(c) => s.push(c),
                    None => break,
                },
            }
        }
        self.ui.pop_screen();
        self.draw_files();
    }

    // --- main loop ---

    fn move_cursor(&mut self, key: u16) -> bool {
        let rows = self.ui.rows();
        let a = self.act;
        let p = &mut self.p[a];
        let n = p.entries.len();
        if n == 0 {
            return false;
        }
        let (r, cols) = p.layout(rows);
        let page = p.page(rows);
        let shift = self.ui.crt.shift;
        let old = p.cur;
        match key {
            UP => p.cur = p.cur.saturating_sub(1),
            DOWN => p.cur = (p.cur + 1).min(n - 1),
            PGUP => p.cur = p.cur.saturating_sub(page.max(2) - 1),
            PGDN => p.cur = (p.cur + page.max(2) - 1).min(n - 1),
            HOME | CTRL_HOME | CTRL_PGUP => p.cur = 0,
            END | CTRL_END | CTRL_PGDN => p.cur = n - 1,
            LEFT if cols > 1 => p.cur = p.cur.saturating_sub(r),
            RIGHT if cols > 1 => p.cur = (p.cur + r).min(n - 1),
            _ => return false,
        }
        if shift && (key == UP || key == DOWN) {
            if !p.entries[old].is_up() {
                p.entries[old].marked = !p.entries[old].marked;
            }
        }
        if self.quickview {
            self.draw_panel(1 - a);
        }
        true
    }

    fn mouse(&mut self) -> u16 {
        let m = self.ui.mouse;
        let rows = self.ui.rows();
        if m.button == 0 {
            return 0;
        }
        // top line
        if m.y == 1 {
            if m.x <= 2 && m.button == 1 {
                self.ui.wait_release();
                return QUICK;
            }
            if m.x >= self.ui.cols() - 2 {
                self.ui.wait_release();
                return if m.button == 1 { SAVER_NOW } else { SHELL_SCREEN };
            }
            if let Some(i) = self.bar.title_at(m.x) {
                if let Some(c) = self.bar.run(&mut self.ui, i) {
                    return c;
                }
                self.draw_top();
            }
            return 0;
        }
        // function key bar
        if m.y == rows {
            self.ui.wait_release();
            if m.button == 2 {
                self.fmod = (self.fmod + 3) % 4;
                self.draw_fkeys();
                return 0;
            }
            if m.x == 1 {
                return QUICK;
            }
            let c = self.fkey_at(m.x).map(|n| fkey_cmd(self.fmod, n)).unwrap_or(0);
            if self.fmod != 0 {
                self.fmod = 0;
                self.draw_fkeys();
            }
            return c;
        }
        // places bar
        if m.y == rows - 1 {
            self.ui.wait_release();
            let i = if m.x > self.p[0].w { 1 } else { 0 };
            self.choose_place(i);
            return 0;
        }
        let i = if m.x > self.p[0].w { 1 } else { 0 };
        // path box
        if (2..=4).contains(&m.y) {
            self.ui.wait_release();
            if m.button == 1 {
                self.choose_place(i);
                return 0;
            }
            self.act = i;
            return QCD;
        }
        // frame top: menus and click points
        if m.y == 5 {
            self.ui.wait_release();
            let (x, iw) = (self.p[i].x, self.p[i].w - 2);
            if i != self.act {
                self.act = i;
                self.draw_files();
            }
            match m.x - x {
                2 => self.panel_menu(1),
                4 => self.panel_menu(2),
                6 => self.panel_menu(3),
                d if d == iw - 5 => {
                    self.p[i].up();
                    self.redraw_panel(i);
                }
                d if d == iw - 3 => {
                    self.p[i].reload();
                    self.redraw_panel(i);
                }
                d if d == iw - 1 => {
                    self.p[i].chdir(Path::new("/"));
                    self.redraw_panel(i);
                }
                _ => {}
            }
            return 0;
        }
        // file list
        if let Some(e) = self.p[i].hit(rows, m.x, m.y) {
            if i != self.act {
                self.act = i;
            }
            self.p[i].cur = e;
            self.draw_files();
            if m.button == 2 {
                let en = &mut self.p[i].entries[e];
                if !en.is_up() {
                    en.marked = !en.marked;
                }
                self.ui.wait_release();
                self.draw_files();
                return 0;
            }
            if self.ui.double_click(m.x, m.y) {
                self.ui.wait_release();
                return DOUBLE_CLICK;
            }
            // dragging: scroll at the edges
            while self.ui.mouse.button == 1 {
                self.ui.pump();
                let m = self.ui.mouse;
                if let Some(e) = self.p[i].hit(rows, m.x, m.y) {
                    if e != self.p[i].cur {
                        self.p[i].cur = e;
                        self.draw_files();
                    }
                } else if m.y < 6 {
                    self.move_cursor(UP);
                    self.draw_files();
                } else if m.y > 5 + Panel::list_rows(rows) {
                    self.move_cursor(DOWN);
                    self.draw_files();
                }
                if self.ui.crt.term.is_none() {
                    break;
                }
            }
        } else {
            self.ui.wait_release();
        }
        0
    }

    fn key(&mut self, key: u16) {
        let a = self.act;
        let ctrl = self.ui.crt.ctrl;
        let alt = self.ui.crt.alt;
        let shift = self.ui.crt.shift;
        if self.move_cursor(key) {
            self.draw_files();
            return;
        }
        if let Some(i) = self.bar.by_alt(key) {
            if let Some(c) = self.bar.run(&mut self.ui, i) {
                self.command(c);
            }
            self.draw_top();
            return;
        }
        let fk = |base: u16| (base..base + 10).contains(&key).then(|| (key - base + 1) as usize);
        if let Some(n) = fk(F1) {
            return self.command(fkey_cmd(0, n));
        }
        if let Some(n) = fk(SHIFT_F1) {
            return self.command(fkey_cmd(1, n));
        }
        if let Some(n) = fk(CTRL_F1) {
            return self.command(fkey_cmd(2, n));
        }
        if let Some(n) = fk(ALT_F1) {
            return self.command(fkey_cmd(3, n));
        }
        if let Some(c) = alt_letter_of(key) {
            let cmd = match c {
                'x' => QUIT,
                'a' => ASCII,
                'b' => HISTORY,
                'c' => QUICK,
                'g' => SYSINFO,
                'h' => HEXDEC,
                'k' => KEYTEST,
                'l' => DRIVES,
                'n' => NOTES,
                'q' => VIEW3,
                'r' => CALC,
                's' => DRIVE_STAT,
                't' => SWAP,
                'v' => DIR_SIZES,
                'w' => VIEW5,
                'y' => SAVER_NOW,
                'z' => CLOCK,
                _ => 0,
            };
            return self.command(cmd);
        }
        if alt {
            match key {
                k if k == alt_digit(1) => return self.command(LONG_NAMES),
                k if k == alt_digit(2) => return self.command(QUICKVIEW),
                k if k == alt_digit(3) => return self.command(VIEW3),
                k if k == alt_digit(5) => return self.command(VIEW5),
                32 => return self.panel_menu(1),
                _ => {}
            }
        }
        match key {
            ENTER => self.enter(),
            10 => {
                // Ctrl-Return: command line with the names, on a directory its size
                if let Some(e) = self.p[a].current().cloned() {
                    if e.is_dir {
                        tools::dir_info(self);
                    } else {
                        let mut names: Vec<String> = self.p[a].marked().iter().map(|e| shell_quote(&e.name)).collect();
                        if names.is_empty() {
                            names.push(shell_quote(&e.name));
                        }
                        cmdline::command_line(self, &format!(" {}", names.join(" ")));
                    }
                }
            }
            TAB => self.switch(),
            LEFT | RIGHT => self.switch(),
            INS | DEL => {
                let p = &mut self.p[a];
                if let Some(e) = p.entries.get_mut(p.cur) {
                    if !e.is_up() {
                        e.marked = key == INS;
                    }
                }
                self.move_cursor(DOWN);
                self.draw_files();
            }
            BKSP => self.command(LAST_CMD),
            15 => self.command(FULL_SHELL), // Ctrl-O
            17 => self.command(INT_VIEW),   // Ctrl-Q
            32 if ctrl => self.panel_menu(2),
            32 if shift => self.panel_menu(3),
            32 => self.quick_search(None),
            k if k == b'1' as u16 => self.panel_menu(1),
            k if k == b'2' as u16 => self.panel_menu(2),
            k if k == b'3' as u16 => self.panel_menu(3),
            k if k == b'+' as u16 || k == b'-' as u16 => {
                let on = k == b'+' as u16;
                let mut m = "*".to_string();
                if dlg::ask(&mut self.ui, if on { "Mark" } else { "Unmark" }, "Files matching:", &mut m, 80) {
                    self.p[a].mark_all(&m, on, false);
                }
                self.draw_files();
            }
            k if k == b'*' as u16 => {
                self.p[a].invert();
                self.draw_files();
            }
            k if k == b'~' as u16 => {
                self.p[a].mark_all("*", false, true);
                self.draw_files();
            }
            k if k == b'/' as u16 => {
                self.p[a].reload();
                self.redraw_panel(a);
            }
            k if k == b'\\' as u16 => {
                self.p[a].chdir(Path::new("/"));
                self.redraw_panel(a);
            }
            k if k == b'.' as u16 => {
                self.p[a].up();
                self.redraw_panel(a);
            }
            k if k == b'#' as u16 => {
                if let Some(e) = self.p[a].current().cloned() {
                    let p = self.p[a].path.join(&e.name);
                    let mut l = vec![p.display().to_string(), files::owner_mode(&e)];
                    if e.is_link {
                        if let Ok(t) = std::fs::read_link(&p) {
                            l.push(format!("-> {}", t.display()));
                        }
                    }
                    dlg::info(&mut self.ui, "Name", &l);
                }
            }
            k => {
                if let Some(c) = Key::new(k).char() {
                    if ctrl || alt {
                        return;
                    }
                    cmdline::command_line(self, &c.to_string());
                }
            }
        }
    }

    fn main_loop(&mut self) {
        self.redraw();
        let mut size = self.ui.term_size();
        while !self.quit {
            let key = self.ui.get_key();
            if self.ui.saver_due {
                let pw = self.password.clone();
                dxtui::saver::screen_saver(&mut self.ui, &pw);
            }
            if self.ui.term_size() != size {
                size = self.ui.term_size();
                self.redraw();
            }
            if key == 0 {
                let c = self.mouse();
                if c == DOUBLE_CLICK {
                    self.enter();
                    continue;
                } else if c != 0 {
                    self.command(c);
                    continue;
                } else {
                    continue;
                }
            }
            if self.fmod != 0 {
                self.fmod = 0;
                self.draw_fkeys();
            }
            self.key(key);
        }
    }
}

/// Colours of files by extension: `color.EXT = n` entries, defaults as in the DX 4 distribution
/// (programs red, pictures yellow); `file_colors = off` switches them off.
pub fn file_colors(conf: &Settings) -> std::collections::HashMap<String, u8> {
    let mut m = std::collections::HashMap::new();
    if !conf.flag("file_colors", true) {
        return m;
    }
    for e in ["bat", "exe", "com", "sh", "cmd", "btm"] {
        m.insert(e.to_string(), 4);
    }
    for e in ["bmp", "gif", "pcx", "jpg", "jpeg", "png", "tif", "tiff", "webp", "svg"] {
        m.insert(e.to_string(), 14);
    }
    for (k, v) in conf.with_prefix("color.") {
        if let Ok(n) = v.parse::<u8>() {
            m.insert(k[6..].to_lowercase(), n & 15);
        }
    }
    m
}

/// Lets a run program's output be read before the screen comes back.
pub fn wait_key() {
    use std::io::{BufRead, Write};
    print!("\nPress Return to continue...");
    let _ = std::io::stdout().flush();
    let mut s = String::new();
    let _ = std::io::stdin().lock().read_line(&mut s);
}

pub fn editor(conf: &Settings) -> String {
    conf.get("editor")
        .map(String::from)
        .or_else(|| std::env::var("VISUAL").ok())
        .or_else(|| std::env::var("EDITOR").ok())
        .unwrap_or_else(|| "vi".into())
}

pub fn shell_quote(s: &str) -> String {
    if s.chars().all(|c| c.is_ascii_alphanumeric() || "._-+/=:,@%".contains(c)) {
        s.to_string()
    } else {
        format!("'{}'", s.replace('\'', "'\\''"))
    }
}

pub fn place_name(p: &Path) -> String {
    if p == Path::new("/") {
        return "/".into();
    }
    if Some(p) == std::env::var_os("HOME").as_deref().map(Path::new) {
        return "~".into();
    }
    p.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_else(|| p.display().to_string())
}

/// A single pull-down at the bar position of `menu` (the panel menus).
fn run_popup(ui: &mut Ui, menu: &mut MenuBar) -> Option<u16> {
    let save = ui.save();
    let r = menu.run(ui, 0);
    ui.restore(&save);
    r
}

fn main() {
    let home = home_dir();
    let conf = Settings::load(&home.join("dx.conf"));
    let crt = match Crt::open(80, 25) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("dx: {e}");
            std::process::exit(1);
        }
    };
    let mut ui = Ui::new(crt);
    ui.clock.long_year = true;
    ui.clock.fg = 0;
    ui.clock.bg = 3;
    ui.saver_delay = conf.num("saver_delay", 0u32);
    let mut app = App::new(ui, conf, home);
    app.main_loop();
    app.save_state();
}

#[cfg(test)]
mod tests {
    use super::*;
    use files::Entry;
    use std::time::{Duration, SystemTime};

    fn reference(name: &str) -> Vec<u8> {
        std::fs::read(Path::new(env!("CARGO_MANIFEST_DIR")).join("../../ref/dxmain").join(name)).unwrap()
    }

    /// The panels of ref/dxmain/MAIN.SCR: C:\ of the test machine, captured on 14.10.26 at 8:28.
    fn app(dirs: &[&str], hm: (i32, i32)) -> App {
        let home = std::env::temp_dir().join(format!("dx-test-{}", std::process::id()));
        let mut a = App::new(Ui::new(Crt::new(80, 25)), Settings::load(&home.join("dx.conf")), home);
        // 2026-10-14 08:28 local time
        let mut tm: libc::tm = unsafe { std::mem::zeroed() };
        tm.tm_year = 126;
        tm.tm_mon = 9;
        tm.tm_mday = 14;
        tm.tm_hour = hm.0;
        tm.tm_min = hm.1;
        tm.tm_isdst = -1;
        let t = SystemTime::UNIX_EPOCH + Duration::from_secs(unsafe { libc::mktime(&mut tm) } as u64);
        let files = [("lpt2", 0), ("readme", 14640), ("dx.bat", 174), ("menu.bat", 153), ("dxoffice.bmp", 790),
            ("balken.bss", 4064), ("diamant.bss", 27520), ("fadenkr.bss", 9040), ("fall.bss", 4208),
            ("flammen.bss", 6704), ("raupe.bss", 9424), ("regen.bss", 4752), ("rgbcym.bss", 4768),
            ("scan.bss", 27392), ("schnee.bss", 27344)];
        for p in &mut a.p {
            p.path = "/".into();
            p.entries = dirs
                .iter()
                .map(|&n| (n, 0, true))
                .chain(files.iter().map(|&(n, s)| (n, s, false)))
                .map(|(n, s, d)| Entry { name: n.into(), is_dir: d, is_link: false, size: s, mtime: t, mode: 0o644,
                    marked: false })
                .collect();
            p.cur = 0;
            p.top = 0;
        }
        a.act = 0;
        a
    }

    #[test]
    fn main_screen_matches_original() {
        let mut a = app(&[], (8, 28));
        a.redraw();
        compare(&a, "MAIN.SCR");
    }

    #[test]
    fn panel_with_dirs_matches_original() {
        let mut a = app(&["GAMES", "TOOLS"], (8, 29));
        a.p[0].cur = 2;
        a.redraw();
        compare(&a, "PANEL.SCR");
    }

    fn compare(a: &App, name: &str) {
        let scr = reference(name);
        let cells = a.ui.cells().to_vec();
        let mut bad = vec![];
        for i in 0..80 * 25 {
            let (ch, at) = (scr[2 * i], scr[2 * i + 1]);
            let (x, y) = (i % 80 + 1, i / 80 + 1);
            // translated or system-specific: menu bar and clock, path text, places bar, function key labels
            let skip_ch = y == 1 || y == 3 || y >= 24;
            // (41,13) holds the DOS mouse cursor
            let skip_at = (x, y) == (41, 13) || y == 1 || y == 3 || y == 24 || y == 25 && x > 1;
            if !skip_at && (cells[i] >> 8) as u8 != at || !skip_ch && cells[i] as u8 != ch {
                bad.push(format!("({x},{y}) {:04x} want {:02x}{:02x}", cells[i], at, ch));
            }
        }
        assert!(bad.is_empty(), "{} cells differ: {:?}", bad.len(), &bad[..bad.len().min(400)]);
    }
}
