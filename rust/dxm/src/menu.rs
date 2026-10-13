//! The user menu: up to 15 groups of 21 program entries, stored in `dxmenu.dat`.
//! Spec: src/dxm/USERMENU.PAS (TMenu) and DXMENU.PAS (LoadMenu, SaveMenu, ItemMenu).

use crate::cp437::{read_pstr, write_pstr};
use std::path::Path;
use std::{fs, io};

pub const MAX_GROUPS: usize = 15;
pub const ITEMS: usize = 21;
pub const NAME_LEN: usize = 18;
pub const PROG_LEN: usize = 78;
pub const GROUP_NAME_LEN: usize = 30;

const ITEM_SIZE: usize = 1 + NAME_LEN + 1 + PROG_LEN + 1;
const GROUP_SIZE: usize = 1 + GROUP_NAME_LEN + 1 + ITEMS * ITEM_SIZE;
pub const FILE_SIZE: usize = 1 + MAX_GROUPS * GROUP_SIZE;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Item {
    pub name: String,
    /// Full path of the program; empty for an unused slot or a separator line.
    pub prog: String,
    /// Stored per entry, but DXM always changes into the program's directory anyway.
    pub chdir: bool,
}

impl Item {
    /// Entry for a newly chosen program: name is the file name without extension, first letter upper case.
    pub fn for_program(path: &str) -> Item {
        let file = path.rsplit(['\\', '/']).next().unwrap_or(path);
        let stem = file.split('.').next().unwrap_or(file);
        let mut name: String = stem.chars().take(8).collect();
        if let Some(c) = name.chars().next() {
            name.replace_range(..c.len_utf8(), &upcase(c).to_string());
        }
        Item { name, prog: path.to_string(), chdir: true }
    }

    /// A separator: the frame character repeated over the whole button width.
    pub fn separator(c: char) -> Item {
        Item { name: std::iter::repeat_n(c, NAME_LEN).collect(), prog: String::new(), chdir: true }
    }

