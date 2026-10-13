//! Menu state and input handling. Spec: src/dxm/DXMENU.PAS (MainMenu, AdminMenu, ItemMenu, FrameMenu,
//! DeleteEntry) and USERMENU.PAS (group/entry dialogs). Drawing lives in ui.rs.

use crate::config::MenuPos;
use crate::menu::{locase, upcase, Item, Menu, MenuError, ITEMS};
use crate::picker::Picker;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers, MouseButton, MouseEvent, MouseEventKind};
use std::path::PathBuf;

pub const ROWS: usize = 7;

/// Admin menu ("Verwaltung"); `None` rows are headings/separators.
pub const ADMIN: [Option<(&str, char)>; 11] = [
    None,
    Some((" Neu           ", 'n')),
    Some((" Löschen       ", 'l')),
    Some((" Sortieren     ", 's')),
    Some((" Umbenennen    ", 'u')),
    None,
    Some((" Löschen       ", 'ö')),
    Some((" Sortieren     ", 'o')),
    Some((" Bearbeiten    ", 'e')),
    None,
    Some((" Beenden    Esc", 'b')),
];
pub const ADMIN_HEADINGS: [&str; 11] =
    ["══ Gruppen ════", "", "", "", "", "══ Einträge ═══", "", "", "", "───────────────", ""];

pub const ITEM_MENU: [(&str, char); 6] = [
    (" Neu         ", 'n'),
    (" Ändern      ", 'ä'),
    (" Löschen     ", 'l'),
    (" Vertauschen ", 'v'),
    (" Trenner     ", 't'),
    (" Beenden     ", 'b'),
];

pub const SEPARATORS: [char; 6] = ['─', '*', '~', '█', '.', '-'];

/// A text field with a cursor (DIALOGS.PAS InputLine).
#[derive(Clone, Debug, Default)]
pub struct Field {
    pub text: String,
    pub pos: usize,
    pub max: usize,
}

impl Field {
    pub fn new(text: &str, max: usize) -> Field {
        Field { text: text.to_string(), pos: text.chars().count(), max }
    }

    fn byte(&self, pos: usize) -> usize {
        self.text.char_indices().nth(pos).map_or(self.text.len(), |(i, _)| i)
    }

