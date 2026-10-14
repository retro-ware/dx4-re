//! The user menu: up to 15 groups of 21 program entries (UserMenu.TMenu).
//!
//! Stored as `dxmenu.txt` in the DX home directory, one line per group or entry, fields separated by tabs:
//! `G<TAB>name` starts a group, `I<TAB>name<TAB>command<TAB>chdir` is an entry (21 per group, empty
//! slots included). `chdir` is 1 or 0.

use std::path::Path;
use std::{fs, io};

pub const MAX_GROUPS: usize = 15;
pub const ITEMS: usize = 21;
pub const NAME_LEN: usize = 18;
pub const PROG_LEN: usize = 78;

#[derive(Clone, Debug, PartialEq)]
pub struct Item {
    pub name: String,
    /// Command line; empty for an unused slot or a separator line.
    pub prog: String,
    /// Start in the program's directory.
    pub chdir: bool,
}

impl Default for Item {
    fn default() -> Item {
        Item { name: String::new(), prog: String::new(), chdir: true }
    }
}

impl Item {
    /// Entry for a newly chosen program: the file name without extension, first letter upper case.
    pub fn for_program(path: &str) -> Item {
        Item { name: default_name(path), prog: path.to_string(), chdir: true }
    }

    pub fn is_empty(&self) -> bool {
        self.name.is_empty() && self.prog.is_empty()
    }
}

/// FSplit name part with the first letter upper case (MainMenu, Ins key).
pub fn default_name(path: &str) -> String {
    let file = path.rsplit('/').next().unwrap_or(path);
    let stem = match file.rfind('.') {
        Some(p) if p > 0 => &file[..p],
        _ => file,
    };
    let mut name: String = stem.chars().take(NAME_LEN).collect();
    if let Some(c) = name.chars().next() {
        name.replace_range(..c.len_utf8(), &dxtui::up_case(c).to_string());
    }
    name
}

#[derive(Clone, Debug, PartialEq)]
pub struct Group {
    /// May contain one '~' marking the hotkey letter.
    pub name: String,
    pub items: Vec<Item>,
}

impl Group {
    pub fn new(name: &str) -> Group {
        Group { name: name.to_string(), items: vec![Item::default(); ITEMS] }
    }

    /// Lower-case letter after the '~' (UserMenu.HotKey).
    pub fn hotkey(&self) -> Option<char> {
        let p = self.name.find('~')?;
        self.name[p + 1..].chars().next().map(dxtui::lo_case)
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Menu {
    pub groups: Vec<Group>,
}

fn clean(s: &str) -> String {
    s.replace(['\t', '\n', '\r'], " ")
}

impl Menu {
    pub fn load(path: &Path) -> io::Result<Menu> {
        Ok(Menu::parse(&fs::read_to_string(path)?))
    }

    pub fn parse(s: &str) -> Menu {
        let mut m = Menu::default();
        let mut n = 0;
        for line in s.lines() {
            let f: Vec<&str> = line.split('\t').collect();
            match f[0] {
                "G" if m.groups.len() < MAX_GROUPS => {
                    m.groups.push(Group::new(f.get(1).copied().unwrap_or("")));
                    n = 0;
                }
                "I" if n < ITEMS => {
                    if let Some(g) = m.groups.last_mut() {
                        g.items[n] = Item {
                            name: f.get(1).copied().unwrap_or("").to_string(),
                            prog: f.get(2).copied().unwrap_or("").to_string(),
                            chdir: f.get(3).copied() != Some("0"),
                        };
                        n += 1;
                    }
                }
                _ => {}
            }
        }
        m
    }

    pub fn to_text(&self) -> String {
        let mut s = String::new();
        for g in &self.groups {
            s += &format!("G\t{}\n", clean(&g.name));
            for it in &g.items {
                s += &format!("I\t{}\t{}\t{}\n", clean(&it.name), clean(&it.prog), it.chdir as u8);
            }
        }
        s
    }

    pub fn save(&self, path: &Path) -> io::Result<()> {
        if let Some(d) = path.parent() {
            fs::create_dir_all(d)?;
        }
        fs::write(path, self.to_text())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip() {
        let mut m = Menu::default();
        m.groups.push(Group::new("~Games"));
        m.groups[0].items[3] = Item::for_program("/usr/games/tetris.sh");
        m.groups[0].items[4] = Item { name: "─".repeat(18), prog: String::new(), chdir: false };
        let t = m.to_text();
        assert_eq!(Menu::parse(&t), m);
        assert_eq!(m.groups[0].items[3].name, "Tetris");
        assert_eq!(m.groups[0].hotkey(), Some('g'));
    }
}
