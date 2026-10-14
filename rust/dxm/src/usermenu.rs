//! Menu administration dialogs. Spec: src/dxm/USERMENU.PAS (GroupDialog, SortGroups, AddGroup, EditItem,
//! EditGroup with AddItems and DeleteItem, SortItems).

use crate::menu::{Group, Item, ITEMS, MAX_GROUPS, NAME_LEN, PROG_LEN};
use crate::Dxm;
use dxtui::button::{Button, Buttons};
use dxtui::keys::*;
use dxtui::list::List;
use dxtui::pad_right;

/// Shorten: long paths keep their first 3 characters and their end.
pub fn shorten(s: &str, n: usize) -> String {
    let c: Vec<char> = s.chars().collect();
    let l = c.len();
    if l > n {
        let tail: String = c[l + 6 - n..].iter().collect();
        format!("{}...{tail}", c[..3].iter().collect::<String>())
    } else {
        s.to_string()
    }
}

/// Sentinel keys for "focus the name field" / "focus the program field" (Alt-N / Alt-P).
fn k_name() -> u16 {
    alt_letter('n').unwrap()
}

fn k_prog() -> u16 {
    alt_letter('p').unwrap()
}

fn letter(k: u16) -> Option<char> {
    dxtui::Key::new(k).char().map(dxtui::lo_case)
}

impl Dxm {
    /// GroupDialog: mode 1 deletes, mode 2 renames groups chosen from a list.
    pub fn group_dialog(&mut self, mode: u8) -> bool {
        let w = 26;
        let mut changed = false;
        self.ui.open_dialog();
        self.ui.frame(25, 3, w, 1, 11, 3, false, true);
        let title = if mode == 1 { " Delete group" } else { " Rename group" };
        self.ui.write(&dxtui::center(title, w - 1));
        self.ui.frame(25, 6, w, 15, 11, 3, false, true);
        let count = self.menu.groups.len() as i32;
        let snapshot = self.menu.clone();
        let lines = |n: i32| format!(" {}", snapshot.groups[n as usize - 1].name);
        let mut list = List::new(&mut self.ui, 0, 3, 14, 1, 26, 7, 15, count, w, false, &lines);
        loop {
            let mut key = self.ui.get_key();
            let menu = self.menu.clone();
            let lines = |n: i32| format!(" {}", menu.groups[n as usize - 1].name);
            list.handle(&mut self.ui, &mut key, &lines);
            let m = self.ui.mouse;
            if list.cur == m.y - 6 && m.button == 1 && self.ui.double_click(m.x, m.y) {
                key = ENTER;
            }
            if key == ENTER {
                let n = list.pos();
                if mode == 1 {
                    changed |= self.delete_group(&mut list, n);
                } else {
                    changed |= self.rename_group(&mut list, n, w);
                }
            }
            if self.ui.is_cancel(key) || self.ui.mouse_outside(25, 55, 3, 22) {
                break;
            }
        }
        self.ui.pop_screen();
        let m = self.menu.clone();
        self.bar.redraw(&mut self.ui, &m);
        changed
    }

    fn delete_group(&mut self, list: &mut List, n: i32) -> bool {
        let count = self.menu.groups.len() as i32;
        if n > count || count < 1 {
            return false;
        }
        if count == 1 {
            self.ui.msg_box("Delete group:", "The last group cannot be deleted!");
            return false;
        }
        let mut y = list.cur + 7;
        if y > 16 {
            y -= 8;
        }
        if !self.confirm_box(16, y, 28, "   Delete this group?", false, 15, 5, false) {
            return false;
        }
        self.menu.groups.remove(n as usize - 1);
        if list.pos() == count {
            if list.cur > 1 {
                list.cur -= 1
            } else {
                list.top -= 1
            }
        }
        let menu = self.menu.clone();
        let lines = |n: i32| format!(" {}", menu.groups[n as usize - 1].name);
        let (c, t) = (list.cur, list.top);
        list.set_data(&mut self.ui, count - 1, 15, c, t, &lines);
        true
    }

