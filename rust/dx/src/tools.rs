//! The DX tools behind the menus: info boxes, calculator, ASCII table, calendar, stopwatches, file search,
//! compare, archives, configuration. Spec: help pages in ref/help/dxhelp.de.txt.

use crate::cmds::*;
use crate::files::{self, Entry};
use crate::{dlg, panel, shell_quote, App};
use dxtui::keys::*;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

pub fn command(app: &mut App, c: u16) {
    match c {
        ABOUT => about(app),
        STATUS => status(app),
        ENV => env(app),
        CALENDAR => calendar(app),
        STOPWATCH => stopwatch(app),
        SYSINFO => sysinfo(app),
        KEYTEST => keytest(app),
        EDIT_MENU => app.command(USER_MENU),
        HEXEDIT => {
            if let Some(p) = app.p[app.act].cur_path().filter(|p| p.is_file()) {
                crate::hexedit::edit(&mut app.ui, &p);
                app.p[app.act].reload();
                app.redraw();
            }
        }
        ATTRIB => attrib(app),
        TOUCH => touch(app),
        FIND => find(app),
        GREP => grep(app),
        COMPARE => compare(app),
        QCD => qcd(app),
        SPLIT => split(app),
        JOIN => join(app),
        DUPES => dupes(app),
        SYNC => sync(app),
        DIR_SIZES => dir_sizes(app),
        MARK_DIRSIZES => dir_info(app),
        DRIVES => drives(app),
        DRIVE_STAT => drive_stat(app),
        CALC => calc(app),
        ASCII => ascii(app),
        HEXDEC => hexdec(app),
        QUICK => quick(app),
        NOTES => {
            let p = app.home.join("notes.txt");
            let ed = crate::editor(&app.conf);
            let _ = std::fs::create_dir_all(&app.home);
            app.run_prog(&ed, &[&p.display().to_string()]);
        }
        CLOCK => clock(app),
        SYSFILES => sysfiles(app),
        PACK => pack(app),
        ARC_VIEW => arc(app, false),
        ARC_TEST => arc(app, true),
        UNPACK => unpack(app),
        CONFIG => config(app),
        SAVER => saver(app),
        SAVE_AS | LOAD_FROM => save_load(app, c == SAVE_AS),
        RESET => {
            if dlg::confirm(&mut app.ui, "Reset", &["Reset all settings to the defaults?"], false) {
                app.conf.clear();
                let _ = app.conf.save();
                app.command(LOAD);
            }
        }
        ASSOC => assoc(app),
        _ => dlg::info(&mut app.ui, "DOS-Expander", &["This function is not available.".into()]),
    }
}

// --- helpers ---

fn output(cmd: &str, dir: &Path) -> String {
    match Command::new("sh").arg("-c").arg(cmd).current_dir(dir).output() {
        Ok(o) => {
            let mut s = String::from_utf8_lossy(&o.stdout).into_owned();
            s += &String::from_utf8_lossy(&o.stderr);
            s
        }
        Err(e) => format!("{cmd}: {e}"),
    }
}

fn walk(dir: &Path, depth: usize, hidden: bool, f: &mut dyn FnMut(&Path, &std::fs::Metadata) -> bool) -> bool {
    let Ok(rd) = std::fs::read_dir(dir) else { return true };
    for e in rd.flatten() {
        let p = e.path();
        if !hidden && e.file_name().to_string_lossy().starts_with('.') {
            continue;
        }
        let Ok(m) = std::fs::symlink_metadata(&p) else { continue };
        if !f(&p, &m) {
            return false;
        }
        if m.is_dir() && depth > 0 && !walk(&p, depth - 1, hidden, f) {
            return false;
        }
    }
    true
}

fn tree_size(p: &Path, ui: &mut dxtui::ui::Ui) -> (u64, u64, bool) {
    let (mut bytes, mut n) = (0u64, 0u64);
    let mut count = 0;
    let ok = walk(p, 64, true, &mut |_, m| {
        if m.is_file() {
            bytes += m.len();
            n += 1;
        }
        count += 1;
        !(count % 2000 == 0 && dlg::interrupted(ui))
    });
    (bytes, n, ok)
}

/// Goes to file `p` in the active panel.
fn goto(app: &mut App, p: &Path) {
    let a = app.act;
    if p.is_dir() {
        app.p[a].chdir(p);
    } else if let (Some(d), Some(n)) = (p.parent(), p.file_name()) {
        app.p[a].chdir(d);
        app.p[a].select(&n.to_string_lossy());
    }
    app.redraw();
}

fn rel(base: &Path, p: &Path) -> String {
    p.strip_prefix(base).unwrap_or(p).display().to_string()
}

pub fn association(app: &App, name: &str) -> Option<String> {
    let ext = files::split_ext(name).1.to_lowercase();
    if ext.is_empty() {
        return None;
    }
    let cmd = app.conf.get(&format!("assoc.{ext}"))?;
    let q = shell_quote(name);
    Some(if cmd.contains("%f") { cmd.replace("%f", &q) } else { format!("{cmd} {q}") })
}

// --- info ---

fn about(app: &mut App) {
    dlg::info(&mut app.ui, "DOS-Expander", &[
        "DOS-Expander 4 for modern terminals".into(),
        format!("Version {}", env!("CARGO_PKG_VERSION")),
        String::new(),
        "A clone of the DX 4 file manager in Rust.".into(),
        "F1 shows the help.".into(),
    ]);
}

fn status(app: &mut App) {
    let mut l = vec![];
    for (i, side) in ["Left", "Right"].iter().enumerate() {
        let p = &app.p[i];
        let files = p.entries.iter().filter(|e| !e.is_dir).count();
        let dirs = p.entries.iter().filter(|e| e.is_dir && !e.is_up()).count();
        let bytes: u64 = p.entries.iter().filter(|e| !e.is_dir).map(|e| e.size).sum();
        l.push(format!("{side} panel: {}", panel::shorten(&p.path.display().to_string(), 50)));
        l.push(format!("  {files} files ({} bytes), {dirs} directories, {} marked", panel::group(bytes),
            p.marked().len()));
        if let Some((free, total)) = files::disk_space(&p.path) {
            l.push(format!("  {} of {} bytes free", panel::group(free), panel::group(total)));
        }
    }
    l.push(format!("Settings: {}", app.conf.path().display()));
    l.push(format!("Commands in the history: {}", app.history.len()));
    dlg::info(&mut app.ui, "Program status", &l);
}

