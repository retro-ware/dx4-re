"""Compare a rebuilt TP7 EXE with the original, code segment by code segment (in link order).
usage: tpcmp.py ORIG.EXE BUILT.EXE BUILT.MAP [-v SEGIDX]
Relocated words are masked on both sides.  Prints size and masked diff count per segment, plus DS and header."""
import sys, re
sys.path.insert(0, __file__.rsplit('/', 1)[0])
sys.path.insert(0, __file__.rsplit('/', 1)[0] + '/tpdec')
from mz import MZ
from model import Model


def mapsegs(path):
    out = []
    for m in re.finditer(r'^\s*([0-9A-F]{5})H ([0-9A-F]{5})H ([0-9A-F]{5})H (\S+)\s+(\S+)', open(path, errors='replace').read(), re.M):
        out.append((int(m[1], 16), int(m[3], 16), m[4], m[5]))
    return out


def masked(m):
    b = bytearray(m.image)
    for o in m.reloc_offsets():
        b[o:o + 2] = b'\xee\xee'
    return b


def main():
    orig, built, mp = sys.argv[1:4]
    verbose = int(sys.argv[5]) if len(sys.argv) > 5 else None
    O = Model(orig)
    B = MZ(built)
    ob, bb = masked(O.m), masked(B)
    osegs = [(s * 16, (O.segend[s] - s) * 16) for s in O.codesegs]
    bsegs = [(a, l) for a, l, n, c in mapsegs(mp) if c == 'CODE']
    names = [n for a, l, n, c in mapsegs(mp) if c == 'CODE']
    total = 0
    for i, ((oa, ol), (ba, bl), n) in enumerate(zip(osegs, bsegs, names)):
        bl16 = (bl + 15) & ~15
        x, y = ob[oa:oa + ol], bb[ba:ba + bl16]
        d = [k for k in range(min(len(x), len(y))) if x[k] != y[k]]
        bad = len(d) + abs(len(x) - len(y))
        total += bad
        st = 'OK' if bad == 0 else f'diff={len(d)} first={d[0]:#x}' if d else ''
        print(f'{i:2d} {oa // 16:04x} {n:10s} orig={ol:5x} built={bl16:5x} {st}')
        if verbose == i and d:
            for k in d[:40]:
                print(f'   {k:04x}: {x[k]:02x} {y[k]:02x}')
    if len(osegs) != len(bsegs):
        print('segment count', len(osegs), len(bsegs))
    od, bd = O.img[O.ds * 16:], B.image[[a for a, l, n, c in mapsegs(mp) if c == 'DATA'][0]:]
    dd = [k for k in range(min(len(od), len(bd))) if od[k] != bd[k]]
    print(f'DATA orig={len(od):x} built={len(bd):x} diff={len(dd)}' + (f' first={dd[0]:#x}' if dd else ''))
    print('header', 'same' if O.m.data[2:0x1c] == B.data[2:0x1c] else 'differs', 'TOTAL', total + len(dd))
    print('IDENTICAL' if O.m.data == B.data else 'not identical')


main()
