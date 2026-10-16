//! Directory entries of a file panel: reading, sorting, wildcard masks.

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

#[derive(Clone, Debug)]
pub struct Entry {
    pub name: String,
    pub is_dir: bool,
    pub is_link: bool,
    pub size: u64,
    pub mtime: SystemTime,
    pub mode: u32,
    pub marked: bool,
}

impl Entry {
    pub fn up() -> Entry {
        Entry {
            name: "..".into(),
            is_dir: true,
            is_link: false,
            size: 0,
            mtime: SystemTime::UNIX_EPOCH,
            mode: 0o755,
            marked: false,
        }
    }

    pub fn is_up(&self) -> bool {
        self.name == ".."
    }

    pub fn hidden(&self) -> bool {
        self.name.starts_with('.') && !self.is_up()
    }

    pub fn read_only(&self) -> bool {
        self.mode & 0o222 == 0
    }

    pub fn executable(&self) -> bool {
        !self.is_dir && self.mode & 0o111 != 0
    }

    /// Name and extension split at the last dot (a leading dot is part of the name).
    pub fn split(&self) -> (&str, &str) {
        split_ext(&self.name)
    }

    pub fn ext(&self) -> &str {
        self.split().1
    }
}

pub fn split_ext(name: &str) -> (&str, &str) {
    match name.rfind('.') {
        Some(p) if p > 0 && p + 1 < name.len() => (&name[..p], &name[p + 1..]),
        _ => (name, ""),
    }
}

pub fn stat(path: &Path, name: &str) -> Option<Entry> {
    let p = path.join(name);
    let lm = fs::symlink_metadata(&p).ok()?;
    let is_link = lm.file_type().is_symlink();
    let m = if is_link { fs::metadata(&p).unwrap_or(lm) } else { lm };
    Some(Entry {
        name: name.to_string(),
        is_dir: m.is_dir(),
        is_link,
        size: m.len(),
        mtime: m.modified().unwrap_or(SystemTime::UNIX_EPOCH),
        mode: m.permissions().mode(),
        marked: false,
    })
}

