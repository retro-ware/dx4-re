//! Starting a menu entry: the optional change into the program's directory (WriteStart / dxstart.bat in
//! the original) and the "wait before return" pause.

use crate::menu::Item;
use std::path::{Path, PathBuf};
use std::process::Command;

/// First shell word of `s` with quotes and backslashes resolved, and the rest of the line after it.
fn first_word(s: &str) -> (String, &str) {
    let s = s.trim_start();
    let mut word = String::new();
    let mut quote: Option<char> = None;
    let mut it = s.char_indices().peekable();
    while let Some((i, c)) = it.next() {
        match (quote, c) {
            (Some(q), c) if c == q => quote = None,
            (Some('"'), '\\') if matches!(it.peek(), Some((_, '"' | '\\' | '$' | '`'))) => {
                word.push(it.next().unwrap().1);
            }
            (Some(_), c) => word.push(c),
            (None, '\'' | '"') => quote = Some(c),
            (None, '\\') => {
                if let Some((_, n)) = it.next() {
                    word.push(n);
                }
            }
            (None, c) if c.is_whitespace() => return (word, &s[i..]),
            (None, c) => word.push(c),
        }
    }
    (word, "")
}

/// `~`, `~/x`, `$HOME/x` and `${HOME}/x` at the start of a word, as the shell would expand them.
fn expand_home(w: &str) -> String {
    let home = std::env::var("HOME").unwrap_or_default();
    for p in ["~", "${HOME}", "$HOME"] {
        if let Some(rest) = w.strip_prefix(p)
            && (rest.is_empty() || rest.starts_with('/'))
        {
            return format!("{home}{rest}");
        }
    }
    w.to_string()
}

fn shell_quote(s: &str) -> String {
    if s.chars().all(|c| c.is_ascii_alphanumeric() || "._-+/=:,@%".contains(c)) {
        s.to_string()
    } else {
        format!("'{}'", s.replace('\'', "'\\''"))
    }
}

/// How to start an entry.
#[derive(Debug, PartialEq)]
pub struct Plan {
    /// Command line for `sh -c`.
    pub cmd: String,
    /// Directory to start in; None keeps the current one.
    pub dir: Option<PathBuf>,
    /// Why the requested directory change was not possible.
    pub warning: Option<String>,
}

/// With `chdir`, the program (first word of the command) is started from its own directory. The program
/// path is made absolute first, because a relative one would no longer be valid after the change.
/// A bare command name (found through PATH) has no directory of its own and runs where it is.
pub fn plan(prog: &str, chdir: bool, cwd: &Path) -> Plan {
    let same = Plan { cmd: prog.to_string(), dir: None, warning: None };
    if !chdir {
        return same;
    }
    let (word, rest) = first_word(prog);
    let word = expand_home(&word);
    if !word.contains('/') {
        return same;
    }
    if word.contains(['$', '`']) {
        return Plan { warning: Some(format!("cannot tell the directory of {word}")), ..same };
    }
    let exe = cwd.join(&word);
    match exe.parent().filter(|d| d.is_dir()) {
        Some(d) => Plan {
            cmd: format!("{}{rest}", shell_quote(&exe.to_string_lossy())),
            dir: Some(d.to_path_buf()),
            warning: None,
        },
        None => {
            let d = exe.parent().unwrap_or(&exe).display().to_string();
            Plan { warning: Some(format!("directory {d} does not exist")), ..same }
        }
    }
}

/// Lets the output of the program be read before the menu comes back; any key continues.
pub fn wait_key() {
    use crossterm::event::{self, Event, KeyEventKind};
    use std::io::{BufRead, Write};
    print!("\nPress any key to continue...");
    let _ = std::io::stdout().flush();
    if crossterm::terminal::enable_raw_mode().is_ok() {
        while let Ok(ev) = event::read() {
            if matches!(ev, Event::Key(k) if k.kind != KeyEventKind::Release) {
                break;
            }
        }
        let _ = crossterm::terminal::disable_raw_mode();
    } else {
        let _ = std::io::stdin().lock().read_line(&mut String::new());
    }
    println!();
}

/// Runs a menu entry through the shell, then pauses if the entry asks for it. A start that failed
/// (directory missing, program not found or not executable) always pauses, so the message stays readable.
pub fn run(item: &Item) {
    let cwd = std::env::current_dir().unwrap_or_default();
    let plan = plan(&item.prog, item.chdir, &cwd);
    let mut failed = false;
    println!("{}$ {}", plan.dir.as_ref().unwrap_or(&cwd).display(), item.prog);
    if let Some(w) = &plan.warning {
        println!("dxm: {w}");
        failed = true;
    }
    let mut c = Command::new("sh");
    c.arg("-c").arg(&plan.cmd);
    if let Some(d) = &plan.dir {
        c.current_dir(d);
    }
    match c.status() {
        Err(e) => {
            println!("dxm: {}: {e}", item.prog);
            failed = true;
        }
        Ok(st) if matches!(st.code(), Some(126 | 127)) => failed = true,
        Ok(_) => {}
    }
    if item.wait || failed {
        wait_key();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn words() {
        assert_eq!(first_word("  /bin/ls -l"), ("/bin/ls".into(), " -l"));
        assert_eq!(first_word("\"/a b/c\" x"), ("/a b/c".into(), " x"));
        assert_eq!(first_word("/a\\ b/c"), ("/a b/c".into(), ""));
        assert_eq!(first_word("'/a b'/c d"), ("/a b/c".into(), " d"));
        assert_eq!(first_word(""), (String::new(), ""));
    }

    #[test]
    fn plan_makes_the_program_absolute() {
        let base = std::env::temp_dir().join(format!("dxm-launch-{}", std::process::id()));
        let game = base.join("my game");
        std::fs::create_dir_all(&game).unwrap();
        // relative to the current directory: still valid after the change
        let p = plan("\"my game/run.sh\" -x", true, &base);
        assert_eq!(p.dir.as_deref(), Some(game.as_path()));
        assert_eq!(p.cmd, format!("'{}/run.sh' -x", game.display()));
        assert_eq!(p.warning, None);
        // quoted path with a space
        let p = plan(&format!("\"{}/run.sh\"", game.display()), true, Path::new("/"));
        assert_eq!(p.dir.as_deref(), Some(game.as_path()));
        // switched off, bare command, missing directory
        assert_eq!(plan("my game/run.sh", false, &base).dir, None);
        assert_eq!(plan("ls -l", true, &base), Plan { cmd: "ls -l".into(), dir: None, warning: None });
        let p = plan("nowhere/run.sh", true, &base);
        assert_eq!((p.dir, p.cmd.as_str()), (None, "nowhere/run.sh"));
        assert!(p.warning.unwrap().contains("does not exist"));
        std::fs::remove_dir_all(&base).unwrap();
    }

    #[test]
    fn plan_expands_home() {
        let home = std::env::var("HOME").unwrap();
        let p = plan("~/x.sh", true, Path::new("/"));
        assert_eq!(p.dir, Some(PathBuf::from(&home)));
        let p = plan("$HOME/x.sh", true, Path::new("/"));
        assert_eq!(p.dir, Some(PathBuf::from(&home)));
        assert!(plan("$OTHER/x.sh", true, Path::new("/")).warning.is_some());
    }
}