fn env(app: &mut App) {
    let mut v: Vec<String> = std::env::vars().map(|(k, v)| format!("{k}={v}")).collect();
    v.sort();
    dlg::list(&mut app.ui, "Environment", &v, 0);
}

fn sysinfo(app: &mut App) {
    let dir = app.p[app.act].path.clone();
    let mut l: Vec<String> = output("uname -srmn; uptime", &dir).lines().map(String::from).collect();
    l.push(format!("User: {}", std::env::var("USER").unwrap_or_default()));
    l.push(format!("Shell: {}", std::env::var("SHELL").unwrap_or_default()));
    l.push(format!("Terminal: {} ({}x{})", std::env::var("TERM").unwrap_or_default(), app.ui.cols(), app.ui.rows()));
    if let Ok(n) = std::thread::available_parallelism() {
        l.push(format!("CPUs: {n}"));
    }
    dlg::info(&mut app.ui, "System info", &l);
}

fn keytest(app: &mut App) {
    let ui = &mut app.ui;
    ui.open_dialog();
    let (x, y) = ((ui.cols() - 44) / 2, (ui.rows() - 6) / 2);
    ui.frame(x, y, 42, 5, 11, 3, false, true);
    ui.write_center_xyfb(1, 1, 42, 14, 3, "Key test");
    ui.write_xyfb(3, 5, 0, 3, "Press keys; Esc twice ends.");
    let mut last = 0;
    loop {
        let k = ui.get_key();
        if k == 0 {
            continue;
        }
        let mods = format!("{}{}{}", if ui.alt { "Alt " } else { "" }, if ui.ctrl { "Ctrl " } else { "" },
            if ui.shift { "Shift" } else { "" });
        let ch = Key::new(k).char().map(|c| format!("'{c}'")).unwrap_or_default();
        ui.write_xyfb(3, 3, 0, 3, &panel::fit(&format!("Code {k:5}  {ch:5} {mods}"), 38));
        if k == ESC && last == ESC {
            break;
        }
        last = k;
    }
    ui.close_dialog();
}

// --- clock, calendar, stopwatches ---

fn days_in(y: u32, m: u32) -> u32 {
    match m {
        2 if y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) => 29,
        2 => 28,
        4 | 6 | 9 | 11 => 30,
        _ => 31,
    }
}

/// Weekday (0 = Sunday) of a date.
pub fn weekday(y: u32, m: u32, d: u32) -> u32 {
    let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
    let y = if m < 3 { y - 1 } else { y };
    (y + y / 4 - y / 100 + y / 400 + t[m as usize - 1] + d) % 7
}

const MONTHS: [&str; 12] = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
    "October", "November", "December"];

fn calendar(app: &mut App) {
    let (ty, tm, td, _) = dxtui::time::today();
    let (mut y, mut m) = (ty, tm);
    let ui = &mut app.ui;
    ui.open_dialog();
    let (x0, y0) = ((ui.cols() - 30) / 2, (ui.rows() - 11) / 2);
    loop {
        ui.frame(x0, y0, 28, 9, 11, 3, false, true);
        let (c, r) = (ui.cols(), ui.rows());
        ui.window(1, 1, c, r);
        ui.write_center_xyfb(x0 + 1, y0 + 1, 28, 14, 3, &format!("{} {y}", MONTHS[m as usize - 1]));
        ui.write_xyfb(x0 + 2, y0 + 2, 0, 3, "Mo  Tu  We  Th  Fr  Sa  Su");
        let first = (weekday(y, m, 1) + 6) % 7;
        for d in 1..=days_in(y, m) {
            let i = first + d - 1;
            let (col, row) = ((i % 7) as i32, (i / 7) as i32);
            let today = (y, m, d) == (ty, tm, td);
            let fg = if col >= 5 { 4 } else { 0 };
            ui.write_xyfb(x0 + 2 + col * 4, y0 + 3 + row, if today { 15 } else { fg }, if today { 1 } else { 3 },
                &format!("{d:2}"));
        }
        ui.write_xyfb(x0 + 2, y0 + 9, 0, 3, "PgUp/PgDn ←→: month, ↑↓: year");
        let k = ui.read_key();
        match k {
            PGUP | LEFT => {
                if m == 1 {
                    m = 12;
                    y -= 1;
                } else {
                    m -= 1;
                }
            }
            PGDN | RIGHT => {
                if m == 12 {
                    m = 1;
                    y += 1;
                } else {
                    m += 1;
                }
            }
            UP => y -= 1,
            DOWN => y += 1,
            HOME => (y, m) = (ty, tm),
            _ => break,
        }
    }
    ui.close_dialog();
}

fn clock(app: &mut App) {
    let ui = &mut app.ui;
    ui.open_dialog();
    let (x0, y0) = ((ui.cols() - 32) / 2, (ui.rows() - 6) / 2);
    ui.frame(x0, y0, 30, 4, 11, 3, false, true);
    ui.write_center_xyfb(1, 1, 30, 14, 3, "Time and date");
    loop {
        let (h, mi, s) = dxtui::time::now_hms();
        let (y, m, d, wd) = dxtui::time::today();
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
        ui.write_center_xyfb(1, 3, 30, 15, 3, &format!("{h:02}:{mi:02}:{s:02}"));
        ui.write_center_xyfb(1, 4, 30, 0, 3, &format!("{}, {d} {} {y}", days[wd as usize], MONTHS[m as usize - 1]));
        if ui.get_key() != 0 || ui.mouse.button != 0 {
            break;
        }
    }
    ui.close_dialog();
}