/// All entries of `path` except "." ; ".." first unless `path` is the root.
pub fn read_dir(path: &Path, hidden: bool) -> std::io::Result<Vec<Entry>> {
    let mut v = vec![];
    if path.parent().is_some() {
        let mut up = Entry::up();
        if let Ok(m) = fs::metadata(path) {
            up.mtime = m.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        }
        v.push(up);
    }
    for e in fs::read_dir(path)?.flatten() {
        let name = e.file_name().to_string_lossy().into_owned();
        if !hidden && name.starts_with('.') {
            continue;
        }
        if let Some(en) = stat(path, &name) {
            v.push(en);
        }
    }
    Ok(v)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Sort {
    Name,
    Ext,
    Size,
    Time,
    None,
}

impl Sort {
    pub fn from_str(s: &str) -> Sort {
        match s {
            "name" => Sort::Name,
            "size" => Sort::Size,
            "time" => Sort::Time,
            "none" => Sort::None,
            _ => Sort::Ext,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Sort::Name => "name",
            Sort::Ext => "ext",
            Sort::Size => "size",
            Sort::Time => "time",
            Sort::None => "none",
        }
    }
}

fn lower(s: &str) -> String {
    s.to_lowercase()
}

/// Directories first (by name), then files in `sort` order; ".." stays on top.
pub fn sort(v: &mut [Entry], sort: Sort, reverse: bool) {
    if sort == Sort::None {
        return;
    }
    v.sort_by(|a, b| {
        use std::cmp::Ordering::*;
        match (a.is_up(), b.is_up()) {
            (true, false) => return Less,
            (false, true) => return Greater,
            _ => {}
        }
        match (a.is_dir, b.is_dir) {
            (true, false) => return Less,
            (false, true) => return Greater,
            (true, true) => return lower(&a.name).cmp(&lower(&b.name)),
            _ => {}
        }
        let by_name = || lower(&a.name).cmp(&lower(&b.name));
        let o = match sort {
            Sort::Name => by_name(),
            Sort::Ext => lower(a.ext()).cmp(&lower(b.ext())).then_with(by_name),
            Sort::Size => b.size.cmp(&a.size).then_with(by_name),
            Sort::Time => b.mtime.cmp(&a.mtime).then_with(by_name),
            Sort::None => Equal,
        };
        if reverse { o.reverse() } else { o }
    });
}

/// DOS-style wildcard match (`*`, `?`), case-insensitive. "*.*" matches names without a dot too.
pub fn matches(mask: &str, name: &str) -> bool {
    let mask = lower(mask);
    let name = lower(name);
    if mask == "*.*" || mask == "*" || mask.is_empty() {
        return true;
    }
    let mask = if mask.ends_with(".*") && !name.contains('.') { &mask[..mask.len() - 2] } else { &mask[..] };
    fn m(p: &[char], s: &[char]) -> bool {
        match p.first() {
            None => s.is_empty(),
            Some('*') => (0..=s.len()).any(|i| m(&p[1..], &s[i..])),
            Some('?') => !s.is_empty() && m(&p[1..], &s[1..]),
            Some(c) => s.first() == Some(c) && m(&p[1..], &s[1..]),
        }
    }
    let p: Vec<char> = mask.chars().collect();
    let s: Vec<char> = name.chars().collect();
    m(&p, &s)
}

/// Any of several masks separated by ';', ',' or blanks.
pub fn matches_any(masks: &str, name: &str) -> bool {
    let mut any = false;
    for m in masks.split([';', ',', ' ']).filter(|m| !m.is_empty()) {
        any = true;
        if matches(m, name) {
            return true;
        }
    }
    !any
}

/// Size in human readable form: "512 B", "1.5 KB", "23.4 MB", "117 GB" (powers of 1024, at most 7 characters).
pub fn human(n: u64) -> String {
    if n < 1024 {
        return format!("{n} B");
    }
    let mut v = n as f64;
    for u in ["KB", "MB", "GB", "TB", "PB", "EB"] {
        v /= 1024.0;
        if v < 1023.95 || u == "EB" {
            return if v < 99.95 { format!("{v:.1} {u}") } else { format!("{v:.0} {u}") };
        }
    }
    unreachable!()
}

/// "dd.mm.yy" and "hh:mm" of a time stamp.
pub fn date_time(t: SystemTime) -> (String, String) {
    let (y, mo, d, h, mi, _) = dxtui::time::local_of(t);
    (format!("{d:02}.{mo:02}.{:02}", y % 100), format!("{h:2}:{mi:02}"))
}

pub fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

/// Free and total bytes of the file system holding `p`.
pub fn disk_space(p: &Path) -> Option<(u64, u64)> {
    use std::ffi::CString;
    let c = CString::new(p.as_os_str().as_encoded_bytes()).ok()?;
    let mut s: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c.as_ptr(), &mut s) } != 0 {
        return None;
    }
    let f = s.f_frsize as u64;
    Some((s.f_bavail as u64 * f, s.f_blocks as u64 * f))
}

pub fn owner_mode(e: &Entry) -> String {
    let mut s = String::new();
    s.push(if e.is_dir { 'd' } else if e.is_link { 'l' } else { '-' });
    for sh in [6, 3, 0] {
        let b = (e.mode >> sh) & 7;
        s.push(if b & 4 != 0 { 'r' } else { '-' });
        s.push(if b & 2 != 0 { 'w' } else { '-' });
        s.push(if b & 1 != 0 { 'x' } else { '-' });
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wildcards() {
        assert!(matches("*.bat", "DX.BAT"));
        assert!(matches("*.*", "readme"));
        assert!(matches("d?.*", "dx.com"));
        assert!(!matches("*.exe", "dx.com"));
        assert!(matches_any("*.c;*.h", "a.h"));
    }

    #[test]
    fn ext_split() {
        assert_eq!(split_ext("dx.bat"), ("dx", "bat"));
        assert_eq!(split_ext(".profile"), (".profile", ""));
        assert_eq!(split_ext("a.tar.gz"), ("a.tar", "gz"));
    }

    #[test]
    fn human_sizes() {
        assert_eq!(human(0), "0 B");
        assert_eq!(human(1023), "1023 B");
        assert_eq!(human(1536), "1.5 KB");
        assert_eq!(human(150 * 1024 * 1024), "150 MB");
        assert_eq!(human(1024 * 1024 - 1), "1.0 MB");
    }
}
