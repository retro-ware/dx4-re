//! Main screen of DXM: group bar, 3x7 program buttons, admin menu, entry menu.
//! Spec: src/dxm/DXMENU.PAS (MainMenu, AdminMenu, ItemMenu, FrameMenu, DeleteEntry, TBtn).

use crate::layout::{caption, Layout};
use crate::menu::{Item, Menu, ITEMS};
use crate::Dxm;
use dxtui::button::Buttons;
use dxtui::keys::*;
use dxtui::Crt;

/// The program buttons of the main screen (DXMenu.TBtn): the caption sits on its own background, and the
/// focused button gets a blue surround.
#[derive(Clone, Default)]
pub struct Btn {
    pub x: i32,
    pub y: i32,
    /// Three-line button with a border, or a single `[Name]` line.
    boxed: bool,
    foc_fg: u8,
    foc_bg: u8,
    fg: u8,
    bg: u8,
    foc_shadow: u8,
    pressed: bool,
    pub focused: bool,
    old_pressed: bool,
    old_focused: bool,
    text: String,
    armed: bool,
}

impl Btn {
    #[allow(clippy::too_many_arguments)]
    pub fn init(&mut self, c: &mut Crt, focus: bool, boxed: bool, x: i32, y: i32, foc_fg: u8, foc_bg: u8, fg: u8,
        bg: u8, foc_shadow: u8, s: &str) {
        *self = Btn {
            x,
            y,
            boxed,
            foc_fg,
            foc_bg,
            fg,
            bg,
            foc_shadow,
            pressed: false,
            old_pressed: true,
            focused: focus,
            old_focused: !focus,
            text: format!(" {s} "),
            armed: false,
        };
        self.draw(c);
    }

    fn len(&self) -> i32 {
        self.text.chars().count() as i32
    }

    pub fn set_focus(&mut self, c: &mut Crt, f: bool) {
        self.focused = f;
        self.armed = false;
        self.draw(c);
    }

    pub fn draw(&mut self, c: &mut Crt) {
        let a = c.text_attr;
        if self.old_focused == self.focused && self.old_pressed == self.pressed {
            return;
        }
        self.old_focused = self.focused;
        self.old_pressed = self.pressed;
        if !self.boxed {
            self.draw_line(c);
            c.text_attr = a;
            return;
        }
        let (mut c2, mut c3) = (0, 0);
        let c4 = if self.focused { self.foc_fg } else { self.foc_bg };
        let c7 = if self.focused { 1 } else { self.bg };
        let (l, r): (&[u8], &[u8]) = if self.pressed {
            c3 = self.fg;
            (b" ", b"")
        } else {
            c2 = self.fg;
            (b"", b" ")
        };
        c.set_color(c2, c7);
        let c6 = if self.focused { self.foc_shadow } else { c7 };
        for i in 0..3 {
            c.write_xy(self.x - 1, self.y + i, " ");
        }
        let n = self.len() as usize;
        c.write_xy_b(self.x, self.y, &[l, b"\xDA"].concat());
        c.write_b(&vec![0xC4; n]);
        c.text_color(c3);
        c.write_b(&[b"\xBF", r].concat());
        c.text_color(c2);
        c.write_xy_b(self.x, self.y + 1, &[l, b"\xB3"].concat());
        c.write_fb(c4, c6, &self.text);
        c.text_color(c3);
        c.write_b(&[b"\xB3", r].concat());
        c.text_color(c2);
        c.write_xy_b(self.x, self.y + 2, &[l, b"\xC0"].concat());
        c.text_color(c3);
        c.write_b(&vec![0xC4; n]);
        c.write_b(&[b"\xD9", r].concat());
        c.text_attr = a;
    }

    /// The one-line look for short terminals: `[Name]`, yellow on blue when focused, inverted while pressed.
    fn draw_line(&self, c: &mut Crt) {
        let (fg, bg) = if self.pressed {
            (15, 0)
        } else if self.focused {
            (self.foc_fg, 1)
        } else {
            (self.foc_bg, self.bg)
        };
        let inner: String = self.text.chars().skip(1).take(self.len() as usize - 2).collect();
        c.set_color(0, self.bg);
        c.write_xy(self.x - 1, self.y, " ");
        c.write_xy(self.x + self.len(), self.y, " ");
        c.set_color(fg, bg);
        c.write_xy(self.x, self.y, &format!("[{inner}]"));
    }

