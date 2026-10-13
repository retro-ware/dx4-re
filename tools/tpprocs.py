"""Find TP7 procedure starts in an EXE image: far-call targets, relocated far pointers, and prologues after returns."""
import sys, struct, re
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mz import MZ
from tpsegs import segments

PROLOGUE = re.compile(rb'\x55\x89\xe5|\xc8..\x00|\x55\x8b\xec', re.S)

def procs(m):
    img = m.image
    segs, _ = segments(m)
    segs = sorted(set([0] + segs))
    dataseg = int.from_bytes(img[0:0], 'little')
    starts = set()
    relset = set(m.reloc_offsets())
    for o in relset:
        seg = int.from_bytes(img[o:o+2], 'little')
        if o >= 3 and img[o-3] == 0x9a:          # call far seg:off
            off = int.from_bytes(img[o-2:o], 'little')
            starts.add((seg, off))
        elif o >= 2 and (o - 2) not in relset:  # dd far pointer (VMT, tables)
            off = int.from_bytes(img[o-2:o], 'little')
            starts.add((seg, off))
    ends = segs[1:] + [len(img) // 16]
    for s, e in zip(segs, ends):
        b = img[s*16:e*16]
        for mm in PROLOGUE.finditer(b):
            p = mm.start()
            prev = b[max(0, p-3):p]
            if p == 0 or prev[-1:] == b'\xc3' or prev[-1:] == b'\xcb' or (len(prev) == 3 and prev[0] in (0xc2, 0xca)):
                starts.add((s, p))
    segset = dict(zip(segs, ends))
    return sorted((s, o) for s, o in starts if s in segset and s * 16 + o < segset[s] * 16)

if __name__ == '__main__':
    m = MZ(sys.argv[1])
    for s, o in procs(m):
        print(f'{s:04x}:{o:04x}')
