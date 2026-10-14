//! F5 copy, F6 rename/move, F7 make directory, F8 delete (CopyDlg, RenFile, FileAsk, DelTree).

use crate::dlg;
use crate::files::Entry;
use crate::panel::group;
use dxtui::ui::Ui;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy, PartialEq)]
enum Over {
    Ask,
    All,
    None,
}

pub struct Job<'a> {
    ui: &'a mut Ui,
    over: Over,
    pub done: u64,
    pub bytes: u64,
    pub errors: Vec<String>,
    cancelled: bool,
}

impl<'a> Job<'a> {
    pub fn new(ui: &'a mut Ui) -> Job<'a> {
        Job { ui, over: Over::Ask, done: 0, bytes: 0, errors: vec![], cancelled: false }
    }

    /// Overwrites existing targets without asking.
    pub fn overwrite_all(&mut self) {
        self.over = Over::All;
    }

    fn progress(&mut self, what: &str, p: &Path) {
        let w = self.ui.cols();
        let s = crate::panel::fit(&format!("{what} {}", p.display()), (w - 10).max(10) as usize);
        dlg::wait_box(self.ui, &s);
        self.ui.pop_screen();
        if dlg::interrupted(self.ui) && dlg::confirm(self.ui, "Cancel", &["Stop the operation?"], true) {
            self.cancelled = true;
        }
    }

    /// May `dst` be written? Asks when it exists.
    fn may_write(&mut self, dst: &Path) -> bool {
        if !dst.exists() {
            return true;
        }
        match self.over {
            Over::All => return true,
            Over::None => return false,
            Over::Ask => {}
        }
        let name = dst.display().to_string();
        let r = dlg::choose(self.ui, "File exists", &[&name, "Overwrite it?"], &["Yes", "All", "Skip", "None",
            "Cancel"], 0);
        match r {
            Some(0) => true,
            Some(1) => {
                self.over = Over::All;
                true
            }
            Some(2) => false,
            Some(3) => {
                self.over = Over::None;
                false
            }
            _ => {
                self.cancelled = true;
                false
            }
        }
    }

    fn err(&mut self, p: &Path, e: io::Error) {
        self.errors.push(format!("{}: {e}", p.display()));
    }

    /// Copies a file or a directory tree.
    pub fn copy(&mut self, src: &Path, dst: &Path) {
        if self.cancelled {
            return;
        }
        if dst.starts_with(src) && src.is_dir() {
            self.errors.push(format!("{}: cannot copy a directory into itself", src.display()));
            return;
        }
        let m = match fs::symlink_metadata(src) {
            Ok(m) => m,
            Err(e) => return self.err(src, e),
        };
        if m.file_type().is_symlink() {
            if !self.may_write(dst) {
                return;
            }
            let _ = fs::remove_file(dst);
            match fs::read_link(src).and_then(|t| std::os::unix::fs::symlink(t, dst)) {
                Ok(()) => self.done += 1,
                Err(e) => self.err(src, e),
            }
        } else if m.is_dir() {
            if let Err(e) = fs::create_dir_all(dst) {
                return self.err(dst, e);
            }
            match fs::read_dir(src) {
                Ok(rd) => {
                    for e in rd.flatten() {
                        self.copy(&e.path(), &dst.join(e.file_name()));
                        if self.cancelled {
                            return;
                        }
                    }
                }
                Err(e) => self.err(src, e),
            }
            let _ = fs::set_permissions(dst, m.permissions());
            set_mtime(dst, &m);
        } else {
            if same_file(src, dst) {
                self.errors.push(format!("{}: source and target are the same file", src.display()));
                return;
            }
            if !self.may_write(dst) {
                return;
            }
            self.progress("Copying", src);
            match fs::copy(src, dst) {
                Ok(n) => {
                    self.bytes += n;
                    self.done += 1;
                    set_mtime(dst, &m);
                }
                Err(e) => self.err(src, e),
            }
        }
    }

    /// Moves by rename, or by copy + delete across file systems.
    pub fn mv(&mut self, src: &Path, dst: &Path) {
        if self.cancelled {
            return;
        }
        if dst.exists() && !same_file(src, dst) && !self.may_write(dst) {
            return;
        }
        if dst.is_dir() && !src.is_dir() {
            let _ = fs::remove_dir(dst);
        }
        self.progress("Moving", src);
        match fs::rename(src, dst) {
            Ok(()) => self.done += 1,
            Err(e) if e.raw_os_error() == Some(libc::EXDEV) => {
                let before = self.errors.len();
                self.copy(src, dst);
                if self.errors.len() == before && !self.cancelled {
                    self.delete(src);
                }
            }
            Err(e) => self.err(src, e),
        }
    }

    pub fn delete(&mut self, p: &Path) {
        let r = match fs::symlink_metadata(p) {
            Ok(m) if m.is_dir() => fs::remove_dir_all(p),
            Ok(_) => fs::remove_file(p),
            Err(e) => Err(e),
        };
        match r {
            Ok(()) => self.done += 1,
            Err(e) => self.err(p, e),
        }
    }

    pub fn report(self, what: &str) {
        if !self.errors.is_empty() {
            let mut lines = vec![format!("{} errors:", self.errors.len())];
            lines.extend(self.errors.iter().take(12).cloned());
            dlg::info(self.ui, what, &lines);
        }
    }
}

fn same_file(a: &Path, b: &Path) -> bool {
    use std::os::unix::fs::MetadataExt;
    match (fs::metadata(a), fs::metadata(b)) {
        (Ok(x), Ok(y)) => x.dev() == y.dev() && x.ino() == y.ino(),
        _ => false,
    }
}

fn set_mtime(p: &Path, m: &fs::Metadata) {
    if let Ok(t) = m.modified() {
        if let Ok(f) = fs::File::options().write(true).open(p).or_else(|_| fs::File::open(p)) {
            let _ = f.set_modified(t);
        }
    }
}

fn describe(v: &[Entry]) -> String {
    if v.len() == 1 {
        format!("'{}'", v[0].name)
    } else {
        let bytes: u64 = v.iter().filter(|e| !e.is_dir).map(|e| e.size).sum();
        format!("{} files ({} bytes)", v.len(), group(bytes))
    }
}

/// Where the target of a copy or move ends up: into `dst` if it is a directory, else as `dst`.
fn target(dst: &Path, name: &str, many: bool) -> PathBuf {
    if dst.is_dir() || many { dst.join(name) } else { dst.to_path_buf() }
}

/// Resolves a typed target relative to `base` (and ~).
pub fn resolve(base: &Path, s: &str) -> PathBuf {
    let s = s.trim();
    if let Some(rest) = s.strip_prefix("~/") {
        return crate::files::home().join(rest);
    }
    if s == "~" {
        return crate::files::home();
    }
    let p = Path::new(s);
    if p.is_absolute() { p.to_path_buf() } else { base.join(p) }
}

/// F5. Returns true when something changed.
pub fn copy(ui: &mut Ui, src_dir: &Path, items: &[Entry], dest: &Path) -> bool {
    if items.is_empty() {
        return false;
    }
    let mut d = dest.display().to_string();
    if !dlg::ask(ui, "Copy", &format!("Copy {} to:", describe(items)), &mut d, 255) {
        return false;
    }
    let dst = resolve(src_dir, &d);
    let many = items.len() > 1;
    if many && !dst.is_dir() {
        if let Err(e) = fs::create_dir_all(&dst) {
            dlg::info(ui, "Copy", &[format!("{}: {e}", dst.display())]);
            return false;
        }
    }
    let mut job = Job::new(ui);
    for e in items {
        let t = target(&dst, &e.name, many);
        job.copy(&src_dir.join(&e.name), &t);
    }
    job.report("Copy");
    true
}

/// F6.
pub fn rename_move(ui: &mut Ui, src_dir: &Path, items: &[Entry], dest: &Path) -> bool {
    if items.is_empty() {
        return false;
    }
    let mut d = if items.len() == 1 { items[0].name.clone() } else { dest.display().to_string() };
    if !dlg::ask(ui, "Rename / move", &format!("Rename or move {} to:", describe(items)), &mut d, 255) {
        return false;
    }
    let dst = resolve(src_dir, &d);
    let many = items.len() > 1;
    if many && !dst.is_dir() {
        if let Err(e) = fs::create_dir_all(&dst) {
            dlg::info(ui, "Move", &[format!("{}: {e}", dst.display())]);
            return false;
        }
    }
    let mut job = Job::new(ui);
    for e in items {
        let t = target(&dst, &e.name, many);
        job.mv(&src_dir.join(&e.name), &t);
    }
    job.report("Move");
    true
}

/// F7. Returns the new directory's name.
pub fn mkdir(ui: &mut Ui, dir: &Path) -> Option<String> {
    let mut s = String::new();
    if !dlg::ask(ui, "Make directory", "Name of the new directory:", &mut s, 255) || s.trim().is_empty() {
        return None;
    }
    let p = resolve(dir, &s);
    match fs::create_dir_all(&p) {
        Ok(()) => p.strip_prefix(dir).ok().and_then(|r| r.components().next()).map(|c| c.as_os_str().to_string_lossy().into()),
        Err(e) => {
            dlg::info(ui, "Make directory", &[format!("{}: {e}", p.display())]);
            None
        }
    }
}

/// F8.
pub fn delete(ui: &mut Ui, dir: &Path, items: &[Entry], confirm: bool) -> bool {
    if items.is_empty() {
        return false;
    }
    if confirm && !dlg::confirm(ui, "Delete", &[&format!("Delete {}?", describe(items))], true) {
        return false;
    }
    let mut job = Job::new(ui);
    let mut all_dirs = false;
    for e in items {
        let p = dir.join(&e.name);
        if e.is_dir && !e.is_link && fs::read_dir(&p).map(|mut r| r.next().is_some()).unwrap_or(false) && !all_dirs {
            let name = format!("'{}' is not empty.", e.name);
            match dlg::choose(job.ui, "Delete", &[&name, "Delete it with everything in it?"], &["Yes", "All", "Skip",
                "Cancel"], 0) {
                Some(0) => {}
                Some(1) => all_dirs = true,
                Some(2) => continue,
                _ => break,
            }
        }
        job.progress("Deleting", &p);
        if e.is_link {
            match fs::remove_file(&p) {
                Ok(()) => job.done += 1,
                Err(err) => job.err(&p, err),
            }
        } else {
            job.delete(&p);
        }
        if job.cancelled {
            break;
        }
    }
    job.report("Delete");
    true
}