fn stopwatch(app: &mut App) {
    // four watches; 1-4 start/stop, Shift-1..4 / R reset
    let mut acc = [0f64; 4];
    let mut run: [Option<Instant>; 4] = [None; 4];
    let ui = &mut app.ui;
    ui.open_dialog();
    let (x0, y0) = ((ui.cols() - 40) / 2, (ui.rows() - 10) / 2);
    ui.frame(x0, y0, 38, 8, 11, 3, false, true);
    ui.write_center_xyfb(1, 1, 38, 14, 3, "Stopwatches");
    ui.write_xyfb(3, 8, 0, 3, "1-4 start/stop  R reset all  Esc end");
    loop {
        for i in 0..4 {
            let t = acc[i] + run[i].map_or(0.0, |s| s.elapsed().as_secs_f64());
            let (h, m, s) = ((t / 3600.0) as u64, (t / 60.0) as u64 % 60, t % 60.0);
            let st = if run[i].is_some() { "running" } else { "stopped" };
            ui.write_xyfb(3, 3 + i as i32, 0, 3, &format!("{}:  {h:2}:{m:02}:{s:05.2}   {st}", i + 1));
        }
        let k = ui.get_key();
        match k {
            0 => continue,
            k if (b'1' as u16..=b'4' as u16).contains(&k) => {
                let i = (k - b'1' as u16) as usize;
                match run[i].take() {
                    Some(s) => acc[i] += s.elapsed().as_secs_f64(),
                    None => run[i] = Some(Instant::now()),
                }
            }
            k if k == b'r' as u16 || k == b'R' as u16 => {
                acc = [0.0; 4];
                run = [None; 4];
            }
            _ => break,
        }
    }
    ui.close_dialog();
}

// --- numbers ---

/// Number in DX notation: decimal, $hex / 0x / h suffix, 0b / b suffix, 'c'.
pub fn parse_num(s: &str) -> Option<i64> {
    let s = s.trim();
    let neg = s.starts_with('-');
    let s = s.trim_start_matches('-');
    let v = if let Some(h) = s.strip_prefix('$').or_else(|| s.strip_prefix("0x")).or_else(|| s.strip_prefix("0X")) {
        i64::from_str_radix(h, 16).ok()
    } else if let Some(b) = s.strip_prefix("0b") {
        i64::from_str_radix(b, 2).ok()
    } else if s.len() == 3 && s.starts_with('\'') && s.ends_with('\'') {
        Some(s.chars().nth(1)? as i64)
    } else if let Some(h) = s.strip_suffix(['h', 'H']) {
        i64::from_str_radix(h, 16).ok()
    } else if s.len() > 1 && s.ends_with(['b', 'B']) && s[..s.len() - 1].chars().all(|c| c == '0' || c == '1') {
        i64::from_str_radix(&s[..s.len() - 1], 2).ok()
    } else {
        s.parse().ok()
    }?;
    Some(if neg { -v } else { v })
}

fn bases(v: i64) -> Vec<String> {
    let mut l = vec![
        format!("Decimal:     {v}"),
        format!("Hexadecimal: {:X}h", v),
        format!("Octal:       {:o}", v),
        format!("Binary:      {:b}", v),
    ];
    if (32..256).contains(&v) {
        l.push(format!("Character:   '{}'", dxtui::cp437::decode(&[v as u8])));
    }
    l
}

fn hexdec(app: &mut App) {
    let mut s = String::new();
    while dlg::ask(&mut app.ui, "Hex-dec-bin", "Number (123, $7B, 7Bh, 0x7B, 1111011b, 'c'):", &mut s, 40) {
        match parse_num(&s) {
            Some(v) => dlg::info(&mut app.ui, "Hex-dec-bin", &bases(v)),
            None => dlg::info(&mut app.ui, "Hex-dec-bin", &[format!("'{s}' is not a number.")]),
        }
    }
}

/// Expression calculator: + - * / % ^, parentheses, numbers in DX notation.
pub fn eval(s: &str) -> Result<f64, String> {
    struct P<'a> {
        t: &'a [u8],
        i: usize,
    }
    impl P<'_> {
        fn ws(&mut self) {
            while self.i < self.t.len() && self.t[self.i] == b' ' {
                self.i += 1;
            }
        }
        fn peek(&mut self) -> Option<u8> {
            self.ws();
            self.t.get(self.i).copied()
        }
        fn expr(&mut self) -> Result<f64, String> {
            let mut v = self.term()?;
            while let Some(c @ (b'+' | b'-')) = self.peek() {
                self.i += 1;
                let r = self.term()?;
                v = if c == b'+' { v + r } else { v - r };
            }
            Ok(v)
        }
        fn term(&mut self) -> Result<f64, String> {
            let mut v = self.pow()?;
            while let Some(c @ (b'*' | b'/' | b'%')) = self.peek() {
                self.i += 1;
                let r = self.pow()?;
                if c != b'*' && r == 0.0 {
                    return Err("Division by zero".into());
                }
                v = match c {
                    b'*' => v * r,
                    b'/' => v / r,
                    _ => v % r,
                };
            }
            Ok(v)
        }
        fn pow(&mut self) -> Result<f64, String> {
            let b = self.unary()?;
            if self.peek() == Some(b'^') {
                self.i += 1;
                return Ok(b.powf(self.pow()?));
            }
            Ok(b)
        }
        fn unary(&mut self) -> Result<f64, String> {
            match self.peek() {
                Some(b'-') => {
                    self.i += 1;
                    Ok(-self.unary()?)
                }
                Some(b'(') => {
                    self.i += 1;
                    let v = self.expr()?;
                    if self.peek() != Some(b')') {
                        return Err("')' expected".into());
                    }
                    self.i += 1;
                    Ok(v)
                }
                Some(_) => {
                    let st = self.i;
                    while self.i < self.t.len()
                        && (self.t[self.i].is_ascii_alphanumeric() || b".$'".contains(&self.t[self.i]))
                    {
                        self.i += 1;
                    }
                    let w = std::str::from_utf8(&self.t[st..self.i]).unwrap_or("");
                    if w.is_empty() {
                        return Err(format!("Unexpected '{}'", self.t[st] as char));
                    }
                    if let Ok(f) = w.parse::<f64>() {
                        return Ok(f);
                    }
                    parse_num(w).map(|v| v as f64).ok_or_else(|| format!("'{w}' is not a number"))
                }
                None => Err("Number expected".into()),
            }
        }
    }
    let mut p = P { t: s.as_bytes(), i: 0 };
    let v = p.expr()?;
    if p.peek().is_some() {
        return Err(format!("Unexpected '{}'", p.t[p.i] as char));
    }
    Ok(v)
}

fn calc(app: &mut App) {
    let mut s = String::new();
    while dlg::ask(&mut app.ui, "Calculator", "Expression (+ - * / % ^ and parentheses):", &mut s, 200) {
        let l = match eval(&s) {
            Ok(v) if v.fract() == 0.0 && v.abs() < 9e15 => {
                let mut l = vec![format!("{s} =")];
                l.extend(bases(v as i64));
                l
            }
            Ok(v) => vec![format!("{s} ="), format!("{v}")],
            Err(e) => vec![e],
        };
        dlg::info(&mut app.ui, "Calculator", &l);
        if let Ok(v) = eval(&s) {
            s = format!("{v}");
        }
    }
}

