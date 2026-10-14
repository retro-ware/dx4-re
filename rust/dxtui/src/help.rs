//! Online help viewer (Help.ShowHelp). Pages come from `help/dxhelp.txt`: `=== title` starts a page,
//! page 0 is the contents; choosing line N there opens page N.

use crate::button::{Button, Buttons};
use crate::keys::*;
use crate::list::List;
use crate::ui::Ui;

pub const TEXT: &str = include_str!("../help/dxhelp.txt");

pub struct Page {
    pub title: String,
    pub lines: Vec<String>,
}

pub fn pages() -> Vec<Page> {
    let mut v: Vec<Page> = vec![];
    for l in TEXT.lines() {
        if let Some(t) = l.strip_prefix("=== ") {
            v.push(Page { title: t.to_string(), lines: vec![] });
        } else if let Some(p) = v.last_mut() {
            p.lines.push(l.to_string());
        }
    }
    v
}

/// ShowHelp: full-screen help starting at page `start` (0 = contents).
pub fn show_help(ui: &mut Ui, start: usize) {
    let pages = pages();
    if pages.is_empty() {
        return;
    }
    let rows = ui.rows();
    let cols = ui.cols();
    ui.open_dialog();
    ui.set_color(0, 3);
    let save_clock = (ui.clock.x, ui.clock.y, ui.clock.fg, ui.clock.bg);
    ui.clock.x = cols - 5;
    ui.clock.y = 1;
    ui.clock.fg = 0;
    ui.clock.bg = 3;
    ui.window(1, 1, cols, rows);
    ui.clr_scr();
    ui.clock.last_date.clear();
    ui.clock.last_time.clear();
    ui.write_xy(2, 1, "DOS-Expander (C) Copyright 1994-1996 H.Hombergs");
    ui.frame(1, 2, cols - 2, rows - 6, 11, 3, false, false);
    ui.write("\r\n");
    ui.write(&"─".repeat(cols as usize - 2));
    ui.window(1, 1, cols, rows);
    let list_rows = rows - 8;
    let mut cur_page = start.min(pages.len() - 1);
    let mut page = cur_page;
    let lines_of = |p: usize| -> Vec<String> {
        let pg = &pages[p];
        if pg.lines.is_empty() { vec!["  (This page has not been written yet.)".into()] } else { pg.lines.clone() }
    };
    let mut text = lines_of(page);
    let index_colors = |l: &mut List, index: bool| {
        if index {
            l.sel_fg = 2;
            l.sel_bg = 1;
            l.fg = 14;
        } else {
            l.sel_fg = 0;
            l.sel_bg = 2;
            l.fg = 0;
        }
    };
    let go_button = |ui: &mut Ui| {
        ui.window(1, 1, cols, rows);
        let mut b = Button::new(true, 3, rows - 2, 14, 0, 11, 3, &crate::center("Go to", cols as i32 - 10));
        b.redraw(ui);
        b
    };
    let nav_buttons = |ui: &mut Ui| {
        ui.window(1, 1, cols, rows);
        for y in rows - 2..=rows {
            ui.goto_xy(1, y);
            ui.clr_eol();
        }
        Buttons::new(ui, true, &[(3, rows - 2), (23, rows - 2), (42, rows - 2), (60, rows - 2)], 14, 0, 11, 3,
            &["      Next     ", "     Back      ", "    Index    ", "    Cancel     "])
    };
    let mut go = go_button(ui);
    let mut nav = None;
    if page != 0 {
        nav = Some(nav_buttons(ui));
    }
    let show_title = |ui: &mut Ui, t: &str| {
        ui.window(5, 3, cols, 3);
        let a = ui.text_attr;
        ui.text_color(14);
        ui.write(&crate::pad_right(t, cols as usize - 5));
        ui.text_attr = a;
    };
    show_title(ui, &pages[page].title);
    let tl = text.clone();
    let lf = move |n: i32| format!(" {}", tl.get(n as usize - 1).cloned().unwrap_or_default());
    let mut l = List::new(ui, 0, 3, 0, 2, 2, 5, list_rows, text.len() as i32, cols - 3, true, &lf);
    index_colors(&mut l, page == 0);
    ui.set_color(l.fg, 3);
    l.draw_all(ui, &lf);
    if page == 0 && start == 0 {
        l.set_pos(ui, 1, 1, &lf);
    }
    loop {
        ui.window(1, 1, cols, rows);
        let mut key;
        let (mut next, mut back, mut index, mut abort, mut goto) = (false, false, false, false, false);
        if page == 0 {
            goto = go.mouse_button(ui);
            key = ui.get_key();
            if crate::Key::new(key).char().map(crate::lo_case) == Some('g') {
                goto = true;
            }
        } else {
            key = 0;
            match nav.as_mut().unwrap().handle(ui, &mut key) {
                Some(0) => next = true,
                Some(1) => back = true,
                Some(2) => index = true,
                Some(3) => abort = true,
                _ => {}
            }
            match crate::Key::new(key).char().map(crate::lo_case) {
                Some('n') => next = true,
                Some('b') => back = true,
                Some('i') => index = true,
                Some('c') => abort = true,
                _ => {}
            }
        }
        ui.window(2, 5, cols, rows);
        let tl = text.clone();
        let lf = move |n: i32| format!(" {}", tl.get(n as usize - 1).cloned().unwrap_or_default());
        let sel = l.handle(ui, &mut key, &lf);
        let mut new_page = None;
        if page == 0 && (key == ENTER || goto) {
            if (sel as usize) < pages.len() {
                new_page = Some(sel as usize);
                cur_page = sel as usize;
            } else {
                ui.error_box("This was the last page!", "There is nothing further.");
            }
        } else if page != 0 {
            if index {
                new_page = Some(0);
            }
            if next {
                if page + 1 < pages.len() {
                    new_page = Some(page + 1);
                    cur_page = page + 1;
                } else {
                    ui.error_box("This was the last page!", "There is nothing further.");
                }
            }
            if back {
                if page > 1 {
                    new_page = Some(page - 1);
                    cur_page = page - 1;
                } else {
                    new_page = Some(0);
                }
            }
        }
        if let Some(p) = new_page {
            let was_index = page == 0;
            page = p;
            text = lines_of(page);
            show_title(ui, &pages[page].title);
            if page == 0 {
                go = go_button(ui);
                nav = None;
            } else if was_index || nav.is_none() {
                nav = Some(nav_buttons(ui));
            }
            ui.window(2, 5, cols, rows);
            let tl = text.clone();
            let lf = move |n: i32| format!(" {}", tl.get(n as usize - 1).cloned().unwrap_or_default());
            index_colors(&mut l, page == 0);
            ui.set_color(l.fg, 3);
            if page == 0 {
                l.count = text.len() as i32;
                l.set_pos(ui, cur_page as i32, 6, &lf);
            } else {
                l.set_data(ui, text.len() as i32, list_rows, 1, 0, &lf);
            }
        }
        if ui.is_cancel(key) || abort {
            break;
        }
    }
    ui.pop_screen();
    (ui.clock.x, ui.clock.y, ui.clock.fg, ui.clock.bg) = save_clock;
    ui.clock.last_time.clear();
    ui.wait_release();
}
