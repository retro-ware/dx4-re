//! File picker for choosing a program. Spec: src/dxm/BROWSER.PAS, ADDPROG.PAS (shows directories and
//! *.exe, *.com, *.bat). The port additionally shows files with the executable bit on Unix.

use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug)]
pub struct Entry {
    pub name: String,
    pub dir: bool,
}

pub struct Picker {
    pub dir: PathBuf,
    pub entries: Vec<Entry>,
    pub sel: usize,
}

fn is_program(p: &Path) -> bool {
    let ext = p.extension().and_then(|e| e.to_str()).map(str::to_ascii_lowercase);
    if matches!(ext.as_deref(), Some("exe" | "com" | "bat")) {
        return true;
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if let Ok(m) = fs::metadata(p) {
            return m.is_file() && m.permissions().mode() & 0o111 != 0;
        }
    }
    false
}

impl Picker {
    pub fn new(dir: PathBuf) -> Picker {
        let mut p = Picker { dir, entries: vec![], sel: 0 };
        p.read();
        p
    }

    fn read(&mut self) {
        let mut dirs = vec![];
        let mut files = vec![];
        if let Ok(rd) = fs::read_dir(&self.dir) {
            for e in rd.flatten() {
                let name = e.file_name().to_string_lossy().into_owned();
                if name.starts_with('.') {
                    continue;
                }
                let path = e.path();
                if path.is_dir() {
                    dirs.push(name);
                } else if is_program(&path) {
                    files.push(name);
                }
            }
        }
        dirs.sort_by_key(|s| s.to_lowercase());
        files.sort_by_key(|s| s.to_lowercase());
        self.entries = Vec::new();
        if self.dir.parent().is_some() {
            self.entries.push(Entry { name: "..".into(), dir: true });
        }
        self.entries.extend(dirs.into_iter().map(|name| Entry { name, dir: true }));
        self.entries.extend(files.into_iter().map(|name| Entry { name, dir: false }));
        self.sel = 0;
    }

    pub fn up(&mut self) {
        self.sel = self.sel.saturating_sub(1);
    }

    pub fn down(&mut self) {
        if self.sel + 1 < self.entries.len() {
            self.sel += 1;
        }
    }

    /// Enters a directory, or returns the chosen program's full path.
    pub fn enter(&mut self) -> Option<PathBuf> {
        let e = self.entries.get(self.sel)?;
        if e.name == ".." {
            let child = self.dir.file_name().map(|n| n.to_string_lossy().into_owned());
            self.dir.pop();
            self.read();
            if let Some(i) = child.and_then(|c| self.entries.iter().position(|e| e.name == c)) {
                self.sel = i;
            }
            None
        } else if e.dir {
            self.dir.push(&e.name);
            self.read();
            None
        } else {
            Some(self.dir.join(&e.name))
        }
    }

    /// Jumps to the next entry starting with the typed letter.
    pub fn jump(&mut self, c: char) {
        let c = c.to_lowercase().next().unwrap_or(c);
        let n = self.entries.len();
        for k in 1..=n {
            let i = (self.sel + k) % n;
            if self.entries[i].name.to_lowercase().starts_with(c) {
                self.sel = i;
                return;
            }
        }
    }
}
