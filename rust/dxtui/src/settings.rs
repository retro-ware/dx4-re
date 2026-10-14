//! Settings shared by the DX programs: a `key = value` text file, by default `~/.config/dx/dx.conf`
//! (the directory can be overridden with `DX_HOME`). Unknown keys are kept when saving.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

/// Directory for the settings and data files of all DX programs.
pub fn home_dir() -> PathBuf {
    if let Some(d) = std::env::var_os("DX_HOME") {
        return d.into();
    }
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| Path::new(&h).join(".config")))
        .unwrap_or_else(|| ".".into());
    base.join("dx")
}

#[derive(Default, Debug, Clone)]
pub struct Settings {
    path: PathBuf,
    map: BTreeMap<String, String>,
}

impl Settings {
    pub fn load(path: &Path) -> Settings {
        let mut map = BTreeMap::new();
        if let Ok(s) = std::fs::read_to_string(path) {
            for line in s.lines() {
                let line = line.trim();
                if line.starts_with('#') {
                    continue;
                }
                if let Some((k, v)) = line.split_once('=') {
                    map.insert(k.trim().to_string(), v.trim().to_string());
                }
            }
        }
        Settings { path: path.to_path_buf(), map }
    }

    pub fn save(&self) -> std::io::Result<()> {
        if let Some(d) = self.path.parent() {
            std::fs::create_dir_all(d)?;
        }
        let mut s = String::from("# DOS-Expander settings\n");
        for (k, v) in &self.map {
            s += &format!("{k} = {v}\n");
        }
        std::fs::write(&self.path, s)
    }

    pub fn get(&self, k: &str) -> Option<&str> {
        self.map.get(k).map(String::as_str)
    }

    pub fn str_or(&self, k: &str, d: &str) -> String {
        self.get(k).unwrap_or(d).to_string()
    }

    pub fn num<T: std::str::FromStr>(&self, k: &str, d: T) -> T {
        self.get(k).and_then(|v| v.parse().ok()).unwrap_or(d)
    }

    pub fn flag(&self, k: &str, d: bool) -> bool {
        match self.get(k) {
            Some("1" | "yes" | "true" | "on") => true,
            Some("0" | "no" | "false" | "off") => false,
            _ => d,
        }
    }

    pub fn set(&mut self, k: &str, v: impl ToString) {
        self.map.insert(k.to_string(), v.to_string());
    }

    pub fn remove(&mut self, k: &str) {
        self.map.remove(k);
    }

    /// Forgets all values (the file is written on the next `save`).
    pub fn clear(&mut self) {
        self.map.clear();
    }

    /// Keys starting with `prefix`, with their values.
    pub fn with_prefix(&self, prefix: &str) -> Vec<(String, String)> {
        self.map.iter().filter(|(k, _)| k.starts_with(prefix)).map(|(k, v)| (k.clone(), v.clone())).collect()
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn set_path(&mut self, p: &Path) {
        self.path = p.to_path_buf();
    }
}