    /// TBtn.Clicked: like Buttons.MouseButton (first poll arms, second presses until release).
    pub fn clicked(&mut self, ui: &mut dxtui::ui::Ui) -> bool {
        let (wx, wy, _, _) = ui.win();
        // The caption of a boxed button is one cell in and one row down; a line button has no border.
        let (x1, y1) = if self.boxed { (self.x + wx, self.y + wy) } else { (self.x + wx - 2, self.y + wy - 1) };
        let x2 = x1 + self.len() + !self.boxed as i32;
        let m = ui.mouse;
        let mut hit = false;
        if m.button == 1 && y1 == m.y && x1 < m.x && x2 > m.x {
            if self.armed {
                self.pressed = true;
                self.armed = false;
                self.draw(ui);
                loop {
                    let m = ui.mouse;
                    if m.button == 0 || y1 != m.y || x1 >= m.x || x2 < m.x || ui.term.is_none() {
                        break;
                    }
                    ui.pump();
                }
                let m = ui.mouse;
                hit = y1 == m.y && x1 < m.x && x2 + 1 > m.x;
                self.pressed = false;
                self.draw(ui);
            } else {
                self.armed = true;
            }
            self.focused = true;
        }
        hit
    }
}

/// One label of the group bar (UserMenu.TLabel).
#[derive(Clone)]
pub struct Label {
    pub text: String,
    pub x: i32,
    /// Hotkey: a plain key code (letter) for groups, Alt+letter for the admin label.
    pub key: u16,
}

impl Label {
    pub fn draw(&self, c: &mut Crt, hi: bool) {
        c.set_color(0, if hi { 2 } else { 3 });
        c.write_xy(self.x - 1, 1, " ");
        c.goto_xy(self.x, 1);
        let mut it = self.text.chars();
        while let Some(ch) = it.next() {
            if ch == '~' {
                if let Some(h) = it.next() {
                    c.write_f(4, &h.to_string());
                }
            } else {
                c.write(&ch.to_string());
            }
        }
        c.write(" ");
    }
}

pub const ADMIN_LABEL: &str = "~Admin";

/// Keys of the admin menu.
pub fn admin_key() -> u16 {
    alt_letter('a').unwrap()
}

/// The group bar (UserMenu.TMenuBar): label 0 is the admin entry at the right, label g is group g.
#[derive(Clone, Default)]
pub struct Bar {
    pub items: Vec<Label>,
    /// Column of the admin label at the right end of the bar.
    pub admin_x: i32,
}

impl Bar {
    /// TMenuBar.Init / Redraw: clears the top line and lays out the labels from column 4.
    pub fn redraw(&mut self, c: &mut Crt, menu: &Menu) {
        let a = c.text_attr;
        c.set_color(0, 3);
        c.goto_xy(1, 1);
        c.clr_eol();
        c.text_attr = a;
        self.items = vec![Label { text: ADMIN_LABEL.into(), x: self.admin_x, key: admin_key() }];
        let mut x = 4;
        for g in &menu.groups {
            let l = Label { text: g.name.clone(), x, key: g.hotkey().map_or(255, |h| h as u16) };
            x += l.text.chars().count() as i32 + 1;
            self.items.push(l);
        }
        for l in &self.items {
            l.draw(c, false);
        }
        c.text_attr = a;
    }

    pub fn count(&self) -> usize {
        self.items.len()
    }

    /// Right end of the last label (X + Length(Text)).
    pub fn end(&self) -> i32 {
        self.items.last().map_or(0, |l| l.x + l.text.chars().count() as i32)
    }
}

const ADMIN_ITEMS: [(&str, usize); 11] = [
    ("\u{2550}\u{2550} Groups \u{2550}\u{2550}\u{2550}\u{2550}\u{2550}", 0),
    (" New           ", 2),
    (" Delete        ", 2),
    (" Sort          ", 2),
    (" Rename        ", 2),
    ("\u{2550}\u{2550} Entries \u{2550}\u{2550}\u{2550}\u{2550}", 0),
    (" Delete        ", 3),
    (" Sort          ", 3),
    (" Modify        ", 2),
    ("\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}", 0),
    (" Quit       Esc", 2),
];

