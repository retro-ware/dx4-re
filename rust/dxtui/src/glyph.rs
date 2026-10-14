//! How a screen byte looks in a Unicode terminal: code page 437 plus the characters that DX redefines in its
//! VGA font (spec: src/dxm/FONTS.PAS).

const LOW: &str = " ☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼";

/// Display character for screen byte `b`.
pub fn glyph(b: u8) -> char {
    match b {
        0x02 => '⧗', // hourglass (busy marker)
        0xAD => '¨', // two dots
        0xC6 => '═', // double line
        0xCE => '▕', // 3D frame: right edge
        0xD0 => '▏', // 3D frame: left edge
        0xD2 => '▗', // 3D corners
        0xD3 => '▖',
        0xD4 => '▝',
        0xD5 => '▘',
        0xD8 => '▁', // bottom line
        0xDD => '▔', // top line
        0xDC => '█',
        0x00 => ' ',
        0x01..=0x1F => LOW.chars().nth(b as usize).unwrap(),
        0x7F => '⌂',
        _ => crate::cp437::decode(&[b]).chars().next().unwrap(),
    }
}
