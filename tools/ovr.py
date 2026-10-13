"""Parse TP7 overlay stubs (int 3Fh segments) of an EXE and the appended FBOV data."""
import sys, struct
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mz import MZ
from tpsegs import segments

def stub_at(m, s):
    b = m.image[s*16:s*16+0x20]
    if b[:2] != b'\xcd\x3f':
        return None
    ret, fofs, csize, rsize, nent, prev = struct.unpack_from('<HIHHHH', b, 2)
    ents = []
    for i in range(nent):
        e = m.image[s*16+0x20+5*i:s*16+0x25+5*i]
        ents.append(struct.unpack_from('<H', e, 2)[0])
    return dict(seg=s, fofs=fofs, csize=csize, rsize=rsize, ents=ents, prev=prev)

def stubs(m):
    # the segment table misses some stub segments: also walk every stub's `prev` chain
    segs, _ = segments(m)
    found = {}
    todo = list(segs)
    while todo:
        s = todo.pop()
        if s in found or s == 0:
            continue
        st = stub_at(m, s)
        if st:
            found[s] = st
            todo.append(st['prev'])
    return [found[s] for s in sorted(found)]

if __name__ == '__main__':
    m = MZ(sys.argv[1])
    st = stubs(m)
    tot = 0
    for x in st:
        tot += x['csize']
        print(f"{x['seg']:04x} fofs={x['fofs']:6x} code={x['csize']:5x} rel={x['rsize']:4x} n={len(x['ents']):3d} prev={x['prev']:04x}")
    print(len(st), 'overlay units, code total', hex(tot), 'FBOV', len(m.overlay))