fn ascii(app: &mut App) {
    let ui = &mut app.ui;
    ui.open_dialog();
    let (x0, y0) = ((ui.cols() - 52) / 2, (ui.rows() - 21) / 2);
    ui.frame(x0, y0, 50, 19, 11, 3, false, true);
    ui.write_center_xyfb(1, 1, 50, 14, 3, "ASCII table");
    let mut cur: u16 = b'A' as u16;
    loop {
        let (c, r) = (ui.cols(), ui.rows());
        ui.window(1, 1, c, r);
        for i in 0..256u16 {
            let (col, row) = ((i % 16) as i32, (i / 16) as i32);
            let ch = if i == 0 { b' ' } else { i as u8 };
            let (fg, bg) = if i == cur { (15, 1) } else { (0, 3) };
            ui.poke(x0 + 3 + col * 3, y0 + 2 + row, ((bg << 4 | fg) as u16) << 8 | ch as u16);
            ui.write_xyfb(x0 + 2 + col * 3, y0 + 2 + row, 0, 3, " ");
        }
        ui.write_xyfb(x0 + 2, y0 + 19, 0, 3, &panel::fit(&format!("Dec {cur:3}  Hex {cur:02X}h  Oct {cur:03o}  Bin {cur:08b}"), 48));
        let k = ui.read_key();
        match k {
            LEFT => cur = (cur + 255) % 256,
            RIGHT => cur = (cur + 1) % 256,
            UP => cur = (cur + 240) % 256,
            DOWN => cur = (cur + 16) % 256,
            HOME => cur = 0,
            END => cur = 255,
            k if k < 256 && k != ESC && k != ENTER => cur = k,
            _ => break,
        }
    }
    ui.close_dialog();
}

// --- quick menu ---

fn quick(app: &mut App) {
    let items: [(&str, u16); 14] = [
        ("Calculator", CALC),
        ("ASCII table", ASCII),
        ("Hex-dec-bin", HEXDEC),
        ("Calendar", CALENDAR),
        ("Time and date", CLOCK),
        ("Stopwatches", STOPWATCH),
        ("Notes", NOTES),
        ("Command history", HISTORY),
        ("Find files", FIND),
        ("Quick change dir", QCD),
        ("Directory sizes", DIR_SIZES),
        ("Drive overview", DRIVES),
        ("Environment", ENV),
        ("Screen saver now", SAVER_NOW),
    ];
    let lines: Vec<String> = items.iter().map(|(t, _)| t.to_string()).collect();
    if let Some(i) = dlg::list(&mut app.ui, "Quick menu", &lines, 0) {
        app.command(items[i].1);
    }
}

// --- files ---

fn attrib(app: &mut App) {
    let a = app.act;
    let items = app.p[a].targets();
    if items.is_empty() {
        return;
    }
    let mut s = format!("{:o}", items[0].mode & 0o7777);
    let what = if items.len() == 1 { items[0].name.clone() } else { format!("{} files", items.len()) };
    if !dlg::ask(&mut app.ui, "Attributes", &format!("Mode of {what} (octal or u+x, go-w, ...):"), &mut s, 40) {
        return;
    }
    let dir = app.p[a].path.clone();
    let mut errs = vec![];
    for e in &items {
        let p = dir.join(&e.name);
        let r = if let Ok(m) = u32::from_str_radix(s.trim(), 8) {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&p, std::fs::Permissions::from_mode(m)).map_err(|e| e.to_string())
        } else {
            let o = Command::new("chmod").arg(s.trim()).arg(&p).output();
            match o {
                Ok(o) if o.status.success() => Ok(()),
                Ok(o) => Err(String::from_utf8_lossy(&o.stderr).trim().to_string()),
                Err(e) => Err(e.to_string()),
            }
        };
        if let Err(err) = r {
            errs.push(format!("{}: {err}", e.name));
        }
    }
    if !errs.is_empty() {
        dlg::info(&mut app.ui, "Attributes", &errs);
    }
    app.p[a].reload();
    app.redraw();
}

fn touch(app: &mut App) {
    let a = app.act;
    let items = app.p[a].targets();
    if items.is_empty() {
        return;
    }
    let (y, m, d, h, mi, s) = dxtui::time::local_of(items[0].mtime);
    let mut t = format!("{y:04}-{m:02}-{d:02} {h:02}:{mi:02}:{s:02}");
    if !dlg::ask(&mut app.ui, "Time and date", "New time stamp (YYYY-MM-DD hh:mm:ss, empty = now):", &mut t, 19) {
        return;
    }
    let digits: String = t.chars().filter(|c| c.is_ascii_digit()).collect();
    let arg = if digits.is_empty() {
        None
    } else if digits.len() == 14 {
        Some(format!("{}.{}", &digits[..12], &digits[12..]))
    } else if digits.len() == 12 {
        Some(digits)
    } else {
        dlg::info(&mut app.ui, "Time and date", &[format!("'{t}' is not a valid time stamp.")]);
        return;
    };
    let dir = app.p[a].path.clone();
    for e in &items {
        let mut c = Command::new("touch");
        if let Some(a) = &arg {
            c.arg("-t").arg(a);
        }
        let _ = c.arg(dir.join(&e.name)).output();
    }
    app.p[a].reload();
    app.redraw();
}

fn find(app: &mut App) {
    let mut mask = app.conf.str_or("find.mask", "*");
    if !dlg::ask(&mut app.ui, "Find files", "Names (wildcards, several with ';'):", &mut mask, 200) {
        return;
    }
    app.conf.set("find.mask", &mask);
    let base = app.p[app.act].path.clone();
    dlg::wait_box(&mut app.ui, &format!("Searching {}", panel::shorten(&base.display().to_string(), 50)));
    let mut found = vec![];
    let hidden = app.p[app.act].hidden;
    let ui = &mut app.ui;
    let mut n = 0;
    walk(&base, 64, hidden, &mut |p, _| {
        n += 1;
        if let Some(name) = p.file_name() {
            if files::matches_any(&mask, &name.to_string_lossy()) {
                found.push(p.to_path_buf());
            }
        }
        !(n % 2000 == 0 && dlg::interrupted(ui)) && found.len() < 5000
    });
    app.ui.pop_screen();
    let lines: Vec<String> = found.iter().map(|p| rel(&base, p)).collect();
    if let Some(i) = dlg::list(&mut app.ui, &format!("{} found", found.len()), &lines, 0) {
        goto(app, &found[i]);
    }
}

