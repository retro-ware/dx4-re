//! Screen saver (Saver.ScreenSaver, star variant) with the optional password check (CheckPassword).
//! Spec: src/dxm/SAVER.PAS.

use crate::Dxm;
use dxtui::keys::*;
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

impl Dxm {
    /// Waits `ms` milliseconds; true when a key or mouse button ended the wait early.
    fn saver_wait(&mut self, ms: u64) -> bool {
        let start = Instant::now();
        while start.elapsed() < Duration::from_millis(ms) {
            self.ui.flush();
            if let Some(k) = self.ui.crt.poll_key(10) {
                self.ui.crt.queue.push_back(k);
                return true;
            }
            if self.ui.mouse.button != 0 {
                return true;
            }
        }
        false
    }

    fn burst(&mut self, s: &mut Star) -> bool {
        if !s.visible {
            return false;
        }
        s.visible = false;
        let steps: [(u8, u8, u64); 4] = [(11, 0xF9, 300), (11, 4, 300), (2, b'*', 300), (2, 15, 600)];
        for (fg, ch, ms) in steps {
            self.ui.text_color(fg);
            self.ui.write_xy_b(s.x, s.y, &[ch]);
            if self.saver_wait(ms) {
                self.ui.write_xy(s.x, s.y, " ");
                return true;
            }
        }
        self.ui.write_xy(s.x, s.y, " ");
        self.ui.text_color(11);
        false
    }

    /// CheckPassword: true when there is no password or the right one was typed.
    fn check_password(&mut self) -> bool {
        while self.ui.get_key() != 0 {}
        if self.password.is_empty() {
            return true;
        }
        self.ui.open_dialog();
        self.ui.frame(20, 8, 40, 7, 11, 3, false, true);
        self.ui.write_center_xy(1, 2, 40, "Activate program:");
        self.ui.write_center_xy(1, 4, 40, "Please enter the password:");
        self.ui.write_xyb(15, 6, 2, "            ");
        let mut p = String::new();
        loop {
            self.ui.write_xyb(15, 6, 2, &format!("{:<12}", "*".repeat(p.chars().count())));
            self.ui.goto_xy(15 + p.chars().count().min(11) as i32, 6);
            self.ui.cursor_visible = true;
            match self.ui.get_key() {
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
        self.ui.cursor_visible = false;
        self.ui.pop_screen();
        self.ui.wait_release();
        if p == self.password {
            true
        } else {
            self.ui.write_xyfb(20, 10, 7, 0, "Wrong password entered!");
            false
        }
    }

    /// ScreenSaver: stars on a black screen until a key or click, then the password check.
    pub fn screen_saver(&mut self) {
        self.ui.open_dialog();
        let rows = self.ui.rows();
        let cols = self.ui.cols();
        self.ui.window(1, 1, cols, rows);
        self.ui.set_color(11, 0);
        self.ui.clr_scr();
        self.ui.wait_release();
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
                self.ui.text_color(11);
                let (x, y, ch) = (stars[i].x, stars[i].y, stars[i].ch);
                self.ui.write_xy_b(x, y, &[ch]);
                stars[i].visible = true;
            }
            let mut hit = self.saver_wait(200);
            if !hit {
                let j = rng.below(60) as usize;
                let mut s = stars[j];
                hit = self.burst(&mut s);
                stars[j] = s;
            }
            if hit {
                self.ui.wait_release();
                if self.check_password() {
                    break;
                }
            }
        }
        self.ui.pop_screen();
        self.ui.reset_idle();
    }
}
