//! F3 file viewer (FileView): key bar in row 1, text in yellow on blue, cursor line, column cursor, line
//! and offset in the bottom row, search (F7 new, F5 again), hex/decimal offsets (F9), copy a marked
//! range to NAME.cut (Return sets the markers, F3 writes). Spec: src/dxmain/FILEVIEW.PAS.

use crate::dlg;
use dxtui::keys::*;
use dxtui::ui::Ui;
use std::path::Path;

const MAX: u64 = 256 << 20;

struct View {
    buf: Vec<u8>,
    /// Start offsets of the screen lines (wrapped at the screen width); one extra entry = end.
    lines: Vec<usize>,
    top: usize,
    row: usize,
    col: usize,
    hex: bool,
    find: String,
    mark: Option<(usize, usize)>,
}

fn index(buf: &[u8], width: usize) -> Vec<usize> {
    let mut v = vec![0];
    let mut col = 0;
    for (i, &b) in buf.iter().enumerate() {
        if b == b'\n' {
            v.push(i + 1);
            col = 0;
            continue;
        }
        if b == b'\t' {
            col = (col / 8 + 1) * 8;
        } else if b != b'\r' {
            col += 1;
        }
        if col >= width && buf.get(i + 1) != Some(&b'\n') {
            v.push(i + 1);
            col = 0;
        }
    }
    if *v.last().unwrap() != buf.len() {
        v.push(buf.len());
    }
    if v.len() == 1 {
        v.push(0);
    }
    v
}

impl View {
    fn nlines(&self) -> usize {
        self.lines.len() - 1
    }

    fn line(&self, n: usize) -> &[u8] {
        let a = self.lines[n];
        let b = self.lines[n + 1];
        let mut s = &self.buf[a..b];
        while let [rest @ .., b'\n' | b'\r'] = s {
            s = rest;
        }
        s
    }

    /// Screen bytes of line n (tabs expanded) and the buffer offset of each column.
    fn cells(&self, n: usize, w: usize) -> (Vec<u8>, Vec<usize>) {
        let mut out = vec![];
        let mut ofs = vec![];
        let base = self.lines[n];
        for (i, &b) in self.line(n).iter().enumerate() {
            if b == b'\t' {
                let to = (out.len() / 8 + 1) * 8;
                while out.len() < to && out.len() < w {
                    out.push(b' ');
                    ofs.push(base + i);
                }
            } else if out.len() < w {
                out.push(if b == 0 { b' ' } else { b });
                ofs.push(base + i);
            }
        }
        (out, ofs)
    }

    fn cur_line(&self) -> usize {
        self.top + self.row - 1
    }
}

fn draw_bar(ui: &mut Ui, size: usize, name: &str) {
    let (c, r) = (ui.cols(), ui.rows());
    ui.window(1, 1, c, r);
    ui.set_color(0, 3);
    ui.goto_xy(1, 1);
    ui.clr_eol();
    for (k, t) in [(" F1", " Help  "), (" F2", " Print "), (" F3", " Copy "), (" F5", " Again "), (" F7", " Find "),
        (" F9", " Hex-Dec")] {
        ui.write_f(4, k);
        ui.write(t);
    }
    ui.goto_xy(c - 22, 1);
    ui.write(&format!("{size:>9} bytes"));
    ui.goto_xy(1, r);
    ui.clr_eol();
    ui.write(&format!(" {}", crate::panel::shorten(name, 36)));
    ui.write_xy(40, r, "Line:");
    ui.write_xy(54, r, "Offset:");
}

