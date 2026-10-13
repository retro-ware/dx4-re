"""Guess which code segments of a TP7 EXE are stock Borland units by searching windows in stock TPU/TPL files."""
import sys, glob, re
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mz import MZ
from tpsegs import segments

TC = __file__.rsplit('/', 2)[0] + '/toolchain/bp701'
W = 10

def tpl_units(path):
    """Split a TPL into its units by the 'TPU9' signature."""
    d = open(path, 'rb').read()
    offs = [m.start() for m in re.finditer(b'TPUQ', d)]
    out = []
    for a, b in zip(offs, offs[1:] + [len(d)]):
        u = d[a:b]
        out.append(u)
    return out

def unit_name(u):
    names = [x for x in re.findall(rb'[A-Za-z]{3,}', u[4:0x100])]
    return names[0].decode().upper() if names else '?'

stock = {}
for u in tpl_units(TC + '/bin/turbo.tpl'):
    stock.setdefault(unit_name(u), u)
for p in glob.glob(TC + '/tv/*.tpu'):
    u = open(p, 'rb').read()
    stock[p.rsplit('/', 1)[1][:-4].upper()] = u

def ident(path):
    m = MZ(path)
    mask = set()
    for o in m.reloc_offsets():
        mask.update((o, o + 1))
    segs, vals = segments(m)
    ends = segs[1:] + [len(m.image) // 16]
    for s, e in zip(segs, ends):
        a, b = s * 16, e * 16
        best = []
        wins = [m.image[o:o+W] for o in range(a, b - W, 4) if not any(x in mask for x in range(o, o + W))]
        for name, u in stock.items():
            hit = sum(1 for w in wins if w in u)
            if wins and hit / len(wins) > 0.3:
                best.append((hit / len(wins), name))
        best.sort(reverse=True)
        print(f'{s:04x} {b-a:6x} ' + ', '.join(f'{n}:{r:.2f}' for r, n in best[:3]))

if __name__ == '__main__':
    print('stock units:', sorted(stock))
    for p in sys.argv[1:]:
        print('==', p); ident(p)
