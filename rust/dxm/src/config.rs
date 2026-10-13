//! `dx.ini`: the 1810-byte settings record shared by all DX programs. DXM only reads a few fields
//! and writes back the last menu position; everything else is preserved byte for byte.
//! Spec: src/dxm/DXM.PAS (TConfig, LoadCfg, SaveCfg).
// Screen-saver and password fields are for the not-yet-ported saver (SAVER.PAS).
#![cfg_attr(not(test), allow(dead_code))]

use crate::cp437::read_pstr;
#[cfg(test)]
use crate::cp437::write_pstr;
use std::path::Path;
use std::{fs, io};

pub const ID: &str = "DOS-Expander 4.0 (C) 1994-1996 Hombergs";
pub const SIZE: usize = 0x712;
pub const INI_NAME: &str = "dx.ini";

const OFS_SAVER_DELAY: usize = 0x284;
const OFS_PASSWORD: usize = 0x5C5;
const OFS_MENU_POS: usize = 0x6E0;
const OFS_SAVER_PROG: usize = 0x6FC;

pub struct Config {
    raw: Vec<u8>,
}

/// Last selected entry, saved when DXM quits.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct MenuPos {
    pub group: usize,
    pub item: usize,
}

impl Config {
    /// `None` when the file is missing, short, or not a DOS-Expander 4.0 settings file
    /// (DXM then silently uses defaults and never writes it).
    pub fn load(path: &Path) -> Option<Config> {
        let raw = fs::read(path).ok()?;
        (raw.len() >= SIZE && read_pstr(&raw, 41) == ID).then_some(Config { raw })
    }

    pub fn save(&self, path: &Path) -> io::Result<()> {
        fs::write(path, &self.raw)
    }

    fn word(&self, ofs: usize) -> u16 {
        u16::from_le_bytes([self.raw[ofs], self.raw[ofs + 1]])
    }

    /// 0-based group/item. Out-of-range values fall back to the first entry, as DXM does.
    pub fn menu_pos(&self) -> MenuPos {
        let w = self.word(OFS_MENU_POS);
        let (group, item) = ((w & 0xFF) as usize, (w >> 8) as usize);
        MenuPos {
            group: if (1..=15).contains(&group) { group - 1 } else { 0 },
            item: if (1..=21).contains(&item) { item - 1 } else { 0 },
        }
    }

    pub fn set_menu_pos(&mut self, p: MenuPos) {
        let w = ((p.item as u16 + 1) << 8) | (p.group as u16 + 1);
        self.raw[OFS_MENU_POS..OFS_MENU_POS + 2].copy_from_slice(&w.to_le_bytes());
    }

    /// Idle time before the screen saver starts.
    pub fn saver_delay_secs(&self) -> u16 {
        self.word(OFS_SAVER_DELAY)
    }

    /// Stored with every character code shifted up by 13.
    pub fn password(&self) -> String {
        let b = &self.raw[OFS_PASSWORD..];
        let len = (b[0] as usize).min(12);
        let plain: Vec<u8> = b[1..1 + len].iter().map(|c| c.wrapping_sub(13)).collect();
        crate::cp437::decode(&plain)
    }

    pub fn saver_prog(&self) -> String {
        read_pstr(&self.raw[OFS_SAVER_PROG..], 12)
    }

    #[cfg(test)]
    fn set_saver_prog(&mut self, s: &str) {
        write_pstr(&mut self.raw[OFS_SAVER_PROG..], 12, s);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shipped_dx_ini() {
        let p = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../dist/DX4/DX.INI");
        let Some(mut c) = Config::load(&p) else { return }; // dist/ isn't in the repo
        assert_eq!(c.menu_pos(), MenuPos { group: 0, item: 0 });
        assert_eq!(c.saver_delay_secs(), 480);
        c.set_menu_pos(MenuPos { group: 2, item: 20 });
        assert_eq!(c.menu_pos(), MenuPos { group: 2, item: 20 });
        c.set_saver_prog("STERNE.BSS");
        assert_eq!(c.saver_prog(), "STERNE.BSS");
    }
}