    pub fn is_runnable(&self) -> bool {
        !self.prog.is_empty()
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Group {
    /// May contain one '~' marking the hotkey letter.
    pub name: String,
    pub flag: u8,
    pub items: [Item; ITEMS],
}

impl Group {
    pub fn new(name: &str) -> Group {
        Group { name: name.to_string(), flag: 1, items: Default::default() }
    }

    /// The name as shown in the menu bar (tilde removed).
    pub fn label(&self) -> String {
        self.name.replacen('~', "", 1)
    }

    /// Lower-case letter after the '~', if any.
    pub fn hotkey(&self) -> Option<char> {
        let mut it = self.name.chars().skip_while(|&c| c != '~');
        it.next()?;
        it.next().map(locase)
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Menu {
    pub groups: Vec<Group>,
}

#[derive(Debug)]
pub enum MenuError {
    TooManyGroups,
    LastGroup,
    EmptyName,
}

impl Menu {
    pub fn load(path: &Path) -> io::Result<Menu> {
        Menu::from_bytes(&fs::read(path)?)
    }

    pub fn save(&self, path: &Path) -> io::Result<()> {
        fs::write(path, self.to_bytes())
    }

    pub fn from_bytes(b: &[u8]) -> io::Result<Menu> {
        if b.len() < FILE_SIZE {
            return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "dxmenu.dat too short"));
        }
        let count = (b[0] as usize).min(MAX_GROUPS);
        let groups = (0..count)
            .map(|g| {
                let gb = &b[1 + g * GROUP_SIZE..];
                let mut group = Group::new(&read_pstr(gb, GROUP_NAME_LEN));
                group.flag = gb[1 + GROUP_NAME_LEN];
                for (i, item) in group.items.iter_mut().enumerate() {
                    let ib = &gb[2 + GROUP_NAME_LEN + i * ITEM_SIZE..];
                    item.name = read_pstr(ib, NAME_LEN);
                    item.prog = read_pstr(&ib[1 + NAME_LEN..], PROG_LEN);
                    item.chdir = ib[2 + NAME_LEN + PROG_LEN] != 0;
                }
                group
            })
            .collect();
        Ok(Menu { groups })
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        let mut b = vec![0u8; FILE_SIZE];
        b[0] = self.groups.len() as u8;
        for (g, group) in self.groups.iter().enumerate() {
            let gb = &mut b[1 + g * GROUP_SIZE..];
            write_pstr(gb, GROUP_NAME_LEN, &group.name);
            gb[1 + GROUP_NAME_LEN] = group.flag;
            for (i, item) in group.items.iter().enumerate() {
                let ib = &mut gb[2 + GROUP_NAME_LEN + i * ITEM_SIZE..];
                write_pstr(ib, NAME_LEN, &item.name);
                write_pstr(&mut ib[1 + NAME_LEN..], PROG_LEN, &item.prog);
                ib[2 + NAME_LEN + PROG_LEN] = item.chdir as u8;
            }
        }
        b
    }

    /// Appends a group. A trailing '~' (hotkey marker without a letter) is dropped.
    pub fn add_group(&mut self, name: &str) -> Result<usize, MenuError> {
        if self.groups.len() >= MAX_GROUPS {
            return Err(MenuError::TooManyGroups);
        }
        let name = name.strip_suffix('~').unwrap_or(name);
        if name.is_empty() {
            return Err(MenuError::EmptyName);
        }
        self.groups.push(Group::new(name));
        Ok(self.groups.len() - 1)
    }

    /// The last remaining group can't be deleted.
    pub fn delete_group(&mut self, g: usize) -> Result<(), MenuError> {
        if self.groups.len() <= 1 {
            return Err(MenuError::LastGroup);
        }
        self.groups.remove(g);
        Ok(())
    }

    pub fn rename_group(&mut self, g: usize, name: &str) -> Result<(), MenuError> {
        let name = name.strip_suffix('~').unwrap_or(name);
        if name.is_empty() {
            return Err(MenuError::EmptyName);
        }
        self.groups[g].name = name.to_string();
        Ok(())
    }
}

/// Upper case as DX does it: ASCII plus the German umlauts.
pub fn upcase(c: char) -> char {
    match c {
        'a'..='z' => c.to_ascii_uppercase(),
        'ü' => 'Ü',
        'ä' => 'Ä',
        'ö' => 'Ö',
        _ => c,
    }
}

pub fn locase(c: char) -> char {
    match c {
        'A'..='Z' => c.to_ascii_lowercase(),
        'Ü' => 'ü',
        'Ä' => 'ä',
        'Ö' => 'ö',
        _ => c,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn layout() {
        assert_eq!(FILE_SIZE, 31666);
    }

    #[test]
    fn roundtrip() {
        let mut m = Menu::default();
        m.add_group("~Spiele").unwrap();
        m.groups[0].items[3] = Item::for_program("C:\\GAMES\\tetris.exe");
        m.groups[0].items[4] = Item::separator('─');
        let b = m.to_bytes();
        assert_eq!(b.len(), FILE_SIZE);
        assert_eq!(Menu::from_bytes(&b).unwrap(), m);
        assert_eq!(m.groups[0].items[3].name, "Tetris");
        assert_eq!(m.groups[0].hotkey(), Some('s'));
        assert_eq!(m.groups[0].label(), "Spiele");
    }

    #[test]
    fn group_rules() {
        let mut m = Menu::default();
        assert!(matches!(m.add_group("~"), Err(MenuError::EmptyName)));
        m.add_group("A").unwrap();
        assert!(matches!(m.delete_group(0), Err(MenuError::LastGroup)));
        for i in 1..MAX_GROUPS {
            m.add_group(&i.to_string()).unwrap();
        }
        assert!(matches!(m.add_group("x"), Err(MenuError::TooManyGroups)));
    }
}
