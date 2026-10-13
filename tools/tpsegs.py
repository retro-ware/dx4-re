"""List code segments of a TP7 EXE (from relocation target values) with size and a few strings."""
import sys, re
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mz import MZ

def segments(m):
    vals = {}
    for o in m.reloc_offsets():
        v = int.from_bytes(m.image[o:o+2], 'little')
        vals[v] = vals.get(v, 0) + 1
    segs = sorted(v for v in vals if v * 16 < len(m.image))
    return segs, vals

if __name__ == '__main__':
    m = MZ(sys.argv[1])
    segs, vals = segments(m)
    ends = segs[1:] + [len(m.image) // 16]
    for s, e in zip(segs, ends):
        b = m.image[s*16:e*16]
        strs = [x.decode('latin-1') for x in re.findall(rb'[\x20-\x7e\x80-\xa5]{6,}', b)][:3]
        print(f'{s:04x} size={len(b):6x} refs={vals[s]:4d}  {strs}')