    fn rename_group(&mut self, list: &mut List, n: i32, w: i32) -> bool {
        if n > self.menu.groups.len() as i32 {
            return false;
        }
        let mut changed = false;
        self.ui.open_dialog();
        self.ui.frame(25, list.cur + 4, w, 3, 15, 5, false, true);
        let mut s = self.menu.groups[n as usize - 1].name.clone();
        let k = self.ui.input_line(28, list.cur + 6, 27, 53, &mut s, 20, 20, false);
        if s.ends_with('~') {
            s.pop();
        }
        if k != ESC && !s.is_empty() {
            changed = true;
            self.menu.groups[n as usize - 1].name = s;
        }
        self.ui.pop_screen();
        let menu = self.menu.clone();
        let lines = |n: i32| format!(" {}", menu.groups[n as usize - 1].name);
        list.draw_all(&mut self.ui, &lines);
        changed
    }

    /// SortGroups: move groups with the cursor keys after picking one with Enter.
    pub fn sort_groups(&mut self) -> bool {
        let count = self.menu.groups.len() as i32;
        let mut changed = false;
        if count == 1 {
            self.ui.error_box("Sort groups:", "How am I supposed to sort just one group??");
        }
        if count < 2 {
            return false;
        }
        let mut sel = false;
        let mut cur = 1;
        self.ui.open_dialog();
        self.ui.set_color(0, 5);
        let r = self.ui.rows();
        self.ui.write_xyfb(3, r, 14, 0, &pad_right("       <Return> = Select/Place  <Cursor> = Move  <Esc> = Done", 76));
        self.ui.frame(30, 2, 20, 21, 15, 5, false, false);
        self.ui.write_xy(1, 1, " Sort groups:       ");
        self.ui.write_xy(1, 2, &"─".repeat(20));
        self.ui.window(31, 5, 80, r);
        self.ui.text_color(0);
        self.ui.write_xy(1, 16, &"─".repeat(20));
        let line = |me: &Dxm, n: i32| format!(" {}", pad_right(&me.menu.groups[n as usize - 1].name, 19));
        for i in 2..=count {
            let s = line(self, i);
            self.ui.write_xy(1, i, &s);
        }
        let hi = |me: &mut Dxm, n: i32, sel: bool| {
            let s = line(me, n);
            if sel { me.ui.write_xyfb(1, n, 14, 0, &s) } else { me.ui.write_xyfb(1, n, 0, 2, &s) }
        };
        hi(self, cur, sel);
        let mut b = Button::new(true, 2, 17, 14, 14, 15, 5, "      OK      ");
        b.redraw(&mut self.ui);
        loop {
            let mut key = self.ui.get_key();
            let m = self.ui.mouse;
            let in_list = m.button == 1 && m.x > 30 && m.x < 51 && m.y >= 5 && m.y <= 20;
            if in_list && cur == m.y - 4 && self.ui.double_click(m.x, m.y) {
                key = ENTER;
            }
            let mut goto = None;
            match key {
                UP if cur > 1 => goto = Some(cur - 1),
                DOWN if cur < count => goto = Some(cur + 1),
                ENTER => {
                    sel = !sel;
                    hi(self, cur, sel);
                }
                _ => {}
            }
            let m = self.ui.mouse;
            if m.button == 1 && m.x > 30 && m.x < 51 && m.y >= 5 && m.y <= 20 && m.y - 4 != cur && m.y - 4 <= count {
                goto = Some(m.y - 4);
            }
            if let Some(n) = goto {
                if sel {
                    self.menu.groups.swap(cur as usize - 1, n as usize - 1);
                    changed = true;
                }
                let s = line(self, cur);
                self.ui.write_xy(1, cur, &s);
                cur = n;
                hi(self, cur, sel);
            }
            if self.ui.mouse_outside(30, 51, 3, 24) {
                key = F10;
            }
            if self.ui.is_cancel(key) || b.mouse_button(&mut self.ui) {
                break;
            }
        }
        self.ui.pop_screen();
        let m = self.menu.clone();
        self.bar.redraw(&mut self.ui, &m);
        changed
    }