fn draw(ui: &mut Ui, v: &View) {
    let (c, r) = (ui.cols(), ui.rows());
    let w = c as usize;
    for y in 0..(r - 2) as usize {
        let n = v.top + y;
        let cursor = y + 1 == v.row;
        let (fg, bg) = if cursor { (0, 7) } else { (14, 1) };
        if n < v.nlines() {
            let (cells, ofs) = v.cells(n, w);
            for x in 0..w {
                let ch = cells.get(x).copied().unwrap_or(b' ');
                let mut b = bg;
                if let (Some((a, e)), Some(&o)) = (v.mark, ofs.get(x)) {
                    if !cursor && o >= a && o <= e {
                        b = 5;
                    }
                }
                ui.poke(x as i32 + 1, y as i32 + 2, ((b as u16) << 4 | fg as u16) << 8 | ch as u16);
            }
            if cursor {
                let x = v.col.min(w) as i32;
                let cell = ui.peek(x, y as i32 + 2);
                ui.poke(x, y as i32 + 2, 0x0E00 | (cell & 0xFF));
            }
        } else {
            for x in 1..=c {
                ui.poke(x, y as i32 + 2, ((bg as u16) << 4 | fg as u16) << 8 | b' ' as u16);
            }
        }
    }
    // position
    let n = v.cur_line();
    let ofs = v.cells(n.min(v.nlines() - 1), w).1;
    let o = ofs.get(v.col - 1).copied().unwrap_or(v.lines[n.min(v.nlines() - 1)]);
    ui.set_color(0, 3);
    ui.goto_xy(46, r);
    ui.write("        ");
    ui.write_xyf(46, r, 14, &format!("{}", n + 1));
    ui.goto_xy(61, r);
    ui.clr_eol();
    let s = if v.hex { format!("{o:X}") } else { o.to_string() };
    ui.write_xyf(62, r, if v.hex { 10 } else { 14 }, &crate::panel::fit(&s, 8));
    if let Some(&b) = v.buf.get(o) {
        let ch = if matches!(b, 13 | 10 | 8 | 7 | 0) { b' ' } else { b };
        ui.goto_xy(71, r);
        ui.text_color(0);
        ui.write_b(&[ch]);
        ui.write_xyf(74, r, 10, &format!("{b:02X}"));
        ui.write_xyf(77, r, 14, &format!("{b:3}"));
    }
}

fn find(v: &mut View, from: usize, rows: usize) -> bool {
    if v.find.is_empty() {
        return false;
    }
    let pat: Vec<u8> = v.find.to_lowercase().into_bytes();
    let hay: Vec<u8> = v.buf.iter().map(|b| b.to_ascii_lowercase()).collect();
    let start = from.min(hay.len());
    if let Some(p) = hay[start..].windows(pat.len()).position(|w| w == pat.as_slice()) {
        let o = start + p;
        let n = v.lines.partition_point(|&s| s <= o) - 1;
        v.top = n.saturating_sub(rows / 2).min(v.nlines().saturating_sub(rows));
        v.row = n - v.top + 1;
        v.col = o - v.lines[n] + 1;
        true
    } else {
        false
    }
}

