//! The DOS input line (DXMAIN EditLine with history): a framed field above the bottom row, help text in the
//! bottom row. ^D inserts the cursor file name, ^P the active and ^A the other panel's directory, ^End
//! deletes to the end of the line, ↑↓ step through the history, Shift-↓ lists it, Return runs, Esc ends.

use crate::{panel, shell_quote, App};
use dxtui::keys::*;

const HELP: &str = " ^D ^P ^A ^End ↓ ↑ Shift↓ Ins Home End Esc=End Return=Run";

pub fn command_line(app: &mut App, init: &str) {
    let rows = app.ui.rows();
    let cols = app.ui.cols();
    let y = rows - 2;
    let w = (cols - 4) as usize;
    let mut buf: Vec<char> = init.chars().collect();
    let mut cur = buf.len();
    let mut ofs = 0usize;
    let mut hist = app.history.len();
    app.ui.open_dialog();
    app.ui.frame(1, rows - 3, cols - 2, 1, 11, 3, true, false);
    app.ui.window(1, 1, cols, rows);
    app.ui.write_xyfb(1, rows, 0, 3, &panel::fit(HELP, cols as usize - 1));
    let run = loop {
        if cur < ofs {
            ofs = cur;
        }
        if cur > ofs + w - 1 {
            ofs = cur + 1 - w;
        }
        let vis: String = buf.iter().skip(ofs).take(w).collect();
        app.ui.write_xyfb(3, y, 15, 3, &panel::fit(&vis, w));
        app.ui.write_xyfb(2, y, 14, 3, if ofs > 0 { "◄" } else { " " });
        app.ui.write_xyfb(cols - 1, y, 14, 3, if ofs + w < buf.len() { "►" } else { " " });
        app.ui.goto_xy(3 + (cur - ofs) as i32, y);
        app.ui.cursor_visible = true;
        let k = app.ui.get_key();
        if k == 0 {
            if app.ui.mouse.button == 2 {
                app.ui.wait_release();
                break false;
            }
            continue;
        }
        let insert = |s: &str, buf: &mut Vec<char>, cur: &mut usize| {
            for c in s.chars() {
                buf.insert(*cur, c);
                *cur += 1;
            }
        };
        let a = app.act;
        match k {
            ENTER => break true,
            ESC | F10 => break false,
            LEFT => cur = cur.saturating_sub(1),
            RIGHT => cur = (cur + 1).min(buf.len()),
            HOME => cur = 0,
            END => cur = buf.len(),
            BKSP => {
                if cur > 0 {
                    cur -= 1;
                    buf.remove(cur);
                }
            }
            DEL => {
                if cur < buf.len() {
                    buf.remove(cur);
                }
            }
            CTRL_LEFT => {
                while cur > 0 && buf[cur - 1] == ' ' {
                    cur -= 1;
                }
                while cur > 0 && buf[cur - 1] != ' ' {
                    cur -= 1;
                }
            }
            CTRL_RIGHT => {
                while cur < buf.len() && buf[cur] != ' ' {
                    cur += 1;
                }
                while cur < buf.len() && buf[cur] == ' ' {
                    cur += 1;
                }
            }
            UP | DOWN if !app.ui.shift => {
                if k == UP && hist > 0 {
                    hist -= 1;
                } else if k == DOWN && hist < app.history.len() {
                    hist += 1;
                } else {
                    continue;
                }
                buf = app.history.get(hist).map_or(vec![], |s| s.chars().collect());
                cur = buf.len();
            }
            DOWN => {
                app.ui.pop_screen();
                app.ui.open_dialog();
                if let Some(i) = pick_history(app) {
                    buf = app.history[i].chars().collect();
                    cur = buf.len();
                }
                app.ui.frame(1, rows - 3, cols - 2, 1, 11, 3, true, false);
                app.ui.window(1, 1, cols, rows);
                app.ui.write_xyfb(1, rows, 0, 3, &panel::fit(HELP, cols as usize - 1));
            }
            4 => {
                if let Some(e) = app.p[a].current() {
                    let s = shell_quote(&e.name);
                    insert(&format!("{s} "), &mut buf, &mut cur);
                }
            }
            16 | 1 => {
                let p = if k == 16 { a } else { 1 - a };
                let s = shell_quote(&app.p[p].path.display().to_string());
                insert(&format!("{s}/"), &mut buf, &mut cur);
            }
            CTRL_END => buf.truncate(cur),
            11 => buf.truncate(cur), // ^K
            25 => {
                buf.clear();
                cur = 0;
            }
            k => {
                if let Some(c) = Key::new(k).char() {
                    if app.ui.ins_mode || cur >= buf.len() {
                        buf.insert(cur, c);
                    } else {
                        buf[cur] = c;
                    }
                    cur += 1;
                } else if k == INS {
                    app.ui.ins_mode = !app.ui.ins_mode;
                }
            }
        }
    };
    app.ui.cursor_visible = false;
    app.ui.pop_screen();
    let cmd: String = buf.into_iter().collect();
    let cmd = cmd.trim().to_string();
    if run && !cmd.is_empty() {
        app.add_history(&cmd);
        if let Some(dir) = cd_target(&cmd) {
            let base = app.p[app.act].path.clone();
            let p = crate::ops::resolve(&base, &dir);
            if !app.p[app.act].chdir(&p) {
                crate::dlg::info(&mut app.ui, "cd", &[format!("{}: no such directory", p.display())]);
            }
            app.redraw();
        } else if cmd == "exit" {
            app.quit = true;
        } else {
            app.run(&cmd, true);
        }
    }
}

/// `cd DIR` is done by the panel, like DX's internal CD.
fn cd_target(cmd: &str) -> Option<String> {
    if cmd == "cd" {
        return Some("~".into());
    }
    let rest = cmd.strip_prefix("cd ")?.trim();
    if rest.contains(['&', ';', '|']) {
        return None;
    }
    let r = rest.trim_matches(|c| c == '\'' || c == '"');
    Some(r.to_string())
}

fn pick_history(app: &mut App) -> Option<usize> {
    let lines: Vec<String> = app.history.clone();
    let n = lines.len();
    crate::dlg::list(&mut app.ui, "Command history", &lines, n.saturating_sub(1))
}

/// Alt-B: history list; Return runs the command (Ctrl-Return edits it).
pub fn history_list(app: &mut App) {
    if let Some(i) = pick_history(app) {
        let cmd = app.history[i].clone();
        command_line(app, &cmd);
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn cd() {
        assert_eq!(super::cd_target("cd /tmp").as_deref(), Some("/tmp"));
        assert_eq!(super::cd_target("cd x && ls"), None);
        assert_eq!(super::cd_target("cdx"), None);
    }
}
