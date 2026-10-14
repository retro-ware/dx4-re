//! Push buttons (Buttons unit): a caption in a thin 3D frame that looks pressed while held.
//! Positions are relative to the window active when the button is drawn or polled, as in the original.

use crate::keys::*;
use crate::ui::Ui;
use crate::Crt;

#[derive(Clone, Debug)]
pub struct Button {
    pub x: i32,
    pub y: i32,
    pub hot_fg: u8,
    pub fg: u8,
    pub light: u8,
    pub bg: u8,
    pub pressed: bool,
    pub focused: bool,
    old_pressed: bool,
    old_focused: bool,
    pub caption: String,
    clicked: bool,
    pub save_focus: bool,
}

impl Button {
    /// InitButton without drawing.
    #[allow(clippy::too_many_arguments)]
    pub fn new(focus: bool, x: i32, y: i32, hot_fg: u8, fg: u8, light: u8, bg: u8, caption: &str) -> Button {
        Button {
            x,
            y,
            hot_fg,
            fg,
            light,
            bg,
            pressed: false,
            old_pressed: true,
            focused: focus,
            old_focused: !focus,
            caption: format!(" {caption} "),
            clicked: false,
            save_focus: focus,
        }
    }

    pub fn len(&self) -> i32 {
        self.caption.chars().count() as i32
    }

    /// DrawButton (thin variant): redraws only when focus or pressed state changed.
    pub fn draw(&mut self, c: &mut Crt) {
        if self.old_focused == self.focused && self.old_pressed == self.pressed {
            return;
        }
        self.redraw(c);
    }

    /// Draws unconditionally.
    pub fn redraw(&mut self, c: &mut Crt) {
        let attr = c.text_attr;
        self.old_focused = self.focused;
        self.old_pressed = self.pressed;
        let (mut dark, mut lit) = (0, 0);
        let text = if self.focused { self.hot_fg } else { self.fg };
        let (l, r): (&[u8], &[u8]) = if self.pressed {
            lit = self.light;
            (b" ", b"")
        } else {
            dark = self.light;
            (b"", b" ")
        };
        let n = self.len() as usize;
        c.set_color(dark, self.bg);
        c.write_xy_b(self.x, self.y, &[l, b"\xDA"].concat());
        c.write_b(&vec![0xC4; n]);
        c.text_color(lit);
        c.write_b(&[b"\xBF", r].concat());
        c.text_color(dark);
        c.write_xy_b(self.x, self.y + 1, &[l, b"\xB3"].concat());
        c.write_f(text, &self.caption);
        c.text_color(lit);
        c.write_b(&[b"\xB3", r].concat());
        c.text_color(dark);
        c.write_xy_b(self.x, self.y + 2, &[l, b"\xC0"].concat());
        c.text_color(lit);
        c.write_b(&vec![0xC4; n]);
        c.write_b(&[b"\xD9", r].concat());
        c.text_attr = attr;
    }

    /// Buttons.MouseButton: true when the button was clicked (pressed and released on it). The first poll
    /// with the button held only focuses it ("armed"); the next one presses it.
    pub fn mouse_button(&mut self, ui: &mut Ui) -> bool {
        let (wx, wy, _, _) = ui.win();
        let x1 = self.x + wx;
        let x2 = x1 + self.len();
        let y = self.y + wy;
        let m = ui.mouse;
        let mut hit = false;
        if m.button == 1 && y == m.y && x1 < m.x && x2 > m.x {
            if self.clicked {
                self.pressed = true;
                self.clicked = false;
                self.draw(ui);
                loop {
                    let m = ui.mouse;
                    if m.button == 0 || y != m.y || x1 >= m.x || x2 < m.x {
                        break;
                    }
                    ui.pump();
                    if ui.term.is_none() {
                        ui.mouse.button = 0;
                    }
                }
                let m = ui.mouse;
                hit = y == m.y && x1 < m.x && x2 + 1 > m.x;
                self.pressed = false;
                self.draw(ui);
            } else {
                self.clicked = true;
            }
            self.focused = true;
        }
        self.save_focus = self.focused;
        hit
    }

    fn force(&mut self) {
        self.old_focused = !self.focused;
    }
}