    /// AddGroup: asks for the name of a new group and appends it.
    pub fn add_group(&mut self) -> bool {
        if self.bar.count() > MAX_GROUPS {
            self.ui.error_box("At most 15 groups are possible!", "No more entries can be added!");
            return false;
        }
        if self.bar.count() > 2 && self.bar.end() > 65 {
            self.ui.error_box("There is no room left!", "No further entry is possible!");
            return false;
        }
        self.ui.open_dialog();
        self.ui.frame(13, 6, 53, 10, 11, 3, false, true);
        self.ui.write_center_xy(1, 1, 53, "Add a new group:");
        self.ui.write_xy(6, 3, "  New group:");
        self.ui.write_xyf(8, 3, 14, "N");
        self.ui.write_xy(1, 5, "    A tilde before a letter makes it the hotkey!");
        let eg = "  E.g. entering \"~Test\" shows in the menu ==> Test";
        self.ui.write_xy(1, 6, eg);
        self.ui.write_xyf(eg.len() as i32 - 3, 6, 4, "T");
        let r = self.ui.rows();
        self.ui.window(1, 1, 80, r);
        let mut b = Buttons::new(&mut self.ui, true, &[(16, 14), (42, 14)], 14, 0, 11, 3,
            &["         OK         ", "      Cancel       "]);
        let mut s = String::new();
        let mut key = k_name();
        let ok = loop {
            if key == k_name() || letter(key) == Some('n') || key == UP || key == SHIFT_TAB || key == TAB
                || self.ui.mouse_on(9, 37, 58)
            {
                b.reset(&mut self.ui);
                let k = self.ui.input_line(38, 9, 32, 66, &mut s, 20, 20, false);
                b.restore(&mut self.ui);
                if k == ESC {
                    break false;
                }
                if k == ENTER {
                    break true;
                }
            }
            match b.handle(&mut self.ui, &mut key) {
                Some(0) => break true,
                Some(1) => break false,
                _ => {}
            }
            if self.ui.mouse_outside(13, 67, 6, 17) || self.ui.is_cancel(key) {
                break false;
            }
        };
        self.ui.pop_screen();
        if !ok || s.is_empty() {
            return false;
        }
        if self.bar.count() > 2 && self.bar.end() + s.chars().count() as i32 > 66 {
            self.ui.error_box("There is no room left!", "The menu item was shortened or dropped!");
            let n = (66 - self.bar.end()).max(0) as usize;
            s = s.chars().take(n).collect();
        }
        if s.ends_with('~') {
            s.pop();
        }
        if s.is_empty() {
            return false;
        }
        self.menu.groups.push(Group::new(&s));
        self.cur_group = self.menu.groups.len() as i32;
        let m = self.menu.clone();
        self.bar.redraw(&mut self.ui, &m);
        true
    }

