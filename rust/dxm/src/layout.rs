//! Geometry of the main screen for the size of the terminal.
//!
//! The original screen is 80x25: group bar, a frame of 72x21 with 3x7 buttons of three lines each, and a
//! hint line. In a smaller terminal the logical screen shrinks to the terminal: the buttons get narrower
//! (the captions are shortened) and, when fewer than 25 rows are available, shrink to one line each.
//! A larger terminal keeps the 80x25 screen centred, because the dialogs are laid out for exactly that.

use dxtui::center;

pub const MIN_W: i32 = 44;
pub const MIN_H: i32 = 11;
/// Width of a caption in the original layout (the length of an entry name).
pub const NAME_W: i32 = 18;

#[derive(Clone, Debug, PartialEq)]
pub struct Layout {
    /// Logical screen size.
    pub w: i32,
    pub h: i32,
    /// Buttons with a three-line border (the original look), or single lines `[Name]` when rows are short.
    pub boxed: bool,
    /// Width of the caption inside a button.
    pub name_w: i32,
    /// Column of each of the 3 button columns and row of each of the 7 button rows, relative to the frame's
    /// inner area (1-based, the top-left corner of a button).
    pub x: [i32; 3],
    pub y: [i32; 7],
}

impl Layout {
    pub fn new(term_w: i32, term_h: i32) -> Layout {
        let w = term_w.clamp(MIN_W, 80);
        let h = term_h.clamp(MIN_H, 25);
        // Inner size of the frame: 4 columns on the left (F-key labels), 3 on the right, rows 2..h-2.
        let (fw, fh) = (w - 8, h - 4);
        let boxed = fh >= 21;
        let border = if boxed { 4 } else { 2 };
        let name_w = ((fw - 6) / 3 - border).clamp(4, NAME_W);
        let bw = name_w + border;
        let free = fw - 3 * bw;
        let margin = free / 6;
        let gap = (free - 2 * margin) / 2;
        let pitch = if boxed { 3 } else { (fh / 7).clamp(1, 3) };
        let used = 6 * pitch + if boxed { 3 } else { 1 };
        let top = (fh - used) / 2;
        Layout {
            w,
            h,
            boxed,
            name_w,
            x: [0, 1, 2].map(|j| 1 + margin + j * (bw + gap)),
            y: [0, 1, 2, 3, 4, 5, 6].map(|i| 1 + top + i * pitch),
        }
    }

    /// Inner size of the frame around the buttons.
    pub fn frame(&self) -> (i32, i32) {
        (self.w - 8, self.h - 4)
    }

    /// Column and row of button `i` (1..=21; 7 per column), relative to the frame's inner area.
    pub fn pos(&self, i: usize) -> (i32, i32) {
        (self.x[(i - 1) / 7], self.y[(i - 1) % 7])
    }

    /// Width of a button including its border.
    pub fn button_w(&self) -> i32 {
        self.name_w + if self.boxed { 4 } else { 2 }
    }

    /// Screen row of the caption line of button `i`.
    pub fn text_row(&self, i: usize) -> i32 {
        2 + self.pos(i).1 + self.boxed as i32
    }

    /// Screen columns (first, last) of the caption cells of button `i`.
    pub fn text_cols(&self, i: usize) -> (i32, i32) {
        let x = self.pos(i).0 + 4 + self.boxed as i32;
        (x, x + self.name_w + 1)
    }

    /// Button at a screen position, if any.
    pub fn button_at(&self, mx: i32, my: i32) -> Option<usize> {
        (1..=21).find(|&i| {
            let (a, b) = self.text_cols(i);
            my == self.text_row(i) && (a..=b).contains(&mx)
        })
    }

    /// Column of the admin label.
    pub fn admin_x(&self) -> i32 {
        self.w - 12
    }

    /// Columns of the hint line texts (F1..F7, Alt-F1..F7, Ctrl-F1..F7); the 80-column positions are
    /// scaled, and texts that would run into each other are dropped.
    pub fn hints(&self) -> Vec<(i32, &'static str)> {
        let mut v: Vec<(i32, &'static str)> = vec![];
        let mut end = 9;
        for (x, t) in [(15, "F1..F7"), (36, "Alt-F1..F7"), (58, "Ctrl-F1..F7")] {
            let x = 3 + (x - 3) * (self.w - 3) / 77;
            if x > end && x + t.len() as i32 + 1 < self.w - 6 {
                v.push((x, t));
                end = x + t.len() as i32;
            }
        }
        v
    }
}

/// A caption of exactly `w` columns: the name centred, or cut off if it is too long.
pub fn caption(name: &str, w: i32) -> String {
    center(&name.chars().take(w as usize).collect::<String>(), w)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn full_size_is_the_original_screen() {
        let l = Layout::new(80, 25);
        assert!(l.boxed);
        assert_eq!((l.w, l.h, l.name_w, l.button_w()), (80, 25, 18, 22));
        assert_eq!(l.x, [2, 26, 50]);
        assert_eq!(l.y, [1, 4, 7, 10, 13, 16, 19]);
        assert_eq!(l.admin_x(), 68);
        assert_eq!(l.hints(), vec![(15, "F1..F7"), (36, "Alt-F1..F7"), (58, "Ctrl-F1..F7")]);
        assert_eq!((l.text_row(1), l.text_row(7), l.text_cols(1), l.text_cols(15)), (4, 22, (7, 26), (55, 74)));
        assert_eq!(l.button_at(8, 4), Some(1));
        assert_eq!(l.button_at(8, 5), None);
        assert_eq!(l.button_at(60, 22), Some(21));
    }

    #[test]
    fn a_larger_terminal_keeps_80x25() {
        assert_eq!(Layout::new(200, 60), Layout::new(80, 25));
    }

    #[test]
    fn smaller_terminals_fit_inside_the_frame() {
        for w in MIN_W - 5..=90 {
            for h in MIN_H - 3..=30 {
                let l = Layout::new(w, h);
                let (fw, fh) = l.frame();
                let bh = if l.boxed { 3 } else { 1 };
                assert!(l.name_w >= 4 && l.name_w <= NAME_W, "{w}x{h}");
                for i in 1..=21 {
                    let (x, y) = l.pos(i);
                    assert!(x >= 1 && x + l.button_w() - 1 <= fw, "{w}x{h} button {i} x={x} bw={}", l.button_w());
                    assert!(y >= 1 && y + bh - 1 <= fh, "{w}x{h} button {i} y={y}");
                }
                for j in 0..2 {
                    assert!(l.x[j] + l.button_w() < l.x[j + 1], "{w}x{h} columns touch");
                }
                for j in 0..6 {
                    assert!(l.y[j] + bh <= l.y[j + 1], "{w}x{h} rows touch");
                }
                assert!(l.w <= w.max(MIN_W) && l.h <= h.max(MIN_H));
            }
        }
    }

    #[test]
    fn captions_are_cut_to_the_width() {
        assert_eq!(caption("Hello", 9), "  Hello  ");
        assert_eq!(caption("Wolfenstein 3D", 6), "Wolfen");
    }
}
