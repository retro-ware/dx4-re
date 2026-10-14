//! Code page 437, the character set of every string in the DOS-Expander data files.

const HIGH: &str = "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■\u{a0}";

pub fn decode(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|&b| if b < 0x80 { b as char } else { HIGH.chars().nth(b as usize - 0x80).unwrap() })
        .collect()
}

/// Non-ASCII characters map to CP437 0x80..0xFF, else to the control-code glyphs (☺, ►, ↑, ...);
/// anything else becomes '?'.
pub fn encode(s: &str) -> Vec<u8> {
    s.chars()
        .map(|c| {
            if (c as u32) < 0x80 {
                c as u8
            } else {
                HIGH.chars()
                    .position(|h| h == c)
                    .map(|i| 0x80 + i as u8)
                    .or_else(|| (1..32).find(|&b| crate::glyph::glyph(b) == c))
                    .unwrap_or(b'?')
            }
        })
        .collect()
}

/// Reads a Turbo Pascal `string[max]`: a length byte followed by `max` bytes.
pub fn read_pstr(buf: &[u8], max: usize) -> String {
    let len = (buf[0] as usize).min(max);
    decode(&buf[1..1 + len])
}

/// Writes a Turbo Pascal `string[max]`, truncating like a Pascal assignment does.
pub fn write_pstr(buf: &mut [u8], max: usize, s: &str) {
    let b = encode(s);
    let len = b.len().min(max);
    buf[0] = len as u8;
    buf[1..1 + len].copy_from_slice(&b[..len]);
    buf[1 + len..1 + max].fill(0);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip() {
        let all: Vec<u8> = (0..=255).collect();
        assert_eq!(encode(&decode(&all)), all);
    }
}