/// Shows file `path`. Returns when the viewer is closed.
pub fn view(ui: &mut Ui, path: &Path) {
    let buf = match std::fs::metadata(path) {
        Ok(m) if m.len() > MAX => {
            dlg::info(ui, "View", &["The file is too big for the viewer.".into(), path.display().to_string()]);
            return;
        }
        Ok(_) => match std::fs::read(path) {
            Ok(b) => b,
            Err(e) => {
                dlg::info(ui, "View", &["The file could not be opened.".into(), format!("{}: {e}", path.display())]);
                return;
            }
        },
        Err(e) => {
            dlg::info(ui, "View", &[format!("{}: {e}", path.display())]);
            return;
        }
    };
    ui.open_dialog();
    let (c, r) = (ui.cols(), ui.rows());
    let rows = (r - 2) as usize;
    let mut v = View { lines: index(&buf, c as usize), buf, top: 0, row: 1, col: 1, hex: false, find: String::new(),
        mark: None };
    let name = path.display().to_string();
    draw_bar(ui, v.buf.len(), &name);
    let mut mark_start: Option<usize> = None;
    loop {
        let n = v.nlines();
        if v.row > rows.min(n) {
            v.row = rows.min(n).max(1);
        }
        draw(ui, &v);
        let mut key = ui.get_key();
        let m = ui.mouse;
        if m.button == 1 && m.y == 1 {
            let k = match m.x {
                2..=9 => F1,
                12..=19 => F1 + 1,
                22..=28 => F1 + 2,
                31..=38 => F1 + 4,
                41..=47 => F1 + 6,
                50..=59 => F9,
                _ => UP,
            };
            ui.wait_release();
            key = k;
        } else if m.button == 1 && m.y == r {
            key = DOWN;
        } else if m.button == 1 && m.y > 1 && m.y < r {
            v.row = (m.y - 1) as usize;
            v.col = m.x as usize;
        }
        if m.button == 2 {
            ui.wait_release();
            break;
        }
        let maxtop = n.saturating_sub(rows);
        match key {
            ESC | F10 => break,
            F1 => dxtui::help::show_help(ui, 19),
            DOWN => {
                if v.row < rows.min(n) {
                    v.row += 1
                } else if v.top < maxtop {
                    v.top += 1
                }
            }
            UP => {
                if v.row > 1 {
                    v.row -= 1
                } else if v.top > 0 {
                    v.top -= 1
                }
            }
            PGDN => v.top = (v.top + rows).min(maxtop),
            PGUP => v.top = v.top.saturating_sub(rows),
            HOME | CTRL_HOME | CTRL_PGUP => {
                v.top = 0;
                v.row = 1;
            }
            END | CTRL_END | CTRL_PGDN => {
                v.top = maxtop;
                v.row = rows.min(n);
            }
            RIGHT => v.col = (v.col + 1).min(c as usize),
            LEFT => v.col = (v.col - 1).max(1),
            F9 => v.hex = !v.hex,
            k if k == F1 + 6 || k == F1 + 4 || k == 12 => {
                let again = k != F1 + 6;
                if !again || v.find.is_empty() {
                    let mut s = v.find.clone();
                    if !dlg::ask(ui, "Find", "Text to find:", &mut s, 80) {
                        continue;
                    }
                    v.find = s;
                }
                let line = v.cur_line();
                let from = if again { v.lines[line] + v.col } else { v.lines[line] };
                if !find(&mut v, from, rows) {
                    dlg::info(ui, "Find", &[format!("'{}' was not found.", v.find)]);
                }
            }
            ENTER => {
                let line = v.cur_line();
                let o = v.lines[line] + v.col - 1;
                match mark_start {
                    None => {
                        mark_start = Some(o);
                        v.mark = Some((o, o));
                    }
                    Some(a) => {
                        v.mark = Some((a.min(o), a.max(o)));
                        mark_start = None;
                    }
                }
            }
            k if k == F1 + 2 => {
                let (a, e) = v.mark.unwrap_or((0, v.buf.len().saturating_sub(1)));
                let stem = path.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
                let mut out = format!("{stem}.cut");
                if dlg::ask(ui, "Copy range", &format!("Write bytes {a}..{e} to:"), &mut out, 255) {
                    let p = crate::ops::resolve(path.parent().unwrap_or(Path::new(".")), &out);
                    if let Err(err) = std::fs::write(&p, &v.buf[a..=e.min(v.buf.len().saturating_sub(1))]) {
                        dlg::info(ui, "Copy range", &[format!("{}: {err}", p.display())]);
                    }
                }
            }
            k if k == F1 + 1 => dlg::info(ui, "Print", &["Printing is not available; use Copy (F3) and your".into(),
                "system's print command.".into()]),
            _ => {}
        }
        let w = ui.cols() as usize;
        let line_len = v.cells(v.cur_line().min(n.saturating_sub(1)), w).0.len().max(1);
        v.col = v.col.min(line_len.max(1)).max(1);
    }
    ui.close_dialog();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wraps_long_lines() {
        let b = b"ab\ncdef\n".to_vec();
        assert_eq!(index(&b, 80), vec![0, 3, 8]);
        let b = vec![b'x'; 100];
        assert_eq!(index(&b, 80), vec![0, 80, 100]);
    }
}
