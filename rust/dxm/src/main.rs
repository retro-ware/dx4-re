//! DXM — the DOS-Expander 4.0 program menu, ported to a terminal app.
//! Spec: src/dxm/DXM.PAS (main program).
//!
//! Usage: dxm [DIR]   DIR holds dxmenu.dat and dx.ini (default: the directory of the executable).

mod app;
mod config;
mod cp437;
mod menu;
mod picker;
mod ui;

use app::{App, Outcome};
use config::{Config, MenuPos};
use crossterm::event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyEventKind};
use crossterm::execute;
use menu::{Item, Menu};
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

fn home_dir() -> PathBuf {
    if let Some(d) = std::env::args_os().nth(1) {
        return d.into();
    }
    std::env::current_exe().ok().and_then(|p| p.parent().map(Path::to_path_buf)).unwrap_or_else(|| ".".into())
}

/// Runs one menu session until the user quits or picks a program.
fn menu_session(home: &Path, pos: MenuPos) -> io::Result<(Option<Item>, MenuPos)> {
    let menu = Menu::load(&home.join("dxmenu.dat")).ok();
    let pick_dir = std::env::current_dir().unwrap_or_else(|_| home.to_path_buf());
    let mut app = App::new(menu, pos, home.join("dxmenu.dat"), pick_dir);
    let mut term = ratatui::init();
    execute!(io::stdout(), EnableMouseCapture)?;
    let result = loop {
        term.draw(|f| ui::draw(f, &mut app))?;
        let outcome = match event::read()? {
            Event::Key(k) if k.kind != KeyEventKind::Release => app.key(k),
            Event::Mouse(m) => app.mouse(m),
            _ => None,
        };
        if app.quit_now {
            break None;
        }
        match outcome {
            Some(Outcome::Quit) => break None,
            Some(Outcome::Run(item)) => break Some(item),
            None => {}
        }
    };
    execute!(io::stdout(), DisableMouseCapture)?;
    ratatui::restore();
    Ok((result, app.pos()))
}

/// Starts the program in its own directory and waits for it (the original did this via dxstart.bat).
fn launch(item: &Item) {
    let prog = Path::new(&item.prog);
    let mut cmd = Command::new(prog);
    if let Some(dir) = prog.parent().filter(|d| !d.as_os_str().is_empty()) {
        cmd.current_dir(dir);
    }
    if let Err(e) = cmd.status() {
        eprintln!("{}: {e}", item.prog);
        eprintln!("Weiter mit Return...");
        let _ = io::stdin().read_line(&mut String::new());
    }
}

fn main() -> io::Result<()> {
    let home = home_dir();
    let ini = home.join(config::INI_NAME);
    let mut cfg = Config::load(&ini);
    let mut pos = cfg.as_ref().map_or(MenuPos { group: 0, item: 0 }, Config::menu_pos);
    loop {
        let (run, new_pos) = menu_session(&home, pos)?;
        pos = new_pos;
        if let Some(c) = cfg.as_mut() {
            c.set_menu_pos(pos);
            let _ = c.save(&ini);
        }
        match run {
            Some(item) => launch(&item),
            None => return Ok(()),
        }
    }
}