const ITEM_ITEMS: [(&str, usize); 6] = [
    (" New         ", 2),
    (" Change      ", 2),
    (" Delete      ", 2),
    (" Exchange    ", 2),
    (" Separator   ", 2),
    (" Quit        ", 2),
];

/// Draws a pull-down menu's entries at rows 1.. of the current window; the hotkey letter in red.
fn draw_items(c: &mut Crt, items: &[(&str, usize)], sel: usize) {
    for (i, (t, hot)) in items.iter().enumerate() {
        let row = i as i32 + 1;
        if i + 1 == sel {
            c.write_xyfb(1, row, 0, 2, t);
            if *hot > 0 {
                let h: String = t.chars().nth(hot - 1).unwrap().to_string();
                c.write_xyfb(*hot as i32, row, 4, 2, &h);
            }
        } else {
            c.write_xy(1, row, t);
            if *hot > 0 {
                let h: String = t.chars().nth(hot - 1).unwrap().to_string();
                c.write_xyf(*hot as i32, row, 4, &h);
            }
        }
    }
}

/// The hotkey letters of a menu (lower case), in entry order.
fn hot_of(items: &[(&str, usize)], i: usize) -> Option<char> {
    let (t, h) = items[i];
    (h > 0).then(|| dxtui::lo_case(t.chars().nth(h - 1).unwrap()))
}

/// A pull-down menu at window position (x, y) with `items` (1-based `sel`, remembered by the caller).
/// Shared loop of AdminMenu, ItemMenu and FrameMenu. `skip` are entries the cursor and mouse skip.
/// Returns the chosen entry or None.
fn pull_down(d: &mut Dxm, x: i32, y: i32, w: i32, items: &[(&str, usize)], sel: &mut usize, skip: &[usize],
    extra_keys: &[(u16, usize)]) -> Option<usize> {
    let n = items.len();
    let ui = &mut d.ui;
    let r = ui.rows();
    ui.window(x, y, 80, r);
    draw_items(ui, items, *sel);
    let mut still = true;
    let (mut old_x, mut old_y) = (ui.mouse.x, ui.mouse.y);
    ui.wait_release();
    let inside = |mx: i32, my: i32| x - 1 < mx && x + w > mx && y <= my && y + n as i32 > my;
    let ok = |s: usize| !skip.contains(&s);
    loop {
        let mut key = ui.get_key();
        let m = ui.mouse;
        if old_y != m.y || old_x != m.x {
            still = false;
            old_y = m.y;
            old_x = m.x;
        }
        match key {
            F1 => {
                let w = ui.get_win();
                crate::help::show_help(ui, &d.home, 14);
                ui.set_win(&w);
            }
            DOWN => {
                still = true;
                loop {
                    *sel = *sel % n + 1;
                    if ok(*sel) {
                        break;
                    }
                }
                draw_items(ui, items, *sel);
            }
            UP => {
                still = true;
                loop {
                    *sel = if *sel <= 1 { n } else { *sel - 1 };
                    if ok(*sel) {
                        break;
                    }
                }
                draw_items(ui, items, *sel);
            }
            _ => {}
        }
        if let Some(c) = dxtui::Key::new(key).char().map(dxtui::lo_case) {
            if let Some(i) = (0..n).find(|&i| hot_of(items, i) == Some(c)) {
                *sel = i + 1;
                key = ENTER;
            }
        }
        if let Some(&(_, s)) = extra_keys.iter().find(|(k, _)| *k == key) {
            *sel = s;
            key = ENTER;
        }
        if key == ENTER {
            still = true;
        }
        let m = ui.mouse;
        if m.button == 1 && inside(m.x, m.y) && ok((m.y - y + 1) as usize) {
            loop {
                ui.pump();
                let m = ui.mouse;
                let s = (m.y - y + 1) as usize;
                if y <= m.y && y + n as i32 > m.y && ok(s) && *sel != s {
                    *sel = s;
                    draw_items(ui, items, *sel);
                }
                if ui.mouse.button == 0 || ui.term.is_none() {
                    break;
                }
            }
            let m = ui.mouse;
            if inside(m.x, m.y) && ok((m.y - y + 1) as usize) {
                key = ENTER;
            }
        }
        if ui.mouse_outside(x - 1, x + w, y - 1, y + n as i32) {
            key = ESC;
        }
        let m = ui.mouse;
        let s = (m.y - y + 1) as usize;
        if inside(m.x, m.y) && !still && ok(s) && *sel != s {
            *sel = s;
            draw_items(ui, items, *sel);
        }
        if key == ENTER {
            return Some(*sel);
        }
        if key == ESC || key == F10 || ui.mouse.button == 2 {
            return None;
        }
    }
}