fn grep(app: &mut App) {
    let a = app.act;
    let mut items = app.p[a].marked().into_iter().cloned().collect::<Vec<Entry>>();
    let all = items.is_empty();
    if all {
        items = app.p[a].entries.iter().filter(|e| !e.is_dir).cloned().collect();
    }
    let mut s = app.conf.str_or("grep.text", "");
    let what = if all { "all files".to_string() } else { format!("{} marked files", items.len()) };
    if !dlg::ask(&mut app.ui, "Search text", &format!("Text to find in {what} (case ignored):"), &mut s, 200)
        || s.is_empty()
    {
        return;
    }
    app.conf.set("grep.text", &s);
    let pat = s.to_lowercase().into_bytes();
    let dir = app.p[a].path.clone();
    let mut hits = vec![];
    for e in &items {
        let Ok(buf) = std::fs::read(dir.join(&e.name)) else { continue };
        let low: Vec<u8> = buf.iter().map(|b| b.to_ascii_lowercase()).collect();
        let mut line = 1;
        let mut start = 0;
        for (i, &b) in low.iter().enumerate() {
            if low[i..].starts_with(&pat) {
                let end = buf[i..].iter().position(|&c| c == b'\n').map_or(buf.len(), |p| i + p);
                let text = String::from_utf8_lossy(&buf[start..end]).trim().to_string();
                hits.push((e.name.clone(), format!("{}:{line}: {}", e.name, text)));
                if hits.len() > 2000 {
                    break;
                }
            }
            if b == b'\n' {
                line += 1;
                start = i + 1;
            }
        }
    }
    let lines: Vec<String> = hits.iter().map(|h| h.1.clone()).collect();
    if let Some(i) = dlg::list(&mut app.ui, &format!("'{s}': {} lines", hits.len()), &lines, 0) {
        let n = hits[i].0.clone();
        app.p[a].select(&n);
        app.redraw();
        crate::viewer::view(&mut app.ui, &dir.join(&n));
    }
}

/// Alt-F9: marks the files that are missing in the other panel or differ (size, newer).
fn compare(app: &mut App) {
    let (a, o) = (app.act, app.other());
    let mut n = [0usize; 2];
    for (i, j) in [(a, o), (o, a)] {
        let other: Vec<Entry> = app.p[j].entries.clone();
        let mut cnt = 0;
        for e in app.p[i].entries.iter_mut() {
            if e.is_dir {
                continue;
            }
            e.marked = match other.iter().find(|x| x.name == e.name && !x.is_dir) {
                None => true,
                Some(x) => x.size != e.size || e.mtime > x.mtime,
            };
            cnt += e.marked as usize;
        }
        n[if i == a { 0 } else { 1 }] = cnt;
    }
    app.redraw();
    dlg::info(&mut app.ui, "Compare directories", &[
        format!("{} files marked in the active panel,", n[0]),
        format!("{} in the other panel", n[1]),
        "(missing on the other side, different size or newer).".into(),
    ]);
}

fn qcd_index(app: &mut App) -> Vec<String> {
    let p = app.home.join("qcd.txt");
    if let Ok(s) = std::fs::read_to_string(&p) {
        return s.lines().map(String::from).collect();
    }
    rescan_qcd(app)
}

fn rescan_qcd(app: &mut App) -> Vec<String> {
    let root = files::home();
    dlg::wait_box(&mut app.ui, &format!("Reading the directory tree of {}", root.display()));
    let mut v = vec![];
    walk(&root, 8, false, &mut |p, m| {
        if m.is_dir() {
            v.push(p.display().to_string());
        }
        v.len() < 50000
    });
    app.ui.pop_screen();
    v.sort();
    let _ = std::fs::create_dir_all(&app.home);
    let _ = std::fs::write(app.home.join("qcd.txt"), v.join("\n"));
    v
}

/// Alt-F10: quick change dir — a part of the name; "!" rereads the tree.
fn qcd(app: &mut App) {
    let mut s = String::new();
    if !dlg::ask(&mut app.ui, "Quick change dir", "Part of the directory name ('!' rereads the tree):", &mut s, 80) {
        return;
    }
    let s = s.trim().to_lowercase();
    let dirs = if s == "!" { rescan_qcd(app) } else { qcd_index(app) };
    if s == "!" {
        return;
    }
    let hits: Vec<String> = dirs
        .into_iter()
        .filter(|d| Path::new(d).file_name().is_some_and(|n| n.to_string_lossy().to_lowercase().contains(&s)))
        .collect();
    match hits.len() {
        0 => dlg::info(&mut app.ui, "Quick change dir", &[format!("No directory matches '{s}'."),
            "Enter '!' to reread the tree.".into()]),
        1 => goto(app, &PathBuf::from(&hits[0])),
        _ => {
            if let Some(i) = dlg::list(&mut app.ui, "Quick change dir", &hits, 0) {
                goto(app, &PathBuf::from(&hits[i]));
            }
        }
    }
}

fn split(app: &mut App) {
    let a = app.act;
    let Some(e) = app.p[a].current().filter(|e| !e.is_dir).cloned() else { return };
    let mut s = "1440k".to_string();
    if !dlg::ask(&mut app.ui, "Split", &format!("Size of the parts of {} (k, m):", e.name), &mut s, 20) {
        return;
    }
    let t = s.trim().to_lowercase();
    let (num, mul) = match t.chars().last() {
        Some('k') => (&t[..t.len() - 1], 1024),
        Some('m') => (&t[..t.len() - 1], 1 << 20),
        _ => (t.as_str(), 1),
    };
    let Some(size) = num.trim().parse::<u64>().ok().map(|n| n * mul).filter(|&n| n > 0) else {
        dlg::info(&mut app.ui, "Split", &[format!("'{s}' is not a size.")]);
        return;
    };
    let dir = app.p[1 - a].path.clone();
    let src = app.p[a].path.join(&e.name);
    let r = (|| -> std::io::Result<usize> {
        use std::io::{Read, Write};
        let mut f = std::fs::File::open(&src)?;
        let mut part = 0;
        loop {
            let mut buf = vec![];
            (&mut f).take(size).read_to_end(&mut buf)?;
            if buf.is_empty() && part > 0 {
                break;
            }
            part += 1;
            std::fs::File::create(dir.join(format!("{}.{part:03}", e.name)))?.write_all(&buf)?;
            if (buf.len() as u64) < size {
                break;
            }
        }
        Ok(part)
    })();
    match r {
        Ok(n) => dlg::info(&mut app.ui, "Split", &[format!("{n} parts written to {}", dir.display())]),
        Err(err) => dlg::info(&mut app.ui, "Split", &[err.to_string()]),
    }
    app.reload_all();
}

