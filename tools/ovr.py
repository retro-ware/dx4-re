"""Parse TP7 overlay stubs (int 3Fh segments) of an EXE and the appended FBOV data."""
import sys, struct
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mz import MZ
from tpsegs import segments

def stubs(m):
    segs, _ = segments(m)
    out = []
    for s in segs:
        b = m.image[s*16:s*16+0x20]
        if b[:2] == b'\xcd\x3f':
            ret, fofs, csize, rsize, nent, prev = struct.unpack_from('<HIHHHH', b, 2)
            ents = []
            for i in range(nent):
                e = m.image[s*16+0x20+5*i:s*16+0x25+5*i]
                ents.append(struct.unpack_from('<H', e, 2)[0])
            out.append(dict(seg=s, fofs=fofs, csize=csize, rsize=rsize, ents=ents, prev=prev))
    return out

if __name__ == '__main__':
    m = MZ(sys.argv[1])
    st = stubs(m)
    tot = 0
    for x in st:
        tot += x['csize']
        print(f"{x['seg']:04x} fofs={x['fofs']:6x} code={x['csize']:5x} rel={x['rsize']:4x} n={len(x['ents']):3d} prev={x['prev']:04x}")
    print(len(st), 'overlay units, code total', hex(tot), 'FBOV', len(m.overlay))