impl Dxm {
    pub fn item(&self, i: i32) -> &Item {
        &self.menu.groups[self.cur_group as usize - 1].items[i as usize - 1]
    }

    pub fn item_mut(&mut self, g: i32, i: i32) -> &mut Item {
        &mut self.menu.groups[g as usize - 1].items[i as usize - 1]
    }

    fn draw_label(&mut self, n: usize, hi: bool) {
        if let Some(l) = self.bar.items.get(n) {
            l.draw(&mut self.ui, hi);
        }
    }

    /// SwitchLabel (indices: 0 = admin, g = group g).
    fn switch_label(&mut self, new: usize, old: usize) {
        let w = self.ui.save_win();
        self.draw_label(old, false);
        self.draw_label(new, true);
        self.ui.restore_win(&w);
    }

    /// ShowGroup: draws the 21 buttons of the current group, the current one focused.
    pub fn show_group(&mut self) {
        let count = self.menu.groups.len() as i32;
        if self.cur_group < 1 {
            self.cur_group = count;
        }
        if count < self.cur_group {
            self.cur_group = 1;
        }
        let cur = self.cur as usize;
        let name = self.item(self.cur).name.clone();
        let (x, y) = (self.xpos[cur], self.ypos[cur]);
        let (boxed, nw) = (self.lay.boxed, self.lay.name_w);
        self.btn[cur].init(&mut self.ui, true, boxed, x, y, 14, 0, 15, 7, 1, &caption(&name, nw));
        if boxed {
            let shown: String = name.chars().take(nw as usize).collect();
            let p = (nw - shown.chars().count() as i32) / 2 + 1;
            self.ui.write_xyfb(x + p, y + 1, 14, 1, &format!(" {shown} "));
        }
        for i in 1..=ITEMS {
            if i != cur {
                let n = self.item(i as i32).name.clone();
                let (x, y) = (self.xpos[i], self.ypos[i]);
                self.btn[i].init(&mut self.ui, false, boxed, x, y, 14, 0, 15, 7, 1, &caption(&n, nw));
            }
        }
        let (cg, lg) = (self.cur_group as usize, self.last_group as usize);
        self.switch_label(cg, lg);
    }

    pub fn save_menu(&mut self) {
        if self.menu.save(&self.menu_path).is_err() {
            let p = self.menu_path.display().to_string();
            self.ui.msg_box("Error writing the menu file", &p);
        }
    }

    /// Yes/No box (DeleteEntry and friends): `text` centred in a teal frame, true for Yes.
    #[allow(clippy::too_many_arguments)]
    pub fn confirm_box(&mut self, x: i32, y: i32, w: i32, text: &str, center_text: bool, fg: u8, bg: u8, first: bool)
        -> bool {
        self.ui.open_dialog();
        self.ui.frame(x, y, w, 4, fg, bg, false, true);
        if center_text {
            self.ui.write_center_xyf(1, 1, w, fg, text);
        } else {
            self.ui.write_f(fg, text);
        }
        let mut b = Buttons::new(&mut self.ui, first, &[(3, 2), (16, 2)], 14, 0, fg, bg, &["  Yes   ", "   No   "]);
        let mut key = 0;
        let yes = loop {
            let hit = b.handle(&mut self.ui, &mut key);
            let c = dxtui::Key::new(key).char().map(dxtui::lo_case);
            if hit == Some(0) || c == Some('y') {
                break true;
            }
            if hit == Some(1) || c == Some('n') {
                break false;
            }
            if self.ui.is_cancel(key) || self.ui.mouse_outside(x, x + w + 1, y, y + 5) {
                break false;
            }
        };
        self.ui.pop_screen();
        self.ui.wait_release();
        yes
    }

