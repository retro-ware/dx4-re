//! F9 hex editor: offset, 16 bytes in hex and as characters per line. Hex digits overwrite nibbles, Tab
//! switches to the character column, F2 saves, Esc ends (asks when changed).

use crate::dlg;
use dxtui::keys::*;
use dxtui::ui::Ui;
use std::path::Path;

const MAX: u64 = 64 << 20;

pub fn edit(ui: &mut Ui, path: &Path) {
    if std::fs::metadata(path).map(|m| m.len() > MAX).unwrap_or(false) {
        dlg::info(ui, "Hex editor", &["The file is too big for the hex editor.".into()]);
        return;
    }
    let mut buf = match std::fs::read(path) {
        Ok(b) => b,
        Err(e) => {
            dlg::info(ui, "Hex editor", &[format!("{}: {e}", path.display())]);
            return;
        }
    };
    if buf.is_empty() {
        ui.error_box("Hex viewer: the file has 0 bytes!", &path.display().to_string());
        return;
    }
    let orig = buf.clone();
    ui.open_dialog();
    let (c, r) = (ui.cols(), ui.rows());
    let rows = (r - 2) as usize;
    let mut pos = 0usize;
    let mut low = false;
    let mut text = false;
    let mut top = 0usize;
    ui.window(1, 1, c, r);
    ui.set_color(0, 3);
    ui.goto_xy(1, 1);
    ui.clr_eol();
    ui.write_xyf(2, 1, 4, "F2");
    ui.write(" Save  ");
    ui.write_f(4, "Tab");
    ui.write(" Hex/Text  ");
    ui.write_f(4, "Esc");
    ui.write(" End");
    ui.write_xy(c - 46, 1, &crate::panel::fit(&crate::panel::shorten(&path.display().to_string(), 40), 40));
    loop {
        let n = buf.len();
        let line = pos / 16;
        if line < top {
            top = line;
        }
        if line >= top + rows {
            top = line + 1 - rows;
        }
        for y in 0..rows {
            let o = (top + y) * 16;
            let mut s = format!("{o:08X}  ");
            let mut t = String::new();
            for i in 0..16 {
                match buf.get(o + i) {
                    Some(&b) => {
                        s += &format!("{b:02X} ");
                        t.push(if b < 32 || b == 127 { '.' } else { dxtui::cp437::decode(&[b]).chars().next().unwrap() });
                    }
                    None => s += "   ",
                }
                if i == 7 {
                    s.push(' ');
                }
            }
            let line = if o <= n { format!("{s} {t}") } else { String::new() };
            ui.write_xyfb(1, 2 + y as i32, 14, 1, &crate::panel::fit(&line, c as usize));
            // changed bytes
            for i in 0..16 {
                let k = o + i;
                if k < n && orig.get(k) != Some(&buf[k]) {
                    let x = 11 + i as i32 * 3 + (i >= 8) as i32;
                    ui.write_xyfb(x, 2 + y as i32, 15, 1, &format!("{:02X}", buf[k]));
                }
            }
        }
        let (cy, i) = ((pos / 16 - top) as i32 + 2, (pos % 16) as i32);
        let hx = 11 + i * 3 + (i >= 8) as i32 + low as i32;
        let tx = 61 + i;
        ui.goto_xy(if text { tx } else { hx }, cy);
        ui.cursor_visible = true;
        if pos < n {
            let cell = ui.peek(if text { hx - low as i32 } else { tx }, cy);
            ui.poke(if text { hx - low as i32 } else { tx }, cy, 0x3000 | (cell & 0xFF));
        }
        let b = buf.get(pos).copied().unwrap_or(0);
        ui.write_xyfb(1, r, 0, 3, &crate::panel::fit(&format!(" Offset {pos} ({pos:X}h)   Byte {b} ({b:02X}h, {b:08b}b)   Size {n}{}",
            if buf != orig { "   modified" } else { "" }), c as usize));
        let k = ui.read_key();
        match k {
            ESC | F10 => {
                if buf != orig {
                    match dlg::choose(ui, "Hex editor", &["The file was changed."], &["Save", "Discard", "Cancel"], 0) {
                        Some(0) => {
                            if save(ui, path, &buf) {
                                break;
                            }
                        }
                        Some(1) => break,
                        _ => {}
                    }
                } else {
                    break;
                }
            }
            k if k == F1 + 1 => {
                save(ui, path, &buf);
                ui.cursor_visible = true;
            }
            TAB => {
                text = !text;
                low = false;
            }
            LEFT => {
                if !text && low {
                    low = false;
                } else if pos > 0 {
                    pos -= 1;
                    low = !text;
                }
            }
            RIGHT => {
                if !text && !low {
                    low = true;
                } else if pos + 1 < n {
                    pos += 1;
                    low = false;
                }
            }
            UP => pos = pos.saturating_sub(16),
            DOWN => pos = (pos + 16).min(n.saturating_sub(1)),
            PGUP => pos = pos.saturating_sub(16 * rows),
            PGDN => pos = (pos + 16 * rows).min(n.saturating_sub(1)),
            HOME => pos -= pos % 16,
            END => pos = (pos - pos % 16 + 15).min(n.saturating_sub(1)),
            CTRL_HOME | CTRL_PGUP => pos = 0,
            CTRL_END | CTRL_PGDN => pos = n.saturating_sub(1),
            k if pos < n => {
                if text {
                    if let Some(ch) = Key::new(k).char() {
                        buf[pos] = dxtui::cp437::encode(&ch.to_string()).first().copied().unwrap_or(b'?');
                        pos = (pos + 1).min(n - 1);
                    }
                } else if let Some(d) = Key::new(k).char().and_then(|c| c.to_digit(16)) {
                    let d = d as u8;
                    buf[pos] = if low { buf[pos] & 0xF0 | d } else { buf[pos] & 0x0F | d << 4 };
                    if low {
                        low = false;
                        pos = (pos + 1).min(n - 1);
                    } else {
                        low = true;
                    }
                }
            }
            _ => {}
        }
    }
    ui.cursor_visible = false;
    ui.close_dialog();
}

fn save(ui: &mut Ui, path: &Path, buf: &[u8]) -> bool {
    match std::fs::write(path, buf) {
        Ok(()) => true,
        Err(e) => {
            dlg::info(ui, "Hex editor", &[format!("{}: {e}", path.display())]);
            false
        }
    }
}
