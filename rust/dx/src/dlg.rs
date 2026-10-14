//! Small dialogs used all over DXMAIN: input box, yes/no box, choice box, info box, wait box.

use dxtui::button::Buttons;
use dxtui::keys::*;
use dxtui::ui::Ui;

/// Left column and width of a box of inner width `w`, centred.
fn centre(ui: &Ui, w: i32) -> i32 {
    ((ui.cols() - w - 2) / 2 + 1).max(1)
}

fn top(ui: &Ui, h: i32) -> i32 {
    ((ui.rows() - h - 2) / 2 + 1).max(2)
}

/// Input box: title, prompt and an edit field. True when ended with Return.
pub fn ask(ui: &mut Ui, title: &str, prompt: &str, s: &mut String, max_len: i32) -> bool {
    let w = 56.min(ui.cols() - 4);
    let x = centre(ui, w);
    let y = top(ui, 6);
    ui.open_dialog();
    ui.frame(x, y, w, 6, 11, 3, false, true);
    ui.write_center_xyfb(1, 1, w, 14, 3, title);
    ui.set_color(0, 3);
    ui.write_xy(3, 3, prompt);
    let mut t = s.clone();
    let k = loop {
        let k = ui.input_line(x + 2, y + 5, x + 1, x + w, &mut t, w - 6, max_len, false);
        if k == ENTER || k == ESC || k == F10 {
            break k;
        }
    };
    ui.close_dialog();
    if k == ENTER {
        *s = t;
        true
    } else {
        false
    }
}

/// Yes/No box with up to three text lines. `yes_first` puts the focus on Yes.
pub fn confirm(ui: &mut Ui, title: &str, lines: &[&str], yes_first: bool) -> bool {
    choose(ui, title, lines, &["Yes", "No"], if yes_first { 0 } else { 1 }) == Some(0)
}

/// Box with buttons (hotkey = first letter). Returns the button index; None on Esc.
pub fn choose(ui: &mut Ui, title: &str, lines: &[&str], caps: &[&str], focus: usize) -> Option<usize> {
    let bw: i32 = caps.iter().map(|c| c.len() as i32 + 6).sum::<i32>() + 2 * (caps.len() as i32 - 1);
    let tw = lines.iter().map(|l| l.chars().count() as i32).max().unwrap_or(0).max(title.chars().count() as i32);
    let w = (tw + 4).max(bw + 4).max(30).min(ui.cols() - 4);
    let h = lines.len() as i32 + 5;
    let x = centre(ui, w);
    let y = top(ui, h);
    ui.open_dialog();
    ui.frame(x, y, w, h, 15, 5, false, true);
    ui.write_center_xyfb(1, 1, w, 14, 5, title);
    for (i, l) in lines.iter().enumerate() {
        ui.write_center_xyfb(1, 3 + i as i32, w, 15, 5, l);
    }
    let (c, r) = (ui.cols(), ui.rows());
    ui.window(1, 1, c, r);
    let caps2: Vec<String> = caps.iter().map(|c| format!("  {c}  ")).collect();
    let mut pos = vec![];
    let mut bx = x + 1 + (w - bw) / 2;
    for c in &caps2 {
        pos.push((bx, y + h - 2));
        bx += c.len() as i32 + 4;
    }
    let refs: Vec<&str> = caps2.iter().map(|s| s.as_str()).collect();
    let mut b = Buttons::new(&mut ui.crt, focus == 0, &pos, 14, 0, 15, 5, &refs);
    if caps.len() > 2 {
        b.set(&mut ui.crt, focus);
    }
    let mut key = 0;
    let res = loop {
        if let Some(i) = b.handle(ui, &mut key) {
            break Some(i);
        }
        if key == ENTER {
            break (0..caps.len()).find(|&i| b[i].focused);
        }
        if let Some(ch) = Key::new(key).char().map(dxtui::lo_case) {
            if let Some(i) = caps.iter().position(|c| c.chars().next().map(dxtui::lo_case) == Some(ch)) {
                break Some(i);
            }
        }
        if key == ESC || key == F10 || ui.mouse.button == 2 {
            break None;
        }
    };
    ui.close_dialog();
    res
}

/// Message box with a title and lines; any key closes it.
pub fn info(ui: &mut Ui, title: &str, lines: &[String]) {
    let tw = lines.iter().map(|l| l.chars().count() as i32).max().unwrap_or(0).max(title.chars().count() as i32);
    let w = (tw + 4).max(30).min(ui.cols() - 4);
    let h = (lines.len() as i32 + 3).min(ui.rows() - 4);
    let x = centre(ui, w);
    let y = top(ui, h);
    ui.open_dialog();
    ui.frame(x, y, w, h, 11, 3, false, true);
    ui.write_center_xyfb(1, 1, w, 14, 3, title);
    for (i, l) in lines.iter().take((h - 3) as usize).enumerate() {
        ui.write_xyfb(3, 3 + i as i32, 0, 3, &crate::panel::fit(l, (w - 4) as usize));
    }
    ui.wait_release();
    loop {
        let k = ui.get_key();
        if k != 0 || ui.mouse.button != 0 {
            break;
        }
    }
    ui.close_dialog();
}