    fn delete_entry(&mut self) {
        if self.item(self.cur).name.is_empty() {
            return;
        }
        let q = format!("Delete {}?", self.item(self.cur).name);
        let (x, y) = ((self.lay.w - 29) / 2, (self.lay.h - 4) / 2);
        if self.confirm_box(x, y, 29, &q, true, 11, 6, true) {
            let (g, c) = (self.cur_group, self.cur);
            *self.item_mut(g, c) = Item::default();
            self.save_menu();
            self.show_group();
            self.ui.wait_release();
        }
    }

    /// AdminMenu: the pull-down under the admin label.
    fn admin_menu(&mut self) -> usize {
        self.ui.open_dialog();
        let ax = self.lay.w - 18;
        self.ui.frame(ax, 2, 15, 11, 11, 3, true, true);
        let mut sel = self.admin_sel;
        let r = pull_down(self, ax + 1, 3, 15, &ADMIN_ITEMS, &mut sel, &[1, 6, 10], &[]);
        self.admin_sel = sel;
        self.ui.pop_screen();
        r.unwrap_or(0)
    }

    /// Admin: runs the chosen admin function. Returns the admin-quit key when "Quit" was chosen.
    fn admin(&mut self) -> u16 {
        let w = self.ui.save_win();
        let mut res = 0;
        let cg = self.cur_group as usize;
        self.switch_label(0, cg);
        let sel = self.admin_menu();
        self.switch_label(cg, 0);
        let sel = if matches!(sel, 2..=5 | 8 | 9) && !self.fits_dialogs() { 0 } else { sel };
        match sel {
            2 => {
                if self.add_group() {
                    self.save_menu()
                }
            }
            3 => {
                if self.group_dialog(1) {
                    self.save_menu()
                }
            }
            4 => {
                if self.sort_groups() {
                    self.save_menu()
                }
            }
            5 => {
                if self.group_dialog(2) {
                    self.save_menu()
                }
            }
            7 => self.delete_entry(),
            8 => {
                self.sort_items(self.cur_group);
                self.save_menu();
            }
            9 => {
                if self.edit_group(self.cur_group, self.cur) {
                    self.save_menu()
                }
            }
            11 => res = F10,
            _ => {}
        }
        self.ui.restore_win(&w);
        let count = self.menu.groups.len() as i32;
        if count < self.cur_group {
            self.cur_group = count;
        }
        self.show_group();
        self.ui.wait_release();
        res
    }

    /// FrameMenu: choice of separator characters.
    fn frame_menu(&mut self, x: i32, y: i32) -> Option<char> {
        const CHARS: [char; 6] = ['─', '*', '~', '█', '.', '-'];
        let strs: Vec<String> = CHARS.iter().map(|c| c.to_string().repeat(16)).collect();
        let items: Vec<(&str, usize)> = strs.iter().map(|s| (s.as_str(), 0)).collect();
        self.ui.open_dialog();
        self.ui.frame(x - 1, y - 1, 16, 6, 11, 3, false, true);
        let mut sel = self.frame_sel;
        let r = pull_down(self, x, y, 16, &items, &mut sel, &[], &[]);
        self.frame_sel = sel;
        self.ui.close_dialog();
        r.map(|s| CHARS[s - 1])
    }

    /// ItemMenu: entry menu opened with the right mouse button or Ctrl-Enter at mouse/button (mx, my).
    /// Returns true for "Quit".
    fn item_menu(&mut self, g: i32, it: i32, mx: i32, my: i32) -> bool {
        let x = match self.lay.button_at(mx, my) {
            Some(i) => self.lay.text_cols(i).0 + 3,
            None => mx,
        };
        let x = x.min(self.lay.w - 15).max(2);
        // Below the button; above it when the menu (6 rows plus border) would not fit.
        let y = if my + 8 > self.lay.h - 1 { my - 7 } else { my + 2 }.max(2);
        self.ui.open_dialog();
        self.ui.frame(x - 1, y - 1, 13, 6, 11, 3, true, true);
        let mut sel = self.item_sel;
        let r = pull_down(self, x, y, 13, &ITEM_ITEMS, &mut sel, &[], &[(INS, 1), (DEL, 3)]);
        self.item_sel = sel;
        self.ui.close_dialog();
        match r {
            Some(1 | 2 | 4) if !self.fits_dialogs() => {}
            Some(1) => {
                if let Some(s) = self.select_program() {
                    *self.item_mut(g, it) = Item::for_program(&s);
                    self.edit_item(g, it);
                    self.save_menu();
                }
            }
            Some(2) => {
                if self.edit_item(g, it) {
                    self.save_menu()
                }
            }
            Some(3) => self.delete_entry(),
            Some(4) => self.swap_entry(g, it),
            Some(5) => {
                if let Some(ch) = self.frame_menu(x - 1, y) {
                    *self.item_mut(g, it) = Item { name: ch.to_string().repeat(18), prog: String::new(), chdir: true, wait: false };
                    self.save_menu();
                }
            }
            Some(6) => return true,
            _ => {}
        }
        false
    }

