//! dxm — the DX program menu (DXM.EXE): up to 15 groups of 21 programs, started with a key or a click.
//! Spec: src/dxm/DXM.PAS, DXMENU.PAS, USERMENU.PAS. Settings live in `$DX_HOME/dx.conf`, the menu in
//! `$DX_HOME/dxmenu.txt`.

mod browser;
mod dxmenu;
mod help;
mod launch;
mod layout;
mod menu;
mod saver;
mod usermenu;

use dxmenu::{Bar, Btn};
use dxtui::settings::{home_dir, Settings};
use dxtui::ui::Ui;
use dxtui::Crt;
use layout::Layout;
use menu::{Menu, ITEMS};
use std::path::{Path, PathBuf};

pub struct Dxm {
    pub ui: Ui,
    pub menu: Menu,
    pub menu_path: PathBuf,
    pub home: PathBuf,
    /// Current group: index into the bar (0 is the admin label, groups start at 1).
    pub cur_group: i32,
    /// Current entry 1..=21.
    pub cur: i32,
    pub last_group: i32,
    pub bar: Bar,
    /// Geometry of the main screen for the current terminal size.
    pub lay: Layout,
    /// Terminal size the layout was made for.
    pub term_size: (i32, i32),
    pub btn: [Btn; ITEMS + 1],
    pub xpos: [i32; ITEMS + 1],
    pub ypos: [i32; ITEMS + 1],
    pub admin_sel: usize,
    pub item_sel: usize,
    pub frame_sel: usize,
    pub password: String,
}

impl Dxm {
    pub fn new(ui: Ui, home: &Path) -> Dxm {
        Dxm {
            ui,
            menu: Menu::default(),
            menu_path: home.join("dxmenu.txt"),
            home: home.to_path_buf(),
            cur_group: 1,
            cur: 1,
            last_group: 0,
            bar: Bar::default(),
            lay: Layout::new(80, 25),
            term_size: (80, 25),
            btn: Default::default(),
            xpos: [0; ITEMS + 1],
            ypos: [0; ITEMS + 1],
            admin_sel: 2,
            item_sel: 1,
            frame_sel: 1,
            password: String::new(),
        }
    }
}

fn main() {
    let home = home_dir();
    let conf_path = home.join("dx.conf");
    let mut conf = Settings::load(&conf_path);
    let crt = match Crt::open(80, 25) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("dxm: {e}");
            std::process::exit(1);
        }
    };
    let mut ui = Ui::new(crt);
    ui.saver_delay = conf.num("saver_delay", 0u32);
    let mut d = Dxm::new(ui, &home);
    d.cur_group = conf.num("menu_group", 1i32).clamp(1, 15);
    d.cur = conf.num("menu_item", 1i32).clamp(1, ITEMS as i32);
    d.password = conf.str_or("password", "");
    loop {
        d.ui.set_color(11, 3);
        d.ui.clr_scr();
        let chosen = d.main_menu();
        conf.set("menu_group", d.cur_group);
        conf.set("menu_item", d.cur);
        let _ = conf.save();
        let Some(item) = chosen else { break };
        d.ui.suspend();
        launch::run(&item);
        d.ui.resume();
        d.ui.reset_idle();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use dxtui::keys::{Key, ESC, F9, RIGHT, SNAPSHOT};

    fn reference(name: &str) -> Vec<u8> {
        std::fs::read(Path::new(env!("CARGO_MANIFEST_DIR")).join("../../ref/dxm").join(name)).unwrap()
    }

    /// Runs the main menu on a sample menu (tools/mkmenu.py) with scripted keys; returns the snapshots.
    fn script(keys: &[u16]) -> Vec<Vec<u16>> {
        let home = std::env::temp_dir().join(format!("dxm-test-{}-{}", std::process::id(), keys.len()));
        let mut m = Menu::default();
        for (g, items) in [("~Spiele", &["TETRIS", "Doom", "-", "Lemmings"][..]), ("~Tools", &["Norton", "Editor"]),
            ("~Office", &["Word"])] {
            let mut grp = menu::Group::new(g);
            for (i, n) in items.iter().enumerate() {
                grp.items[i] = if *n == "-" {
                    menu::Item { name: "\u{2500}".repeat(18), prog: String::new(), chdir: false, wait: false }
                } else {
                    menu::Item { name: n.to_string(), prog: format!("/bin/{n}"), chdir: true, wait: false }
                };
            }
            m.groups.push(grp);
        }
        m.save(&home.join("dxmenu.txt")).unwrap();
        let mut d = Dxm::new(Ui::new(Crt::new(80, 25)), &home);
        for &k in keys {
            d.ui.crt.queue.push_back(Key { code: k, alt: false, shift: false, ctrl: false });
        }
        d.ui.crt.queue.push_back(Key { code: ESC, alt: false, shift: false, ctrl: false });
        assert!(d.main_menu().is_none());
        std::mem::take(&mut d.ui.crt.snaps)
    }

    /// Compares attributes everywhere and characters on rows `y1..=y2` with a DOS capture.
    fn compare(cells: &[u16], scr: &[u8], y1: usize, y2: usize, skip: impl Fn(usize, usize) -> bool) {
        let mut bad = vec![];
        for i in 0..80 * 25 {
            let (ch, at) = (scr[2 * i], scr[2 * i + 1]);
            let (x, y) = (i % 80 + 1, i / 80 + 1);
            // (41,13) holds the DOS mouse cursor in the captures.
            if (x, y) == (41, 13) || skip(x, y) {
                continue;
            }
            if (cells[i] >> 8) as u8 != at || (y1..=y2).contains(&y) && cells[i] as u8 != ch {
                bad.push(format!("({x},{y}) {:04x} want {:02x}{:02x}", cells[i], at, ch));
            }
        }
        assert!(bad.is_empty(), "{} cells differ: {:?}", bad.len(), &bad[..bad.len().min(20)]);
    }

    #[test]
    fn main_screen_matches_original() {
        let s = script(&[SNAPSHOT, RIGHT, SNAPSHOT, F9, SNAPSHOT, ESC, b' ' as u16, SNAPSHOT]);
        let none = |_, _| false;
        compare(&s[0], &reference("MENU.SCR"), 2, 24, none);
        compare(&s[1], &reference("RIGHT.SCR"), 2, 24, none);
        // The English admin label is shorter; the original starts with the "Groups" heading selected,
        // the port with the first function under it. "Modify" has its hotkey on M, "Bearbeiten" on e.
        compare(&s[2], &reference("ADMIN.SCR"), 2, 1, |x, y| y == 1 && x >= 62 || (y == 3 || y == 4) && x > 62 || y == 11 && (64..=65).contains(&x));
        compare(&s[3], &reference("ITEMMENU.SCR"), 2, 24, none);
    }
}