/// Shows a one-line "please wait" box; close it with `ui.pop_screen()`.
pub fn wait_box(ui: &mut Ui, text: &str) {
    let w = (text.chars().count() as i32 + 6).max(30).min(ui.cols() - 4);
    let x = centre(ui, w);
    let y = top(ui, 1);
    ui.open_dialog();
    ui.frame(x, y, w, 1, 11, 3, false, true);
    ui.write_center_xyfb(1, 1, w, 0, 3, text);
    ui.flush();
}

/// True when Esc was pressed (polls without waiting); for long operations.
pub fn interrupted(ui: &mut Ui) -> bool {
    if let Some(k) = ui.crt.poll_key(0) {
        return k.code == ESC;
    }
    false
}

/// Scrolling list box; returns the chosen index (Return or double click), None on Esc.
pub fn list(ui: &mut Ui, title: &str, lines: &[String], start: usize) -> Option<usize> {
    if lines.is_empty() {
        info(ui, title, &["Nothing found.".into()]);
        return None;
    }
    let tw = lines.iter().map(|l| l.chars().count() as i32).max().unwrap_or(0).max(title.chars().count() as i32 + 4);
    let w = (tw + 2).max(30).min(ui.cols() - 4);
    let h = (lines.len() as i32).min(ui.rows() - 6).max(1);
    let x = centre(ui, w);
    let y = top(ui, h);
    ui.open_dialog();
    ui.frame(x, y, w, h, 11, 3, false, true);
    let (c, r) = (ui.cols(), ui.rows());
    ui.window(1, 1, c, r);
    ui.write_xyfb(x + (w + 2 - title.chars().count() as i32 - 2) / 2, y, 14, 3, &format!(" {title} "));
    let n = lines.len();
    let hu = h as usize;
    let mut cur = start.min(n - 1);
    let mut topi = cur.saturating_sub(hu / 2).min(n.saturating_sub(hu));
    let res = loop {
        if cur < topi {
            topi = cur;
        }
        if cur >= topi + hu {
            topi = cur + 1 - hu;
        }
        for row in 0..hu {
            let i = topi + row;
            let s = lines.get(i).map(|s| s.as_str()).unwrap_or("");
            let (fg, bg) = if i == cur { (0, 2) } else { (0, 3) };
            ui.write_xyfb(x + 1, y + 1 + row as i32, fg, bg, &crate::panel::fit(&format!(" {s}"), w as usize));
        }
        let k = ui.get_key();
        let m = ui.mouse;
        if k == 0 {
            if m.button == 2 {
                ui.wait_release();
                break None;
            }
            if m.button == 1 {
                if m.y > y && m.y <= y + h && m.x > x && m.x <= x + w {
                    let i = topi + (m.y - y - 1) as usize;
                    if i < n {
                        let dbl = ui.double_click(m.x, m.y);
                        cur = i;
                        if dbl {
                            ui.wait_release();
                            break Some(cur);
                        }
                    }
                } else if m.y <= y && topi > 0 {
                    cur = cur.saturating_sub(1);
                } else if m.y > y + h {
                    cur = (cur + 1).min(n - 1);
                }
            }
            continue;
        }
        match k {
            ESC | F10 => break None,
            ENTER => break Some(cur),
            UP => cur = cur.saturating_sub(1),
            DOWN => cur = (cur + 1).min(n - 1),
            PGUP => cur = cur.saturating_sub(hu),
            PGDN => cur = (cur + hu).min(n - 1),
            HOME | CTRL_PGUP => cur = 0,
            END | CTRL_PGDN => cur = n - 1,
            _ => {
                if let Some(ch) = Key::new(k).char().map(dxtui::lo_case) {
                    if let Some(i) = (1..=n).map(|d| (cur + d) % n).find(|&i| {
                        lines[i].trim_start().chars().next().map(dxtui::lo_case) == Some(ch)
                    }) {
                        cur = i;
                    }
                }
            }
        }
    };
    ui.close_dialog();
    res
}

/// Output text in a scrolling box (archive listings, command output).
pub fn text(ui: &mut Ui, title: &str, s: &str) {
    let lines: Vec<String> = s.lines().map(|l| l.replace('\t', "    ")).collect();
    let lines = if lines.is_empty() { vec!["(no output)".to_string()] } else { lines };
    list(ui, title, &lines, 0);
}