    /// "Exchange": choose the target button with the cursor or mouse.
    fn swap_entry(&mut self, g: i32, it: i32) {
        self.ui.open_dialog();
        let (x, y) = (self.xpos[it as usize], self.ypos[it as usize]);
        let name = self.item(it).name.clone();
        let (boxed, nw) = (self.lay.boxed, self.lay.name_w);
        self.btn[it as usize].init(&mut self.ui, true, boxed, x, y, 14, 14, 2, 3, 1, &caption(&name, nw));
        self.ui.window(1, 1, 80, 25);
        self.ui.goto_xy(1, 1);
        self.ui.set_color(14, 3);
        self.ui.clr_eol();
        self.ui.write(&format!("    Exchange entry '{name}': click the target button"));
        let r = self.ui.rows();
        self.ui.window(5, 3, self.lay.w, r);
        let mut target = it;
        let mut ok = false;
        loop {
            let key = self.ui.get_key();
            let mv = |t: i32| -> Option<i32> {
                match key {
                    DOWN if t < 21 => Some(t + 1),
                    UP if t > 1 => Some(t - 1),
                    RIGHT if t < 15 => Some(t + 7),
                    LEFT if t > 7 => Some(t - 7),
                    _ => None,
                }
            };
            if let Some(n) = mv(target) {
                self.btn[target as usize].set_focus(&mut self.ui, false);
                target = n;
                self.btn[target as usize].set_focus(&mut self.ui, true);
            }
            for j in 1..=ITEMS {
                if self.btn[j].clicked(&mut self.ui) {
                    target = j as i32;
                    ok = true;
                }
                if self.btn[j].focused {
                    target = j as i32;
                    for k in 1..=ITEMS {
                        if k != j {
                            self.btn[k].set_focus(&mut self.ui, false);
                        }
                    }
                }
            }
            if self.ui.is_cancel(key) {
                break;
            }
            if key == ENTER {
                ok = true;
            }
            if ok {
                break;
            }
        }
        if ok && it != target {
            let gi = g as usize - 1;
            self.menu.groups[gi].items.swap(it as usize - 1, target as usize - 1);
            self.cur = target;
            self.save_menu();
        }
        self.ui.pop_screen();
    }

    /// The editing dialogs are laid out for 80x25 and would be cut off in a smaller terminal: says so on the
    /// bottom line and returns false until the terminal is big enough.
    pub fn fits_dialogs(&mut self) -> bool {
        let (tw, th) = self.term_size;
        if tw >= 80 && th >= 25 {
            return true;
        }
        let (w, r) = (self.lay.w, self.lay.h);
        let win = self.ui.save_win();
        self.ui.window(1, 1, w, r);
        let line = self.ui.save_rect(1, r, w, r);
        self.ui.write_center_xyfb(1, r, w, 14, 4, &format!("Needs an 80x25 terminal (now {tw}x{th})"));
        self.ui.wait_release();
        while self.ui.get_key() == 0 && self.ui.mouse.button == 0 {}
        self.ui.wait_release();
        self.ui.restore_rect(1, r, w, r, &line);
        self.ui.restore_win(&win);
        false
    }

    /// Matches the logical screen to the terminal and recomputes the button positions.
    fn fit(&mut self) {
        let (tw, th) = self.ui.term_size();
        self.term_size = (tw, th);
        self.lay = Layout::new(tw, th);
        if (self.lay.w, self.lay.h) != (self.ui.cols(), self.ui.rows()) {
            self.ui.resize(self.lay.w, self.lay.h);
        }
        self.bar.admin_x = self.lay.admin_x();
        for i in 1..=ITEMS {
            (self.xpos[i], self.ypos[i]) = self.lay.pos(i);
        }
    }

