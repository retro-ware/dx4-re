//! Keys in the encoding of DX `GetKey`: the ASCII code, or 1000 + scan code for keys without one.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Key {
    pub code: u16,
    pub alt: bool,
    pub shift: bool,
    pub ctrl: bool,
}

impl Key {
    pub fn new(code: u16) -> Key {
        Key { code, alt: false, shift: false, ctrl: false }
    }

    /// The typed character for printable keys (CP437 code as char via `cp437::decode`).
    pub fn char(&self) -> Option<char> {
        (self.code >= 32 && self.code < 256 && self.code != 127)
            .then(|| crate::cp437::decode(&[self.code as u8]).chars().next().unwrap())
    }
}

/// Pseudo key for scripted tests: `Crt::poll_key` records the screen in `Crt::snaps` instead.
pub const SNAPSHOT: u16 = 0xFFFF;
pub const ESC: u16 = 27;
pub const ENTER: u16 = 13;
pub const TAB: u16 = 9;
pub const BKSP: u16 = 8;
pub const SHIFT_TAB: u16 = 1015;
pub const F1: u16 = 1059;
pub const F9: u16 = 1067;
pub const F10: u16 = 1068;
pub const SHIFT_F1: u16 = 1084;
pub const CTRL_F1: u16 = 1094;
pub const ALT_F1: u16 = 1104;
pub const HOME: u16 = 1071;
pub const UP: u16 = 1072;
pub const PGUP: u16 = 1073;
pub const LEFT: u16 = 1075;
pub const RIGHT: u16 = 1077;
pub const END: u16 = 1079;
pub const DOWN: u16 = 1080;
pub const PGDN: u16 = 1081;
pub const INS: u16 = 1082;
pub const DEL: u16 = 1083;
pub const CTRL_LEFT: u16 = 1115;
pub const CTRL_RIGHT: u16 = 1116;
pub const CTRL_END: u16 = 1117;
pub const CTRL_PGDN: u16 = 1118;
pub const CTRL_HOME: u16 = 1119;
pub const CTRL_PGUP: u16 = 1132;
pub const F11: u16 = 1133;
pub const F12: u16 = 1134;

/// Fn key code (n = 1..=10) for no modifier / shift / ctrl / alt.
pub fn f_key(n: u16, shift: bool, ctrl: bool, alt: bool) -> u16 {
    let base = if alt {
        ALT_F1
    } else if ctrl {
        CTRL_F1
    } else if shift {
        SHIFT_F1
    } else {
        F1
    };
    base + n - 1
}

const ALT_LETTERS: &[u8; 26] = &[
    30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50, 49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44,
];

/// Alt+letter code (scan code of the letter key, US layout).
pub fn alt_letter(c: char) -> Option<u16> {
    let c = c.to_ascii_lowercase();
    c.is_ascii_lowercase().then(|| 1000 + ALT_LETTERS[(c as u8 - b'a') as usize] as u16)
}

/// The letter of an Alt+letter code.
pub fn alt_letter_of(code: u16) -> Option<char> {
    let s = u8::try_from(code.checked_sub(1000)?).ok()?;
    ALT_LETTERS.iter().position(|&x| x == s).map(|i| (b'a' + i as u8) as char)
}

/// Alt+digit (1..9, 0) code.
pub fn alt_digit(d: u8) -> u16 {
    1000 + if d == 0 { 129 } else { 119 + d as u16 }
}