fn join(app: &mut App) {
    let a = app.act;
    let mut items: Vec<Entry> = app.p[a].targets().into_iter().filter(|e| !e.is_dir).collect();
    if items.is_empty() {
        return;
    }
    items.sort_by(|x, y| x.name.cmp(&y.name));
    let first = &items[0].name;
    let mut out = first.strip_suffix(".001").unwrap_or(first).to_string();
    if items.len() == 1 && first.ends_with(".001") {
        // join NAME.001, NAME.002, ...
        let stem = out.clone();
        items = app.p[a].entries.iter().filter(|e| {
            e.name.strip_prefix(&stem).and_then(|r| r.strip_prefix('.')).is_some_and(|r| r.len() == 3 && r.chars().all(|c| c.is_ascii_digit()))
        }).cloned().collect();
        items.sort_by(|x, y| x.name.cmp(&y.name));
    }
    if !dlg::ask(&mut app.ui, "Join", &format!("Join {} files into (other panel):", items.len()), &mut out, 255) {
        return;
    }
    let dst = crate::ops::resolve(&app.p[1 - a].path, &out);
    let src = app.p[a].path.clone();
    let r = (|| -> std::io::Result<()> {
        let mut f = std::fs::File::create(&dst)?;
        for e in &items {
            std::io::copy(&mut std::fs::File::open(src.join(&e.name))?, &mut f)?;
        }
        Ok(())
    })();
    if let Err(err) = r {
        dlg::info(&mut app.ui, "Join", &[format!("{}: {err}", dst.display())]);
    }
    app.reload_all();
}

fn dupes(app: &mut App) {
    use std::collections::HashMap;
    let base = app.p[app.act].path.clone();
    dlg::wait_box(&mut app.ui, "Looking for duplicate files...");
    let mut by_size: HashMap<u64, Vec<PathBuf>> = HashMap::new();
    let hidden = app.p[app.act].hidden;
    walk(&base, 64, hidden, &mut |p, m| {
        if m.is_file() && m.len() > 0 {
            by_size.entry(m.len()).or_default().push(p.to_path_buf());
        }
        true
    });
    let mut groups: Vec<(u64, Vec<PathBuf>)> = vec![];
    for (size, v) in by_size.into_iter().filter(|(_, v)| v.len() > 1) {
        let mut by_hash: HashMap<u64, Vec<PathBuf>> = HashMap::new();
        for p in v {
            if let Ok(b) = std::fs::read(&p) {
                use std::hash::{Hash, Hasher};
                let mut h = std::collections::hash_map::DefaultHasher::new();
                b.hash(&mut h);
                by_hash.entry(h.finish()).or_default().push(p);
            }
        }
        groups.extend(by_hash.into_values().filter(|v| v.len() > 1).map(|v| (size, v)));
    }
    app.ui.pop_screen();
    groups.sort_by(|a, b| b.0.cmp(&a.0));
    let mut lines = vec![];
    let mut paths = vec![];
    for (size, v) in &groups {
        for (k, p) in v.iter().enumerate() {
            let s = if k == 0 { format!("{:>12}", panel::group(*size)) } else { " ".repeat(12) };
            lines.push(format!("{s}  {}", rel(&base, p)));
            paths.push(p.clone());
        }
    }
    if let Some(i) = dlg::list(&mut app.ui, &format!("{} groups of duplicates", groups.len()), &lines, 0) {
        goto(app, &paths[i]);
    }
}

/// Copies files missing or older in the other panel's directory there.
fn sync(app: &mut App) {
    let (a, o) = (app.act, app.other());
    let other = app.p[o].entries.clone();
    let todo: Vec<Entry> = app.p[a]
        .entries
        .iter()
        .filter(|e| !e.is_dir)
        .filter(|e| other.iter().find(|x| x.name == e.name).is_none_or(|x| x.mtime < e.mtime))
        .cloned()
        .collect();
    if todo.is_empty() {
        dlg::info(&mut app.ui, "Synchronize", &["The other directory is up to date.".into()]);
        return;
    }
    if !dlg::confirm(&mut app.ui, "Synchronize", &[&format!("Copy {} new or newer files to the other panel?",
        todo.len())], true)
    {
        return;
    }
    let (src, dst) = (app.p[a].path.clone(), app.p[o].path.clone());
    let mut job = crate::ops::Job::new(&mut app.ui);
    job.overwrite_all();
    for e in &todo {
        job.copy(&src.join(&e.name), &dst.join(&e.name));
    }
    job.report("Synchronize");
    app.reload_all();
}

fn dir_sizes(app: &mut App) {
    let a = app.act;
    let dir = app.p[a].path.clone();
    let dirs: Vec<Entry> = app.p[a].entries.iter().filter(|e| e.is_dir && !e.is_up()).cloned().collect();
    dlg::wait_box(&mut app.ui, "Adding up directory sizes...");
    let mut v = vec![];
    let mut total = 0;
    for e in &dirs {
        let (b, n, ok) = tree_size(&dir.join(&e.name), &mut app.ui);
        total += b;
        v.push((b, format!("{:<24} {:>15} {:>7} files", panel::fit(&e.name, 24), panel::group(b), n)));
        if !ok {
            break;
        }
    }
    let files: u64 = app.p[a].entries.iter().filter(|e| !e.is_dir).map(|e| e.size).sum();
    app.ui.pop_screen();
    v.sort_by(|x, y| y.0.cmp(&x.0));
    let mut lines: Vec<String> = v.into_iter().map(|x| x.1).collect();
    lines.push(format!("{:<24} {:>15}", "(files here)", panel::group(files)));
    lines.push(format!("{:<24} {:>15}", "Total", panel::group(total + files)));
    dlg::list(&mut app.ui, "Directory sizes", &lines, 0);
}