    /// Draws the whole main screen: group bar, hint line, frame and the buttons of the current group.
    fn draw_main(&mut self) {
        let (w, r) = (self.lay.w, self.lay.h);
        self.ui.window(1, 1, w, r);
        self.ui.set_color(4, 7);
        self.ui.clr_scr();
        let m = self.menu.clone();
        self.bar.redraw(&mut self.ui, &m);
        let ui = &mut self.ui;
        ui.goto_xy(1, r);
        ui.set_color(0, 3);
        ui.clr_eol();
        ui.write_xy_b(3, r, b"\x11\x11 \x10\x10");
        for (x, t) in self.lay.hints() {
            ui.write_xy(x, r, t);
        }
        ui.write_xy_b(w - 6, r, b"F9 \x18\x18");
        for i in 2..r {
            ui.write_xy(1, i, "  ");
            ui.write_xy(w - 1, i, "  ");
        }
        for i in 1..=7 {
            ui.goto_xy(1, self.lay.text_row(i));
            ui.write(&format!("F{i}"));
        }
        let (fw, fh) = self.lay.frame();
        ui.frame(4, 2, fw, fh, 15, 7, true, false);
        ui.window(5, 3, w, r);
        if !(1..=21).contains(&self.cur) {
            self.cur = 1;
        }
        self.show_group();
    }

