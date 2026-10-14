//! Screen saver (Saver.ScreenSaver, star variant) with the optional password check (CheckPassword).
//! Spec: src/dxm/SAVER.PAS.

use crate::keys::*;
use crate::ui::Ui;
use std::time::{Duration, Instant, SystemTime};

#[derive(Clone, Copy, Default)]
struct Star {
x: i32,
y: i32,
ch: u8,
visible: bool,
}

/// Small xorshift generator; the saver needs no real randomness.
struct Rng(u64);

impl Rng {
fn new() -> Rng {
    let t = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).map_or(1, |d| d.as_nanos() as u64);
    Rng(t | 1)
}

fn below(&mut self, n: i32) -> i32 {
    self.0 ^= self.0 << 13;
    self.0 ^= self.0 >> 7;
    self.0 ^= self.0 << 17;
    (self.0 % n.max(1) as u64) as i32
}
}

/// Waits `ms` milliseconds; true when a key or mouse button ended the wait early.
fn saver_wait(ui: &mut Ui, ms: u64) -> bool {
    let start = Instant::now();
    while start.elapsed() < Duration::from_millis(ms) {
        ui.flush();
        if let Some(k) = ui.crt.poll_key(10) {
            ui.crt.queue.push_back(k);
            return true;
        }
        if ui.mouse.button != 0 {
            return true;
        }
    }
    false
}

fn burst(ui: &mut Ui, s: &mut Star) -> bool {
    if !s.visible {
        return false;
    }
    s.visible = false;
    let steps: [(u8, u8, u64); 4] = [(11, 0xF9, 300), (11, 4, 300), (2, b'*', 300), (2, 15, 600)];
    for (fg, ch, ms) in steps {
        ui.text_color(fg);
        ui.write_xy_b(s.x, s.y, &[ch]);
        if saver_wait(ui, ms) {
            ui.write_xy(s.x, s.y, " ");
            return true;
        }
    }
    ui.write_xy(s.x, s.y, " ");
    ui.text_color(11);
    false
}

/// CheckPassword: true when there is no password or the right one was typed.
fn check_password(ui: &mut Ui, password: &str) -> bool {
    while ui.get_key() != 0 {}
    if password.is_empty() {
        return true;
    }
    ui.open_dialog();
    ui.frame(20, 8, 40, 7, 11, 3, false, true);
    ui.write_center_xy(1, 2, 40, "Activate program:");
    ui.write_center_xy(1, 4, 40, "Please enter the password:");
    ui.write_xyb(15, 6, 2, "            ");
    let mut p = String::new();
    loop {
        ui.write_xyb(15, 6, 2, &format!("{:<12}", "*".repeat(p.chars().count())));
        ui.goto_xy(15 + p.chars().count().min(11) as i32, 6);
        ui.cursor_visible = true;
        match ui.get_key() {
            0 => {}
            ENTER => break,
            ESC => {
                p.clear();
                break;
            }
            BKSP => {
                p.pop();
            }
            k if (32..256).contains(&k) && p.chars().count() < 12 => p.push(char::from(k as u8)),
            _ => {}
        }
    }
    ui.cursor_visible = false;
    ui.pop_screen();
    ui.wait_release();
    if p == *password {
        true
    } else {
        ui.write_xyfb(20, 10, 7, 0, "Wrong password entered!");
        false
    }
}

/// ScreenSaver: stars on a black screen until a key or click, then the password check.
pub fn screen_saver(ui: &mut Ui, password: &str) {
    ui.open_dialog();
    let rows = ui.rows();
    let cols = ui.cols();
    ui.window(1, 1, cols, rows);
    ui.set_color(11, 0);
    ui.clr_scr();
    ui.wait_release();
    let mut rng = Rng::new();
    let mut stars = [Star::default(); 60];
    for (i, s) in stars.iter_mut().enumerate() {
        s.ch = if i % 2 == 0 { 0xFA } else { 0xF9 };
    }
    loop {
        let i = rng.below(60) as usize;
        if !stars[i].visible {
            stars[i].x = rng.below(cols - 1) + 1;
            stars[i].y = rng.below(rows) + 1;
            ui.text_color(11);
            let (x, y, ch) = (stars[i].x, stars[i].y, stars[i].ch);
            ui.write_xy_b(x, y, &[ch]);
            stars[i].visible = true;
        }
        let mut hit = saver_wait(ui, 200);
        if !hit {
            let j = rng.below(60) as usize;
            let mut s = stars[j];
            hit = burst(ui, &mut s);
            stars[j] = s;
        }
        if hit {
            ui.wait_release();
            if check_password(ui, password) {
                break;
            }
        }
    }
    ui.pop_screen();
    ui.reset_idle();
}