/// Ctrl-Return on a directory / Shift-F5: size of the cursor directory or the marked entries.
pub fn dir_info(app: &mut App) {
    let a = app.act;
    let dir = app.p[a].path.clone();
    let items = app.p[a].targets();
    dlg::wait_box(&mut app.ui, "Adding up sizes...");
    let (mut b, mut n) = (0, 0);
    for e in &items {
        if e.is_dir {
            let (x, y, _) = tree_size(&dir.join(&e.name), &mut app.ui);
            b += x;
            n += y;
        } else {
            b += e.size;
            n += 1;
        }
    }
    app.ui.pop_screen();
    let what = if items.len() == 1 { items[0].name.clone() } else { format!("{} entries", items.len()) };
    dlg::info(&mut app.ui, "Size", &[what, format!("{} bytes in {n} files", panel::group(b))]);
}

fn drives(app: &mut App) {
    let pl = dxtui::ui::places();
    let lines: Vec<String> = pl
        .iter()
        .map(|p| {
            let (f, t) = files::disk_space(p).unwrap_or((0, 0));
            format!("{:<30} {:>18} free of {:>18}", panel::fit(&p.display().to_string(), 30), panel::group(f),
                panel::group(t))
        })
        .collect();
    if let Some(i) = dlg::list(&mut app.ui, "Drive overview", &lines, 0) {
        goto(app, &pl[i]);
    }
}

fn drive_stat(app: &mut App) {
    let p = app.p[app.act].path.clone();
    let mut l = vec![p.display().to_string()];
    if let Some((f, t)) = files::disk_space(&p) {
        let used = t - f;
        let pct = if t > 0 { used * 100 / t } else { 0 };
        l.push(format!("Total: {:>20} bytes", panel::group(t)));
        l.push(format!("Used:  {:>20} bytes", panel::group(used)));
        l.push(format!("Free:  {:>20} bytes", panel::group(f)));
        let bar = (pct as usize * 30) / 100;
        l.push(format!("[{}{}] {pct}%", "█".repeat(bar), "░".repeat(30 - bar)));
    }
    l.extend(output("df -h .", &p).lines().map(String::from));
    dlg::info(&mut app.ui, "Drive statistics", &l);
}

// --- archives ---

fn arc_kind(name: &str) -> Option<&'static str> {
    let n = name.to_lowercase();
    if n.ends_with(".zip") || n.ends_with(".jar") {
        Some("zip")
    } else if [".tar", ".tgz", ".tar.gz", ".tar.bz2", ".tbz", ".tar.xz", ".txz", ".tar.zst"].iter().any(|e| n.ends_with(e)) {
        Some("tar")
    } else if n.ends_with(".7z") {
        Some("7z")
    } else if n.ends_with(".gz") {
        Some("gz")
    } else {
        None
    }
}

fn pack(app: &mut App) {
    let a = app.act;
    let items = app.p[a].targets();
    if items.is_empty() {
        return;
    }
    let def = if items.len() == 1 { items[0].name.clone() } else { app.p[a].path.file_name().map_or("archive".into(), |n| n.to_string_lossy().into_owned()) };
    let mut out = format!("{}/{def}.zip", app.p[1 - a].path.display());
    if !dlg::ask(&mut app.ui, "Pack", "Archive (.zip, .tar.gz, .tar.xz, .7z):", &mut out, 255) {
        return;
    }
    let dst = crate::ops::resolve(&app.p[a].path, &out);
    let q = shell_quote(&dst.display().to_string());
    let names: Vec<String> = items.iter().map(|e| shell_quote(&e.name)).collect();
    let names = names.join(" ");
    let cmd = match arc_kind(&out) {
        Some("zip") => format!("zip -r {q} {names}"),
        Some("tar") => format!("tar -caf {q} {names}"),
        Some("7z") => format!("7z a {q} {names}"),
        _ => {
            dlg::info(&mut app.ui, "Pack", &["Unknown archive type; use .zip, .tar.gz, .tar.xz or .7z.".into()]);
            return;
        }
    };
    app.run(&cmd, true);
}

fn arc(app: &mut App, test: bool) {
    let a = app.act;
    let Some(e) = app.p[a].current().filter(|e| !e.is_dir).cloned() else { return };
    let q = shell_quote(&e.name);
    let cmd = match (arc_kind(&e.name), test) {
        (Some("zip"), false) => format!("unzip -l {q}"),
        (Some("zip"), true) => format!("unzip -t {q}"),
        (Some("tar"), false) => format!("tar -tvf {q}"),
        (Some("tar"), true) => format!("tar -tf {q} >/dev/null && echo 'No errors.'"),
        (Some("7z"), false) => format!("7z l {q}"),
        (Some("7z"), true) => format!("7z t {q}"),
        (Some("gz"), false) => format!("gzip -l {q}"),
        (Some("gz"), true) => format!("gzip -tv {q}"),
        _ => {
            dlg::info(&mut app.ui, "Archive", &[format!("{} is not a known archive.", e.name)]);
            return;
        }
    };
    let dir = app.p[a].path.clone();
    dlg::wait_box(&mut app.ui, &format!("Reading {}", e.name));
    let out = output(&cmd, &dir);
    app.ui.pop_screen();
    dlg::text(&mut app.ui, &e.name, &out);
}

fn unpack(app: &mut App) {
    let a = app.act;
    let Some(e) = app.p[a].current().filter(|e| !e.is_dir).cloned() else { return };
    let mut to = app.p[1 - a].path.display().to_string();
    if !dlg::ask(&mut app.ui, "Unpack", &format!("Unpack {} to:", e.name), &mut to, 255) {
        return;
    }
    let d = crate::ops::resolve(&app.p[a].path, &to);
    let _ = std::fs::create_dir_all(&d);
    let dq = shell_quote(&d.display().to_string());
    let q = shell_quote(&e.name);
    let cmd = match arc_kind(&e.name) {
        Some("zip") => format!("unzip {q} -d {dq}"),
        Some("tar") => format!("tar -xvf {q} -C {dq}"),
        Some("7z") => format!("7z x {q} -o{dq}"),
        Some("gz") => format!("gunzip -c {q} > {dq}/{}", shell_quote(e.name.trim_end_matches(".gz"))),
        _ => {
            dlg::info(&mut app.ui, "Unpack", &[format!("{} is not a known archive.", e.name)]);
            return;
        }
    };
    app.run(&cmd, true);
}