/// A row of buttons handled together (TButton2/3/4).
pub struct Buttons(pub Vec<Button>);

impl std::ops::Index<usize> for Buttons {
    type Output = Button;
    fn index(&self, i: usize) -> &Button {
        &self.0[i]
    }
}

impl std::ops::IndexMut<usize> for Buttons {
    fn index_mut(&mut self, i: usize) -> &mut Button {
        &mut self.0[i]
    }
}

impl Buttons {
    /// InitButton2/3/4: the first button focused if `first`, otherwise the second.
    #[allow(clippy::too_many_arguments)]
    pub fn new(c: &mut Crt, first: bool, pos: &[(i32, i32)], hot_fg: u8, fg: u8, light: u8, bg: u8, caps: &[&str])
        -> Buttons {
        let mut v: Vec<Button> = pos
            .iter()
            .zip(caps)
            .enumerate()
            .map(|(i, (&(x, y), cap))| {
                let f = if first { i == 0 } else { i == 1 };
                Button::new(f, x, y, hot_fg, fg, light, bg, cap)
            })
            .collect();
        for b in &mut v {
            b.redraw(c);
        }
        Buttons(v)
    }

    pub fn draw(&mut self, c: &mut Crt) {
        for b in &mut self.0 {
            b.draw(c);
        }
    }

    /// RestoreButtonN: focus as before ResetButtonN.
    pub fn restore(&mut self, c: &mut Crt) {
        for b in &mut self.0 {
            b.focused = b.save_focus;
            b.force();
        }
        self.draw(c);
    }

    /// ResetButtonN: no button focused (while an input line has the focus).
    pub fn reset(&mut self, c: &mut Crt) {
        for b in &mut self.0 {
            b.old_focused = true;
            b.focused = false;
        }
        self.draw(c);
    }

    /// SetButton3: focus button `n` (0-based) when restored.
    pub fn set(&mut self, c: &mut Crt, n: usize) {
        for (i, b) in self.0.iter_mut().enumerate() {
            b.save_focus = i == n;
        }
        self.restore(c);
    }

    /// HandleButton2/3/4: polls the mouse and one key. Returns which button was hit; `key` is the key read.
    /// Two buttons: Tab (after Tab) toggles, Left/Right select. More: Left/Right rotate the focus.
    pub fn handle(&mut self, ui: &mut Ui, key: &mut u16) -> Option<usize> {
        let old = *key;
        let n = self.0.len();
        let mut hit = None;
        for i in 0..n {
            if self.0[i].mouse_button(ui) {
                hit = Some(i);
            }
            if n == 2 {
                let f = self.0[i].focused;
                self.0[1 - i].focused = !f;
            } else if self.0[i].focused {
                for j in 0..n {
                    if j != i {
                        self.0[j].focused = false;
                    }
                }
            }
        }
        *key = ui.get_key();
        if n == 2 {
            if old == TAB {
                if *key == TAB {
                    self.0[0].focused = !self.0[0].focused;
                    self.0[1].focused = !self.0[1].focused;
                }
            } else {
                if *key == RIGHT {
                    self.0[0].focused = false;
                    self.0[1].focused = true;
                }
                if *key == LEFT {
                    self.0[0].focused = true;
                    self.0[1].focused = false;
                }
            }
        } else if *key == RIGHT {
            let f: Vec<bool> = self.0.iter().map(|b| b.focused).collect();
            for i in 0..n {
                self.0[i].focused = f[(i + n - 1) % n];
            }
        } else if *key == LEFT {
            let f: Vec<bool> = self.0.iter().map(|b| b.focused).collect();
            for i in 0..n {
                self.0[i].focused = f[(i + 1) % n];
            }
        }
        if *key == ENTER {
            for (i, b) in self.0.iter_mut().enumerate() {
                if b.focused {
                    hit = Some(i);
                    b.pressed = true;
                }
            }
        }
        self.draw(ui);
        if *key == ENTER {
            ui.flush();
            if ui.term.is_some() {
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
            for b in &mut self.0 {
                b.pressed = false;
            }
            self.draw(ui);
        }
        hit
    }
}