    /// Returns false for keys the field doesn't use.
    pub fn key(&mut self, k: KeyEvent) -> bool {
        let len = self.text.chars().count();
        match k.code {
            KeyCode::Char(c) if !k.modifiers.intersects(KeyModifiers::CONTROL | KeyModifiers::ALT) => {
                if len < self.max {
                    let b = self.byte(self.pos);
                    self.text.insert(b, c);
                    self.pos += 1;
                }
            }
            KeyCode::Backspace if self.pos > 0 => {
                self.pos -= 1;
                let b = self.byte(self.pos);
                self.text.remove(b);
            }
            KeyCode::Delete if self.pos < len => {
                let b = self.byte(self.pos);
                self.text.remove(b);
            }
            KeyCode::Left => self.pos = self.pos.saturating_sub(1),
            KeyCode::Right => self.pos = (self.pos + 1).min(len),
            KeyCode::Home => self.pos = 0,
            KeyCode::End => self.pos = len,
            KeyCode::Backspace | KeyCode::Delete => {}
            _ => return false,
        }
        true
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum GroupListMode {
    Delete,
    Rename,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Delete {
    Entry(usize),
    Group(usize),
}

/// What the file picker is choosing a program for.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum PickFor {
    /// Ins in the main menu / "Neu" in the entry menu: fill the slot, then edit it.
    Slot(usize),
    /// "Einfügen" in the entry editor: ask for a name, then insert or overwrite.
    Edit(usize),
}

pub enum Popup {
    Message(String, String),
    Admin { sel: usize },
    ItemMenu { item: usize, sel: usize },
    Separator { item: usize, sel: usize },
    Swap { from: usize, target: usize },
    Confirm { what: Delete, text: String, yes: bool },
    AddGroup { field: Field },
    GroupList { mode: GroupListMode, sel: usize },
    RenameGroup { group: usize, field: Field },
    SortGroups { cur: usize, grabbed: bool },
    SortItems { cur: usize, grabbed: bool },
    EditItem { item: usize, name: Field, prog: Field, chdir: bool, focus: usize },
    EditGroup { sel: usize },
    Pick { picker: Picker, purpose: PickFor },
    PlaceFile { item: usize, path: String, name: Field, chdir: bool },
}

pub enum Outcome {
    Quit,
    Run(Item),
}

pub struct App {
    pub menu: Menu,
    pub group: usize,
    pub cur: usize,
    pub popups: Vec<Popup>,
    pub menu_path: PathBuf,
    /// Start directory for the file picker.
    pub pick_dir: PathBuf,
    /// Set when the menu file couldn't be read: the first group must be created before anything else.
    pub needs_group: bool,
    /// Set when the user cancels creating the first group.
    pub quit_now: bool,
    /// Screen positions of the buttons and bar labels from the last draw, for mouse hits.
    pub hit_items: Vec<(ratatui::layout::Rect, usize)>,
    pub hit_bar: Vec<(ratatui::layout::Rect, Option<usize>)>,
}

fn plain_char(k: &KeyEvent) -> Option<char> {
    match k.code {
        KeyCode::Char(c) if !k.modifiers.intersects(KeyModifiers::CONTROL | KeyModifiers::ALT) => Some(locase(c)),
        _ => None,
    }
}

impl App {
    pub fn new(menu: Option<Menu>, pos: MenuPos, menu_path: PathBuf, pick_dir: PathBuf) -> App {
        let needs_group = menu.as_ref().is_none_or(|m| m.groups.is_empty());
        let menu = menu.unwrap_or_default();
        let mut app = App {
            group: pos.group.min(menu.groups.len().saturating_sub(1)),
            cur: pos.item,
            menu,
            popups: vec![],
            menu_path,
            pick_dir,
            needs_group,
            quit_now: false,
            hit_items: vec![],
            hit_bar: vec![],
        };
        if needs_group {
            app.popups.push(Popup::AddGroup { field: Field::new("", 20) });
            app.popups.push(Popup::Message(
                "Wenn noch keine Datei bzw. Gruppe existiert".into(),
                "muß als erstes eine Gruppe eingefügt werden!".into(),
            ));
        }
        app
    }

    pub fn pos(&self) -> MenuPos {
        MenuPos { group: self.group, item: self.cur }
    }

    pub fn item(&self, i: usize) -> &Item {
        &self.menu.groups[self.group].items[i]
    }

    fn item_mut(&mut self, i: usize) -> &mut Item {
        &mut self.menu.groups[self.group].items[i]
    }

    fn save(&mut self) {
        if let Err(e) = self.menu.save(&self.menu_path) {
            self.popups.push(Popup::Message(
                "Fehler beim Schreiben der Menüdatei".into(),
                format!("{}: {e}", self.menu_path.display()),
            ));
        }
    }

    fn error(&mut self, a: &str, b: &str) {
        self.popups.push(Popup::Message(a.into(), b.into()));
    }

    /// Moves the selection by `d` slots; leaving the grid at either end switches group (MainMenu).
    pub fn step(&mut self, d: isize) {
        let n = self.menu.groups.len() as isize;
        let mut cur = self.cur as isize + d;
        let mut g = self.group as isize;
        if cur >= ITEMS as isize {
            cur -= ITEMS as isize;
            g += 1;
        }
        if cur < 0 {
            cur += ITEMS as isize;
            g -= 1;
        }
        self.cur = cur as usize;
        self.group = g.rem_euclid(n) as usize;
    }

    pub fn switch_group(&mut self, d: isize) {
        let n = self.menu.groups.len() as isize;
        self.group = (self.group as isize + d).rem_euclid(n) as usize;
    }

    /// Runs the selected entry, if it has a program.
    fn run(&self, i: usize) -> Option<Outcome> {
        let it = self.item(i);
        it.is_runnable().then(|| Outcome::Run(it.clone()))
    }

    fn picker(&self, purpose: PickFor) -> Popup {
        Popup::Pick { picker: Picker::new(self.pick_dir.clone()), purpose }
    }

    pub fn key(&mut self, k: KeyEvent) -> Option<Outcome> {
        if self.popups.is_empty() {
            self.main_key(k)
        } else {
            self.popup_key(k)
        }
    }

    fn main_key(&mut self, k: KeyEvent) -> Option<Outcome> {
        let alt = k.modifiers.contains(KeyModifiers::ALT);
        let ctrl = k.modifiers.contains(KeyModifiers::CONTROL);
        match k.code {
            // F1..F7 = column 1, Alt = column 2, Ctrl (Strg) = column 3: select and run.
            KeyCode::F(n @ 1..=7) => {
                self.cur = (n as usize - 1) + if alt { ROWS } else if ctrl { 2 * ROWS } else { 0 };
                return self.run(self.cur);
            }
            KeyCode::F(9) => self.popups.push(Popup::Admin { sel: 1 }),
            KeyCode::Char('v') if alt => self.popups.push(Popup::Admin { sel: 1 }),
            KeyCode::Esc | KeyCode::F(10) => return Some(Outcome::Quit),
            KeyCode::Home => self.cur = 0,
            KeyCode::End => self.cur = ITEMS - 1,
            KeyCode::Up => self.step(-1),
            KeyCode::Down => self.step(1),
            KeyCode::Left => self.step(-(ROWS as isize)),
            KeyCode::Right => self.step(ROWS as isize),
            KeyCode::PageDown | KeyCode::Tab => self.switch_group(1),
            KeyCode::PageUp | KeyCode::BackTab => self.switch_group(-1),
            KeyCode::Insert => self.popups.push(self.picker(PickFor::Slot(self.cur))),
            KeyCode::Delete => self.confirm_delete_entry(self.cur),
            // Ctrl-Enter (Ctrl-J) opens the entry menu.
            KeyCode::Enter if ctrl => self.popups.push(Popup::ItemMenu { item: self.cur, sel: 0 }),
            KeyCode::Char('j') if ctrl => self.popups.push(Popup::ItemMenu { item: self.cur, sel: 0 }),
            KeyCode::Enter => return self.run(self.cur),
            KeyCode::Char(c) if !ctrl => {
                let c = locase(c);
                if let Some(g) = self.menu.groups.iter().position(|g| g.hotkey() == Some(c)) {
                    self.group = g;
                }
            }
            _ => {}
        }
        None
    }

    fn confirm_delete_entry(&mut self, i: usize) {
        let name = self.item(i).name.clone();
        if !name.is_empty() {
            self.popups.push(Popup::Confirm {
                what: Delete::Entry(i),
                text: format!("{name} löschen?"),
                yes: true,
            });
        }
    }

    fn popup_key(&mut self, k: KeyEvent) -> Option<Outcome> {
        let mut top = self.popups.pop().unwrap();
        let keep = match &mut top {
            Popup::Message(..) => !matches!(k.code, KeyCode::Enter | KeyCode::Esc | KeyCode::Char(' ')),
            Popup::Admin { sel } => match k.code {
                KeyCode::Down => {
                    *sel = next_admin(*sel, 1);
                    true
                }
                KeyCode::Up => {
                    *sel = next_admin(*sel, -1);
                    true
                }
                KeyCode::Enter => return self.admin(*sel),
                KeyCode::Esc | KeyCode::F(10) | KeyCode::Left => false,
                _ => match plain_char(&k).and_then(|c| ADMIN.iter().position(|e| e.is_some_and(|e| e.1 == c))) {
                    Some(i) => return self.admin(i),
                    None => true,
                },
            },
            Popup::ItemMenu { item, sel } => {
                let item = *item;
                let pick = match k.code {
                    KeyCode::Down => {
                        *sel = (*sel + 1) % ITEM_MENU.len();
                        None
                    }
                    KeyCode::Up => {
                        *sel = (*sel + ITEM_MENU.len() - 1) % ITEM_MENU.len();
                        None
                    }
                    KeyCode::Enter => Some(*sel),
                    KeyCode::Insert => Some(0),
                    KeyCode::Delete => Some(2),
                    KeyCode::Esc | KeyCode::F(10) | KeyCode::Left => {
                        return None;
                    }
                    _ => plain_char(&k).and_then(|c| ITEM_MENU.iter().position(|e| e.1 == c)),
                };
                match pick {
                    None => true,
                    Some(p) => return self.item_menu(item, p),
                }
            }
            Popup::Separator { item, sel } => match k.code {
                KeyCode::Down => {
                    *sel = (*sel + 1) % SEPARATORS.len();
                    true
                }
                KeyCode::Up => {
                    *sel = (*sel + SEPARATORS.len() - 1) % SEPARATORS.len();
                    true
                }
                KeyCode::Enter => {
                    *self.item_mut(*item) = Item::separator(SEPARATORS[*sel]);
                    self.save();
                    false
                }
                KeyCode::Esc | KeyCode::F(10) => false,
                _ => true,
            },
            Popup::Swap { from, target } => match k.code {
                KeyCode::Down if *target < ITEMS - 1 => {
                    *target += 1;
                    true
                }
                KeyCode::Up if *target > 0 => {
                    *target -= 1;
                    true
                }
                KeyCode::Right if *target < 2 * ROWS => {
                    *target += ROWS;
                    true
                }
                KeyCode::Left if *target >= ROWS => {
                    *target -= ROWS;
                    true
                }
                KeyCode::Enter => {
                    let (a, b) = (*from, *target);
                    if a != b {
                        self.menu.groups[self.group].items.swap(a, b);
                        self.cur = b;
                        self.save();
                    }
                    false
                }
                KeyCode::Esc => false,
                _ => true,
            },
            Popup::Confirm { what, yes, .. } => {
                let answer = match k.code {
                    KeyCode::Left | KeyCode::Right | KeyCode::Tab => {
                        *yes = !*yes;
                        None
                    }
                    KeyCode::Enter => Some(*yes),
                    KeyCode::Esc => Some(false),
                    _ => match plain_char(&k) {
                        Some('j') => Some(true),
                        Some('n') => Some(false),
                        _ => None,
                    },
                };
                match answer {
                    None => true,
                    Some(false) => false,
                    Some(true) => {
                        self.confirmed(*what);
                        false
                    }
                }
            }
            Popup::AddGroup { field } => match k.code {
                KeyCode::Enter => {
                    let name = field.text.clone();
                    match self.menu.add_group(&name) {
                        Ok(g) => {
                            self.group = g;
                            self.cur = 0;
                            self.needs_group = false;
                            self.save();
                            false
                        }
                        Err(MenuError::EmptyName) => {
                            self.cancel_add_group();
                            false
                        }
                        Err(_) => {
                            self.error("Es sind maximal 15 Gruppen vorgesehen!", "Mehr Einträge sind nicht möglich!");
                            false
                        }
                    }
                }
                KeyCode::Esc => {
                    self.cancel_add_group();
                    false
                }
                _ => {
                    field.key(k);
                    true
                }
            },
            Popup::GroupList { mode, sel } => match k.code {
                KeyCode::Down => {
                    *sel = (*sel + 1).min(self.menu.groups.len() - 1);
                    true
                }
                KeyCode::Up => {
                    *sel = sel.saturating_sub(1);
                    true
                }
                KeyCode::Enter => {
                    let (mode, g) = (*mode, *sel);
                    self.popups.push(top);
                    match mode {
                        GroupListMode::Delete if self.menu.groups.len() == 1 => {
                            self.error("Gruppe löschen:", "Die letzte Gruppe darf nicht gelöscht werden!")
                        }
                        GroupListMode::Delete => self.popups.push(Popup::Confirm {
                            what: Delete::Group(g),
                            text: "Diese Gruppe löschen?".into(),
                            yes: false,
                        }),
                        GroupListMode::Rename => self.popups.push(Popup::RenameGroup {
                            group: g,
                            field: Field::new(&self.menu.groups[g].name, 20),
                        }),
                    }
                    return None;
                }
                KeyCode::Esc => false,
                _ => true,
            },
            Popup::RenameGroup { group, field } => match k.code {
                KeyCode::Enter => {
                    if self.menu.rename_group(*group, &field.text).is_ok() {
                        self.save();
                    }
                    false
                }
                KeyCode::Esc => false,
                _ => {
                    field.key(k);
                    true
                }
            },
            Popup::SortGroups { cur, grabbed } => {
                let n = self.menu.groups.len();
                let keep = sort_key(k, cur, grabbed, n, |a, b| self.menu.groups.swap(a, b));
                if !keep {
                    self.group = self.group.min(n - 1);
                    self.save();
                }
                keep
            }
            Popup::SortItems { cur, grabbed } => {
                let g = self.group;
                let keep = sort_key(k, cur, grabbed, ITEMS, |a, b| self.menu.groups[g].items.swap(a, b));
                if !keep {
                    self.save();
                }
                keep
            }
            Popup::EditItem { item, name, prog, chdir, focus } => match k.code {
                KeyCode::Tab | KeyCode::Down => {
                    *focus = (*focus + 1) % 3;
                    true
                }
                KeyCode::BackTab | KeyCode::Up => {
                    *focus = (*focus + 2) % 3;
                    true
                }
                KeyCode::Char(' ') if *focus == 2 => {
                    *chdir = !*chdir;
                    true
                }
                KeyCode::Char('v') if k.modifiers.contains(KeyModifiers::ALT) => {
                    *chdir = !*chdir;
                    true
                }
                KeyCode::Enter => {
                    // OK with both fields empty counts as cancel.
                    if !(name.text.is_empty() && prog.text.is_empty()) {
                        let it = Item { name: name.text.clone(), prog: prog.text.clone(), chdir: *chdir };
                        *self.item_mut(*item) = it;
                        self.save();
                    }
                    false
                }
                KeyCode::Esc => false,
                _ => {
                    match focus {
                        0 => name.key(k),
                        1 => prog.key(k),
                        _ => false,
                    };
                    true
                }
            },
            Popup::EditGroup { sel } => {
                let sel = *sel;
                let act = match k.code {
                    KeyCode::Down | KeyCode::Up => {
                        if let Popup::EditGroup { sel } = &mut top {
                            *sel = if k.code == KeyCode::Down { (*sel + 1).min(ITEMS - 1) } else { sel.saturating_sub(1) };
                        }
                        None
                    }
                    KeyCode::Insert => Some('e'),
                    KeyCode::Delete => Some('l'),
                    KeyCode::Enter => Some('u'),
                    KeyCode::Esc => Some('f'),
                    _ => plain_char(&k),
                };
                match act {
                    Some('f') => false,
                    Some(a @ ('e' | 'u' | 'l')) => {
                        self.popups.push(top);
                        match a {
                            'e' => self.popups.push(self.picker(PickFor::Edit(sel))),
                            'u' => self.popups.push(self.edit_item(sel)),
                            _ => self.popups.push(Popup::Confirm {
                                what: Delete::Entry(sel),
                                text: "Diesen Eintrag löschen?".into(),
                                yes: true,
                            }),
                        }
                        return None;
                    }
                    _ => true,
                }
            }
            Popup::Pick { picker, purpose } => match k.code {
                KeyCode::Down => {
                    picker.down();
                    true
                }
                KeyCode::Up => {
                    picker.up();
                    true
                }
                KeyCode::Enter => match picker.enter() {
                    None => true,
                    Some(path) => {
                        self.pick_dir = picker.dir.clone();
                        let path = path.to_string_lossy().into_owned();
                        match *purpose {
                            PickFor::Slot(i) => {
                                *self.item_mut(i) = Item::for_program(&path);
                                self.save();
                                self.popups.push(self.edit_item(i));
                            }
                            PickFor::Edit(i) => {
                                let mut name = Item::for_program(&path).name.to_lowercase();
                                if let Some(c) = name.chars().next() {
                                    name.replace_range(..c.len_utf8(), &upcase(c).to_string());
                                }
                                self.popups.push(Popup::PlaceFile {
                                    item: i,
                                    path,
                                    name: Field::new(&name, 18),
                                    chdir: true,
                                });
                            }
                        }
                        false
                    }
                },
                KeyCode::Esc => false,
                _ => {
                    if let Some(c) = plain_char(&k) {
                        picker.jump(c);
                    }
                    true
                }
            },
            // Enter = overwrite the slot ("Eintragen"), Ins = insert and shift the rest down ("Einfügen").
            Popup::PlaceFile { item, path, name, chdir } => match k.code {
                KeyCode::Enter | KeyCode::Insert => {
                    let it = Item { name: name.text.clone(), prog: path.clone(), chdir: *chdir };
                    let items = &mut self.menu.groups[self.group].items;
                    if k.code == KeyCode::Insert {
                        if !items[ITEMS - 1].name.is_empty() || items[ITEMS - 1].is_runnable() {
                            self.popups.push(top);
                            self.error("Einfügen ist nicht mehr möglich!", "Es würde der letzte Eintrag gelöscht werden.");
                            return None;
                        }
                        items[*item..].rotate_right(1);
                    }
                    items[*item] = it;
                    self.save();
                    false
                }
                KeyCode::Char('v') if k.modifiers.contains(KeyModifiers::ALT) => {
                    *chdir = !*chdir;
                    true
                }
                KeyCode::Esc => false,
                _ => {
                    name.key(k);
                    true
                }
            },
        };
        if keep {
            self.popups.push(top);
        }
        None
    }

    /// Cancelling the very first group leaves DXM.
    fn cancel_add_group(&mut self) {
        self.quit_now |= self.needs_group;
    }

    fn edit_item(&self, i: usize) -> Popup {
        let it = self.item(i);
        Popup::EditItem {
            item: i,
            name: Field::new(&it.name, 18),
            prog: Field::new(&it.prog, 78),
            chdir: it.chdir,
            focus: 0,
        }
    }

    fn admin(&mut self, sel: usize) -> Option<Outcome> {
        match sel {
            1 => self.popups.push(Popup::AddGroup { field: Field::new("", 20) }),
            2 => self.popups.push(Popup::GroupList { mode: GroupListMode::Delete, sel: 0 }),
            3 if self.menu.groups.len() == 1 => {
                self.error("Gruppe sortieren:", "Wie soll ich denn nur eine Gruppe sortieren??")
            }
            3 => self.popups.push(Popup::SortGroups { cur: 0, grabbed: false }),
            4 => self.popups.push(Popup::GroupList { mode: GroupListMode::Rename, sel: 0 }),
            6 => self.confirm_delete_entry(self.cur),
            7 => self.popups.push(Popup::SortItems { cur: 0, grabbed: false }),
            8 => self.popups.push(Popup::EditGroup { sel: self.cur }),
            10 => return Some(Outcome::Quit),
            _ => {}
        }
        None
    }

    fn item_menu(&mut self, item: usize, p: usize) -> Option<Outcome> {
        self.cur = item;
        match p {
            0 => self.popups.push(self.picker(PickFor::Slot(item))),
            1 => self.popups.push(self.edit_item(item)),
            2 => self.confirm_delete_entry(item),
            3 => self.popups.push(Popup::Swap { from: item, target: item }),
            4 => self.popups.push(Popup::Separator { item, sel: 0 }),
            _ => return Some(Outcome::Quit),
        }
        None
    }

    fn confirmed(&mut self, what: Delete) {
        match what {
            Delete::Entry(i) => {
                let it = self.item_mut(i);
                it.name.clear();
                it.prog.clear();
                self.save();
            }
            Delete::Group(g) => {
                if self.menu.delete_group(g).is_ok() {
                    self.group = self.group.min(self.menu.groups.len() - 1);
                    if let Some(Popup::GroupList { sel, .. }) = self.popups.last_mut() {
                        *sel = (*sel).min(self.menu.groups.len() - 1);
                    }
                    self.save();
                }
            }
        }
    }

    pub fn mouse(&mut self, m: MouseEvent) -> Option<Outcome> {
        if !self.popups.is_empty() {
            return None;
        }
        let hit = |r: &ratatui::layout::Rect| {
            m.column >= r.x && m.column < r.x + r.width && m.row >= r.y && m.row < r.y + r.height
        };
        match m.kind {
            MouseEventKind::Down(MouseButton::Left) => {
                if let Some(&(_, g)) = self.hit_bar.iter().find(|(r, _)| hit(r)) {
                    match g {
                        Some(g) => self.group = g,
                        None => self.popups.push(Popup::Admin { sel: 1 }),
                    }
                } else if let Some(&(_, i)) = self.hit_items.iter().find(|(r, _)| hit(r)) {
                    self.cur = i;
                    return self.run(i);
                }
            }
            MouseEventKind::Down(MouseButton::Right) => {
                if let Some(&(_, i)) = self.hit_items.iter().find(|(r, _)| hit(r)) {
                    self.cur = i;
                    self.popups.push(Popup::ItemMenu { item: i, sel: 0 });
                }
            }
            MouseEventKind::ScrollDown => self.step(1),
            MouseEventKind::ScrollUp => self.step(-1),
            _ => {}
        }
        None
    }
}

/// Cursor movement in the admin menu skips headings and separators.
fn next_admin(sel: usize, d: isize) -> usize {
    let n = ADMIN.len() as isize;
    let mut s = sel as isize;
    loop {
        s = (s + d).rem_euclid(n);
        if ADMIN[s as usize].is_some() {
            return s as usize;
        }
    }
}

/// Reordering list (SortGroups / SortItems): Enter picks up or drops the entry, cursor keys move the
/// cursor and carry a picked-up entry along. Returns false when the dialog closes.
fn sort_key(k: KeyEvent, cur: &mut usize, grabbed: &mut bool, n: usize, mut swap: impl FnMut(usize, usize)) -> bool {
    match k.code {
        KeyCode::Up if *cur > 0 => {
            if *grabbed {
                swap(*cur, *cur - 1);
            }
            *cur -= 1;
        }
        KeyCode::Down if *cur + 1 < n => {
            if *grabbed {
                swap(*cur, *cur + 1);
            }
            *cur += 1;
        }
        KeyCode::Enter => *grabbed = !*grabbed,
        KeyCode::Esc | KeyCode::F(10) => return false,
        _ => {}
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::menu::Group;

    fn app(groups: usize) -> App {
        let mut m = Menu::default();
        for g in 0..groups {
            m.groups.push(Group::new(&format!("G{g}")));
        }
        let dir = std::env::temp_dir();
        App::new(Some(m), MenuPos { group: 0, item: 0 }, dir.join("dxm-test-menu.dat"), dir)
    }

    fn key(c: KeyCode) -> KeyEvent {
        KeyEvent::new(c, KeyModifiers::NONE)
    }

    #[test]
    fn grid_wraps_into_neighbour_groups() {
        let mut a = app(3);
        a.key(key(KeyCode::Up));
        assert_eq!((a.group, a.cur), (2, 20));
        a.key(key(KeyCode::Down));
        assert_eq!((a.group, a.cur), (0, 0));
        a.cur = 16;
        a.key(key(KeyCode::Right));
        assert_eq!((a.group, a.cur), (1, 2));
    }

    #[test]
    fn delete_entry_is_saved() {
        let mut a = app(1);
        a.menu_path = std::env::temp_dir().join(format!("dxm-test-{}.dat", std::process::id()));
        a.menu.groups[0].items[2] = Item::for_program("C:\\X\\EDIT.COM");
        a.cur = 2;
        a.key(key(KeyCode::Delete));
        a.key(key(KeyCode::Char('j')));
        assert!(a.popups.is_empty());
        let saved = Menu::load(&a.menu_path).unwrap();
        assert_eq!(saved.groups[0].items[2], Item { chdir: true, ..Default::default() });
        let _ = std::fs::remove_file(&a.menu_path);
    }

    #[test]
    fn admin_cursor_skips_headings() {
        assert_eq!(next_admin(4, 1), 6);
        assert_eq!(next_admin(1, -1), 10);
        assert_eq!(next_admin(8, 1), 10);
    }

    #[test]
    fn f_keys_select_columns() {
        let mut a = app(1);
        a.menu.groups[0].items[9] = Item::for_program("/bin/true");
        let alt = KeyEvent::new(KeyCode::F(3), KeyModifiers::ALT);
        assert!(matches!(a.key(alt), Some(Outcome::Run(_))));
        assert_eq!(a.cur, 9);
        assert!(a.key(key(KeyCode::F(1))).is_none()); // empty slot: select only
    }
}