// --- settings ---

fn sysfiles(app: &mut App) {
    let h = files::home();
    let mut v: Vec<PathBuf> = [".profile", ".bashrc", ".bash_profile", ".zshrc", ".zprofile", ".inputrc"]
        .iter()
        .map(|n| h.join(n))
        .filter(|p| p.exists())
        .collect();
    v.push(app.conf.path().to_path_buf());
    let lines: Vec<String> = v.iter().map(|p| p.display().to_string()).collect();
    if let Some(i) = dlg::list(&mut app.ui, "Edit system files", &lines, 0) {
        let conf = i == v.len() - 1;
        if conf {
            app.save_state();
        }
        let ed = crate::editor(&app.conf);
        app.run_prog(&ed, &[&lines[i]]);
        if conf {
            app.command(LOAD);
        }
    }
}

fn config(app: &mut App) {
    let mut sel = 0;
    loop {
        let flags = [("confirm_delete", "Confirm delete", true), ("confirm_quit", "Confirm quit", true),
            ("hidden", "Show hidden files", false)];
        let mut lines: Vec<String> = flags
            .iter()
            .map(|(k, t, d)| format!("{:<24} {}", t, if app.conf.flag(k, *d) { "on" } else { "off" }))
            .collect();
        lines.push(format!("{:<24} {}", "Editor", crate::editor(&app.conf)));
        lines.push(format!("{:<24} {}", "External viewer", app.conf.str_or("viewer", "less")));
        lines.push(format!("{:<24} {}", "Screen saver after", match app.ui.saver_delay {
            0 => "never".to_string(),
            s => format!("{s} s"),
        }));
        let Some(i) = dlg::list(&mut app.ui, "Configuration", &lines, sel) else { break };
        sel = i;
        match i {
            0..=2 => {
                let (k, _, d) = flags[i];
                let v = !app.conf.flag(k, d);
                app.conf.set(k, if v { "on" } else { "off" });
                if k == "hidden" {
                    for p in &mut app.p {
                        p.hidden = v;
                    }
                    app.reload_all();
                }
            }
            3 | 4 => {
                let (k, t) = if i == 3 { ("editor", "Editor command:") } else { ("viewer", "Viewer command:") };
                let mut s = if i == 3 { crate::editor(&app.conf) } else { app.conf.str_or("viewer", "less") };
                if dlg::ask(&mut app.ui, "Configuration", t, &mut s, 200) {
                    app.conf.set(k, s.trim());
                }
            }
            _ => saver(app),
        }
    }
    let _ = app.conf.save();
}

fn saver(app: &mut App) {
    let mut s = app.ui.saver_delay.to_string();
    if dlg::ask(&mut app.ui, "Screen saver", "Start after how many seconds without input (0 = never):", &mut s, 6) {
        if let Ok(n) = s.trim().parse::<u32>() {
            app.ui.saver_delay = n;
            app.conf.set("saver_delay", n);
        }
        let mut pw = app.password.clone();
        if dlg::ask(&mut app.ui, "Screen saver", "Password to end it (empty = none):", &mut pw, 20) {
            app.password = pw.clone();
            app.conf.set("password", pw);
        }
        let _ = app.conf.save();
    }
}

fn save_load(app: &mut App, save: bool) {
    let mut s = app.home.join("dx2.conf").display().to_string();
    let t = if save { "Save settings as" } else { "Load settings from" };
    if !dlg::ask(&mut app.ui, t, "File:", &mut s, 255) {
        return;
    }
    let p = crate::ops::resolve(&app.p[app.act].path, &s);
    if save {
        app.save_state();
        if let Err(e) = std::fs::copy(app.conf.path(), &p) {
            dlg::info(&mut app.ui, t, &[format!("{}: {e}", p.display())]);
        }
    } else if p.is_file() {
        let _ = std::fs::copy(&p, app.conf.path());
        app.command(LOAD);
    } else {
        dlg::info(&mut app.ui, t, &[format!("{} does not exist.", p.display())]);
    }
}

/// Shift-F2: point-and-shoot — the command started by Return for files with the cursor file's extension.
fn assoc(app: &mut App) {
    let list = app.conf.with_prefix("assoc.");
    let cur_ext = app.p[app.act].current().map(|e| files::split_ext(&e.name).1.to_lowercase()).unwrap_or_default();
    let mut lines: Vec<String> = list.iter().map(|(k, v)| format!("{:<8} {v}", &k[6..])).collect();
    lines.insert(0, if cur_ext.is_empty() { "New entry...".to_string() } else { format!("New entry for .{cur_ext}...") });
    let Some(i) = dlg::list(&mut app.ui, "Point-and-shoot (%f = file name)", &lines, 0) else { return };
    let (mut ext, mut cmd) = if i == 0 {
        (cur_ext, String::new())
    } else {
        (list[i - 1].0[6..].to_string(), list[i - 1].1.clone())
    };
    if !dlg::ask(&mut app.ui, "Point-and-shoot", "Extension:", &mut ext, 20) || ext.trim().is_empty() {
        return;
    }
    if !dlg::ask(&mut app.ui, "Point-and-shoot", "Command (empty removes the entry):", &mut cmd, 200) {
        return;
    }
    let k = format!("assoc.{}", ext.trim().trim_start_matches('.').to_lowercase());
    if cmd.trim().is_empty() {
        app.conf.remove(&k);
    } else {
        app.conf.set(&k, cmd.trim());
    }
    let _ = app.conf.save();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn numbers() {
        assert_eq!(parse_num("$7B"), Some(123));
        assert_eq!(parse_num("7Bh"), Some(123));
        assert_eq!(parse_num("1111011b"), Some(123));
        assert_eq!(parse_num("'A'"), Some(65));
        assert_eq!(parse_num("-12"), Some(-12));
        assert_eq!(eval("2+3*4").unwrap(), 14.0);
        assert_eq!(eval("(2+3)*4 - $10").unwrap(), 4.0);
        assert_eq!(eval("2^10").unwrap(), 1024.0);
        assert!(eval("1/0").is_err());
    }

    #[test]
    fn weekdays() {
        assert_eq!(weekday(2026, 10, 14), 3);
        assert_eq!(weekday(2000, 1, 1), 6);
    }
}