    /// EditItem: name, command and "change directory" of entry `i` in group `g`.
    pub fn edit_item(&mut self, g: i32, i: i32) -> bool {
        self.ui.open_dialog();
        let it = self.item_mut(g, i).clone();
        let (mut name, mut prog, mut flag) = (it.name, it.prog, it.chdir);
        self.ui.frame(21, 6, 50, 10, 11, 6, false, true);
        self.ui.write_xyf(4, 3, 14, "N");
        self.ui.write_f(11, "ame");
        self.ui.write_xyf(4, 6, 14, "P");
        self.ui.write_f(11, "rogram");
        self.ui.input_line(25, 11, 19, 60, &mut prog, 42, 0, false);
        self.ui.write_xyf(47, 8, 11, "[ ] ");
        self.ui.write_f(14, "D");
        self.ui.write_f(11, "irectory change");
        self.ui.write_xyf(48, 8, 11, if flag { "X" } else { " " });
        let mut b = Buttons::new(&mut self.ui, true, &[(23, 14), (48, 14)], 14, 0, 11, 6,
            &["         OK         ", "      Cancel       "]);
        let mut key = k_name();
        self.ui.wait_release();
        let ok = 'outer: loop {
            b.reset(&mut self.ui);
            let mut field = if key == k_name() { 1 } else if key == k_prog() { 2 } else { 0 };
            while field != 0 {
                let k = if field == 1 {
                    self.ui.input_line(25, 8, 24, 45, &mut name, 18, NAME_LEN as i32, false)
                } else {
                    self.ui.input_line(25, 11, 24, 69, &mut prog, 42, PROG_LEN as i32, false)
                };
                field = match (field, k) {
                    (_, ESC) => break 'outer false,
                    (1, TAB) => 2,
                    (2, SHIFT_TAB) => 1,
                    _ => 0,
                };
            }
            b.restore(&mut self.ui);
            let res = loop {
                let hit = b.handle(&mut self.ui, &mut key);
                let c = letter(key);
                if key == TAB || key == DOWN || c == Some('n') || self.ui.mouse_on(8, 25, 44) {
                    key = k_name();
                }
                if self.ui.mouse_on(11, 25, 68) || c == Some('p') || key == SHIFT_TAB || key == UP {
                    key = k_prog();
                }
                let mut r = match hit {
                    Some(0) => Some(true),
                    Some(1) => Some(false),
                    _ => None,
                };
                if c == Some('o') {
                    r = Some(true);
                }
                if c == Some('c') {
                    r = Some(false);
                }
                if key == alt_letter('d').unwrap() || c == Some('d') || self.ui.mouse_on(8, 47, 68) {
                    flag = !flag;
                    self.ui.write_xyf(48, 8, 11, if flag { "X" } else { " " });
                    self.ui.wait_release();
                }
                if self.ui.is_cancel(key) || self.ui.mouse_outside(21, 73, 6, 17) {
                    r = Some(false);
                }
                if r.is_some() || key == k_name() || key == k_prog() {
                    break r;
                }
            };
            match res {
                Some(true) if name.is_empty() && prog.is_empty() => break false,
                Some(r) => break r,
                None => {}
            }
        };
        if ok {
            *self.item_mut(g, i) = Item { name, prog, chdir: flag };
            self.ui.pop_screen();
        } else {
            self.ui.close_dialog();
        }
        ok
    }

    fn item_line(&self, n: i32) -> String {
        let num = format!("{n:2}.");
        let it = &self.menu.groups[self.cur_group as usize - 1].items[n as usize - 1];
        let head: String = pad_right(&format!(" {num}{}", it.name), 23);
        head + &shorten(&it.prog, 42)
    }

    /// EditGroup: the full-screen list of a group's entries with Insert/Change/Delete/Done.
    pub fn edit_group(&mut self, g: i32, start: i32) -> bool {
        self.ui.open_dialog();
        let old_dir = std::env::current_dir().ok();
        let mut changed = false;
        self.ui.set_color(0, 7);
        self.ui.frame(4, 2, 72, 21, 15, 7, false, false);
        let title = "User menu management  Current group: ";
        self.ui.write_xy(10, 1, title);
        let gname: String = self.menu.groups[g as usize - 1].name.replace('~', "");
        self.ui.write_f(14, &gname);
        self.ui.write_xy_b(10, 2, &vec![0xDD; title.len() + gname.chars().count()]);
        self.ui.write_xy(3, 3, "User entries:");
        self.ui.write_xy(26, 3, "Program:");
        self.ui.frame(6, 6, 68, 13, 15, 7, false, false);
        let snap = self.clone_lines();
        let lines = |n: i32| snap[n as usize - 1].clone();
        let mut list = List::new(&mut self.ui, 0, 7, 0, 2, 7, 7, 13, ITEMS as i32, 67, true, &lines);
        list.set_pos(&mut self.ui, start, 7, &lines);
        let w = self.ui.save_win();
        let mut b = Buttons::new(&mut self.ui, true, &[(6, 21), (25, 21), (44, 21), (62, 21)], 14, 0, 15, 7,
            &["    Insert    ", "    Change    ", "   Delete    ", "   Done   "]);
        self.ui.restore_win(&w);
        let mut key = 0;
        loop {
            let snap = self.clone_lines();
            let lines = |n: i32| snap[n as usize - 1].clone();
            list.handle(&mut self.ui, &mut key, &lines);
            let mut act = if key == ENTER {
                (0..4).find(|&i| b[i].focused)
            } else {
                let w = self.ui.save_win();
                let a = b.handle(&mut self.ui, &mut key);
                self.ui.restore_win(&w);
                a
            };
            match letter(key) {
                Some('i') => act = Some(0),
                Some('c') => act = Some(1),
                Some('d') => act = Some(2),
                Some('o') => act = Some(3),
                _ => {}
            }
            if key == INS {
                act = Some(0);
            }
            match act {
                Some(0) => {
                    changed |= self.add_items(g, list.pos(), &mut list);
                    key = 0;
                }
                Some(1) => {
                    key = 0;
                    if self.edit_item(g, list.pos()) {
                        let snap = self.clone_lines();
                        let lines = |n: i32| snap[n as usize - 1].clone();
                        list.draw_all(&mut self.ui, &lines);
                        changed = true;
                    }
                }
                Some(2) => {
                    key = 0;
                    changed |= self.delete_item(g, &mut list);
                }
                _ => {}
            }
            if key == F1 {
                crate::help::show_help(&mut self.ui, &self.home, 14);
            }
            if act == Some(3) || self.ui.mouse_outside(3, 78, 2, 24) || self.ui.is_cancel(key) {
                break;
            }
        }
        self.ui.close_dialog();
        if let Some(d) = old_dir {
            let _ = std::env::set_current_dir(d);
        }
        changed
    }

    fn clone_lines(&self) -> Vec<String> {
        (1..=ITEMS as i32).map(|n| self.item_line(n)).collect()
    }

    fn refresh_list(&mut self, list: &mut List) {
        let snap = self.clone_lines();
        let lines = |n: i32| snap[n as usize - 1].clone();
        let (c, t) = (list.cur, list.top);
        list.set_data(&mut self.ui, ITEMS as i32, 13, c, t, &lines);
    }

    fn delete_item(&mut self, g: i32, list: &mut List) -> bool {
        let mut y = list.cur + 7;
        if y > 16 {
            y -= 7;
        }
        if !self.confirm_box(16, y, 29, "   Delete this entry?", false, 11, 6, true) {
            return false;
        }
        let p = list.pos();
        let it = self.item_mut(g, p);
        it.name.clear();
        it.prog.clear();
        self.refresh_list(list);
        true
    }

    /// AddItems: browse for programs and set or insert them at entry `n`, repeatedly.
    fn add_items(&mut self, g: i32, n: i32, list: &mut List) -> bool {
        let mut toggle = true;
        let mut chg = false;
        self.ui.open_dialog();
        let r = self.ui.rows();
        self.ui.window(1, 1, 80, r);
        let mut b = Buttons::new(&mut self.ui, true, &[(6, 21), (31, 21), (54, 21)], 14, 0, 2, 7,
            &["       Insert       ", "      Drive       ", "       Done       "]);
        self.ui.write_xy(7, 5, &pad_right("Current directory:", 39));
        self.ui.frame(6, 6, 25, 13, 11, 1, false, false);
        self.ui.set_color(11, 1);
        for l in [
            "       Insert:", "", "  Please choose the", "  program to add", "", " =====================>", "",
            "  Shown are programs", "  and scripts.", "", "  Change drive also", "   with Alt-F1/Alt-F2",
        ] {
            self.ui.write(l);
            self.ui.write("\r\n");
        }
        self.ui.write_xy_b(8, 2, &[0xDD; 7]);
        self.ui.window(1, 1, 80, 25);
        for i in 6..=20 {
            self.ui.write_xyb(33, i, 1, " ");
        }
        self.ui.frame(34, 6, 40, 13, 11, 1, false, false);
        let mut br = crate::browser::Browser::new(&mut self.ui, 11, 1, 0, 3, 35, 5, 13, 7);
        while let Some(file) = br.execute(&mut self.ui, Some(&mut b)) {
            b.reset(&mut self.ui);
            self.ui.open_dialog();
            let mut name = crate::menu::default_name(&file);
            self.ui.frame(13, 7, 54, 11, 11, 3, false, true);
            self.ui.write_center_xy(1, 1, 54, "Set or insert the file");
            self.ui.write_center_xyf(1, 3, 54, 14, &shorten(&file, 52));
            self.ui.write_center_xy(1, 5, 54, &format!("into the user menu at position {n} under the"));
            self.ui.write_xyf(3, 7, 14, "N");
            self.ui.write("ame:");
            self.ui.input_line(23, 14, 30, 61, &mut name, 18, 0, false);
            let mut b2 = Buttons::new(&mut self.ui, true, &[(16, 16), (33, 16), (49, 16)], 14, 0, 11, 3,
                &["   Insert   ", "    Set    ", "   Cancel    "]);
            self.ui.write_xy(44, 14, if toggle { "[X] " } else { "[ ] " });
            self.ui.write_f(14, "D");
            self.ui.write("irectory change");
            let mut key = UP;
            let act = loop {
                if key == UP || key == SHIFT_TAB || key == TAB || key == k_name() || letter(key) == Some('n')
                    || self.ui.mouse_on(14, 23, 42)
                {
                    b2.reset(&mut self.ui);
                    let k = self.ui.input_line(23, 14, 7, 30, &mut name, 18, 18, false);
                    b2.restore(&mut self.ui);
                    if k == ESC {
                        break 2;
                    }
                }
                let mut act = b2.handle(&mut self.ui, &mut key);
                if key == alt_letter('d').unwrap() || letter(key) == Some('d') || self.ui.mouse_on(14, 44, 65) {
                    toggle = !toggle;
                    self.ui.write_xy(45, 14, if toggle { "X" } else { " " });
                    self.ui.wait_release();
                }
                if self.ui.is_cancel(key) || self.ui.mouse_outside(13, 68, 7, 19) {
                    act = Some(2);
                }
                if act == Some(0) && !self.item_mut(g, ITEMS as i32).is_empty() {
                    self.ui.error_box("Inserting is not possible any more!", "The last entry would be lost.");
                    act = None;
                }
                if let Some(a) = act {
                    break a;
                }
            };
            self.ui.close_dialog();
            b.restore(&mut self.ui);
            let it = Item { name: name.clone(), prog: file.clone(), chdir: toggle };
            match act {
                1 => {
                    *self.item_mut(g, n) = it;
                    chg = true;
                }
                0 => {
                    let items = &mut self.menu.groups[g as usize - 1].items;
                    items.pop();
                    items.insert(n as usize - 1, it);
                    chg = true;
                }
                _ => {}
            }
        }
        self.ui.pop_screen();
        if chg {
            self.refresh_list(list);
        }
        self.ui.wait_release();
        chg
    }

    /// SortItems: move entries of group `g` like SortGroups, with the F-key columns drawn at the left.
    pub fn sort_items(&mut self, g: i32) {
        let mut sel = false;
        self.ui.open_dialog();
        self.ui.set_color(14, 0);
        self.ui.write_xy(30, 1, "        Sort:         ");
        self.ui.frame(12, 1, 56, 23, 15, 5, false, false);
        for (y, t) in [(15, "<Esc>"), (16, "Done"), (18, "<Cursor>"), (19, "Move"), (21, "<Return>"), (22, "Select/Place")] {
            self.ui.write_xy(41, y, t);
        }
        for (y0, label, lx) in [(2, "F1..F7 ┤", 10), (9, "Alt-F1..F7 ┤", 6), (16, "Ctrl-F1..F7 ┤", 5)] {
            self.ui.write_xy(17, y0, "┌");
            for i in y0 + 1..y0 + 6 {
                self.ui.write_xy(17, i, "│");
            }
            self.ui.write_xy(17, y0 + 6, "└");
            self.ui.write_xy(lx, y0 + 3, label);
        }
        self.ui.frame(30, 2, 20, 21, 15, 7, true, false);
        let r = self.ui.rows();
        self.ui.window(31, 3, 80, r);
        let line = |me: &Dxm, n: i32| {
            format!(" {}", pad_right(&me.menu.groups[g as usize - 1].items[n as usize - 1].name, 19))
        };
        for i in 1..=ITEMS as i32 {
            let n = self.menu.groups[g as usize - 1].items[i as usize - 1].name.clone();
            self.ui.write_xy(2, i, &n);
        }
        let hi = |me: &mut Dxm, n: i32, sel: bool| {
            let s = line(me, n);
            if sel { me.ui.write_xyfb(1, n, 14, 0, &s) } else { me.ui.write_xyfb(1, n, 0, 2, &s) }
        };
        hi(self, 1, sel);
        let mut cur = 1;
        loop {
            let mut key = self.ui.get_key();
            let m = self.ui.mouse;
            let in_list = m.button == 1 && m.x > 30 && m.x < 51 && m.y >= 3 && m.y <= 23;
            if in_list && cur == m.y - 2 && self.ui.double_click(m.x, m.y) {
                key = ENTER;
            }
            let mut goto = None;
            match key {
                UP if cur > 1 => goto = Some(cur - 1),
                DOWN if cur < ITEMS as i32 => goto = Some(cur + 1),
                ENTER => {
                    sel = !sel;
                    hi(self, cur, sel);
                }
                _ => {}
            }
            let m = self.ui.mouse;
            if m.button == 1 && m.x > 30 && m.x < 51 && m.y >= 3 && m.y <= 23 && m.y - 2 != cur {
                goto = Some(m.y - 2);
            }
            if let Some(n) = goto {
                if sel {
                    self.menu.groups[g as usize - 1].items.swap(cur as usize - 1, n as usize - 1);
                }
                let s = line(self, cur);
                self.ui.write_xy(1, cur, &s);
                cur = n;
                hi(self, cur, sel);
            }
            if self.ui.is_cancel(key) {
                break;
            }
        }
        self.ui.pop_screen();
    }
}