    /// MainMenu. Returns the command to start, or None to quit.
    pub fn main_menu(&mut self) -> Option<Item> {
        self.last_group = 0;
        self.fit();
        self.ui.open_dialog();
        let mut click = false;
        self.ui.date_off();
        self.ui.clock_off();
        let (w, r) = (self.lay.w, self.lay.h);
        self.ui.window(1, 1, w, r);
        self.ui.set_color(4, 7);
        self.ui.clr_scr();
        let mut empty = false;
        match Menu::load(&self.menu_path) {
            Ok(m) if !m.groups.is_empty() => self.menu = m,
            _ => {
                self.menu = Menu::default();
                self.ui.error_box("There is no menu file or group yet,", "so first a group has to be added!");
                empty = true;
            }
        }
        let m = self.menu.clone();
        self.bar.redraw(&mut self.ui, &m);
        if empty {
            if self.add_group() {
                self.save_menu();
            } else {
                self.ui.pop_screen();
                self.ui.wait_release();
                return None;
            }
        }
        self.draw_main();
        let result;
        loop {
            let mut key = self.ui.get_key();
            if self.ui.saver_due {
                self.screen_saver();
            }
            if self.ui.term_size() != self.term_size {
                self.fit();
                self.last_group = self.cur_group;
                self.draw_main();
            }
            let mut any = false;
            for i in 1..=ITEMS {
                let hit = self.btn[i].clicked(&mut self.ui);
                any |= hit;
                if hit {
                    self.cur = i as i32;
                }
                if self.btn[i].focused {
                    self.cur = i as i32;
                    for k in 1..=ITEMS {
                        if k != i {
                            self.btn[k].set_focus(&mut self.ui, false);
                        }
                    }
                }
            }
            let rows = self.ui.rows();
            let m = self.ui.mouse;
            if m.button == 1 && m.y == rows {
                if m.x == 3 || m.x == 4 {
                    key = self.arrow_click(rows, 2, 4, b"\x11\x11\xC4", b" \x11\x11", PGUP);
                } else if m.x == 6 || m.x == 7 {
                    key = self.arrow_click(rows, 6, 8, b"\xC4\x10\x10", b"\x10\x10 ", PGDN);
                }
            }
            for i in 1..self.bar.count() {
                if key != 0 && key < 256 && dxtui::lo_case(char::from(key as u8)) as u16 == self.bar.items[i].key {
                    self.cur_group = i as i32;
                }
            }
            if key == admin_key() || key == F9 {
                key = self.admin();
            }
            if key == DEL {
                self.delete_entry();
            }
            let m = self.ui.mouse;
            if m.button == 1 && m.y == 1 {
                for i in 0..self.bar.count() {
                    let l = &self.bar.items[i];
                    if l.x - 1 <= m.x && l.x + l.text.chars().count() as i32 > m.x && i as i32 != self.cur_group {
                        if i == 0 {
                            key = self.admin();
                        } else {
                            self.cur_group = i as i32;
                        }
                        break;
                    }
                }
            }
            match key {
                HOME => self.cur = 1,
                END => self.cur = 21,
                RIGHT => self.cur += 7,
                LEFT => self.cur -= 7,
                UP => self.cur -= 1,
                DOWN => self.cur += 1,
                PGDN | TAB => self.cur_group += 1,
                PGUP => self.cur_group -= 1,
                k if (F1..F1 + 7).contains(&k) => self.cur = (k - F1 + 1) as i32,
                k if (ALT_F1..ALT_F1 + 7).contains(&k) => self.cur = (k - ALT_F1 + 8) as i32,
                k if (CTRL_F1..CTRL_F1 + 7).contains(&k) => self.cur = (k - CTRL_F1 + 15) as i32,
                INS if self.fits_dialogs() => {
                    if let Some(s) = self.select_program() {
                        let (g, c) = (self.cur_group, self.cur);
                        *self.item_mut(g, c) = Item::for_program(&s);
                        self.edit_item(g, c);
                        self.save_menu();
                        self.show_group();
                    }
                }
                _ => {}
            }
            if self.cur > 21 {
                self.cur -= 21;
                self.cur_group += 1;
            }
            if self.cur < 1 {
                self.cur += 21;
                self.cur_group -= 1;
            }
            if self.last_group != self.cur_group {
                self.show_group();
            }
            self.last_group = self.cur_group;
            if key != 0 {
                let c = self.cur as usize;
                self.btn[c].set_focus(&mut self.ui, true);
                for i in 1..=ITEMS {
                    if i != c {
                        self.btn[i].set_focus(&mut self.ui, false);
                    }
                }
                if click {
                    self.ui.wait_release();
                }
                click = false;
            }
            let m = self.ui.mouse;
            let (mut mx, mut my) = (m.x, m.y);
            let on_button = if m.button == 2 { self.lay.button_at(mx, my) } else { None };
            // Ctrl-Enter (the original: Ctrl-Return = key 10) opens the entry menu of the current button.
            if key == 10 || on_button.is_some() {
                let mut new_cur = on_button.map_or(self.cur, |i| i as i32);
                if key == 10 {
                    new_cur = self.cur;
                    my = self.lay.text_row(new_cur as usize);
                    mx = self.lay.text_cols(new_cur as usize).0 + 1;
                }
                self.cur = new_cur;
                self.show_group();
                let g = self.cur_group;
                self.ui.wait_release();
                if self.item_menu(g, new_cur, mx, my) {
                    key = F10;
                }
                self.show_group();
            }
            let quit = key == ESC || key == F10;
            let run_key = key == ENTER
                || (F1..F1 + 7).contains(&key)
                || (ALT_F1..ALT_F1 + 7).contains(&key)
                || (CTRL_F1..CTRL_F1 + 7).contains(&key)
                || any;
            if run_key && !self.item(self.cur).prog.is_empty() {
                result = Some(self.item(self.cur).clone());
                break;
            }
            if quit {
                result = None;
                break;
            }
        }
        self.ui.clock_on();
        self.ui.date_on();
        self.ui.pop_screen();
        self.ui.wait_release();
        result
    }

    /// The << and >> arrows in the bottom line: pressed look while held; returns `key` when released on them.
    fn arrow_click(&mut self, rows: i32, x1: i32, x2: i32, down: &[u8], up: &[u8], key: u16) -> u16 {
        let w = self.ui.save_win();
        self.ui.set_color(14, 3);
        self.ui.write_xy_b(x1, rows, down);
        loop {
            let m = self.ui.mouse;
            if m.button == 0 || m.y != rows || m.x < x1 || m.x > x2 || self.ui.term.is_none() {
                break;
            }
            self.ui.pump();
        }
        self.ui.set_color(0, 3);
        self.ui.write_xy_b(x1, rows, up);
        let m = self.ui.mouse;
        self.ui.restore_win(&w);
        if m.x >= x1 && m.x <= x2 && m.y == rows { key } else { 0 }
    }
}
