"""Instruction-level diff of DXM.EXE code segments (original vs rebuilt); prints differing instructions.
usage: dsdiff.py ORIG.EXE BUILT.EXE [maxlines]"""
import sys, capstone, collections
a = open(sys.argv[1], 'rb').read(); b = open(sys.argv[2], 'rb').read()
H = int.from_bytes(a[8:10], 'little') * 16
SEGS = [0x0000, 0x005f, 0x038f, 0x03ad, 0x073b, 0x088d, 0x08a9, 0x0aa6, 0x0acc, 0x0b3a, 0x0c74, 0x0da0, 0x0da2, 0x0dbd, 0x0e05,
        0x0eb7, 0x0fb1, 0x10a4, 0x10f5, 0x1113, 0x1140, 0x118c, 0x1191, 0x11bd, 0x129a, 0x12a3, 0x12e1, 0x1343, 0x1509]
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_16)
cnt = collections.Counter()
lines = []
for s, e in zip(SEGS, SEGS[1:]):
    o = H + s * 16; code = a[o:H + e * 16]
    off = 0
    while off < len(code):
        ins = next(md.disasm(code[off:off + 16], off), None)
        n = ins.size if ins else 1
        if a[o + off:o + off + n] != b[o + off:o + off + n]:
            bi = next(md.disasm(b[o + off:o + off + 16], off), None)
            lines.append('%04x:%04x  %-40s | %s' % (s, off, (ins.mnemonic + ' ' + ins.op_str) if ins else '?', (bi.mnemonic + ' ' + bi.op_str) if bi else '?'))
            cnt[s] += 1
        off += n
print(' '.join('%04x:%d' % kv for kv in sorted(cnt.items())))
print('\n'.join(lines[:int(sys.argv[3]) if len(sys.argv) > 3 else 100]))
