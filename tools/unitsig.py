"""Name the stock Dos/Crt procedures inside a TP7 EXE by byte signature.
usage: unitsig.py build        -> tools/unitsig.json from work/usig/ALL.EXE (all Dos+Crt procs referenced)
       unitsig.py name EXE     -> prints seg:off name for every stock Dos/Crt proc found"""
import sys, re, json
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mz import MZ
from tpsegs import segments
ROOT = __file__.rsplit('/', 2)[0]
SIG = ROOT + '/tools/unitsig.json'


def masked(m):
    b = bytearray(m.image)
    for o in m.reloc_offsets():
        b[o:o + 2] = b'\xff\xff'
        if o >= 3 and m.image[o - 3] == 0x9a:
            b[o - 2:o] = b'\xff\xff'
    return b


def build():
    m = MZ(ROOT + '/work/usig/ALL.EXE')
    mp = open(ROOT + '/work/usig/ALL.MAP').read()
    segs = {int(a, 16) >> 4: n for a, n in re.findall(r'^\s*([0-9A-F]{5})H [0-9A-F]{5}H [0-9A-F]{5}H (\w+)\s+CODE', mp, re.M)}
    ends = sorted(segs) + [int(re.search(r'([0-9A-F]{5})H [0-9A-F]{5}H [0-9A-F]{5}H DATA', mp)[1], 16) >> 4]
    pubs = [(int(s, 16), int(o, 16), n) for s, o, n in re.findall(r'^ ([0-9A-F]{4}):([0-9A-F]{4})\s+(\w+)$', mp, re.M)]
    b = masked(m)
    out = {}
    for s, o, n in pubs:
        if segs.get(s) not in ('Dos', 'Crt'):
            continue
        nxt = min([p[1] for p in pubs if p[0] == s and p[1] > o] + [(ends[ends.index(s) + 1] - s) * 16])
        L = min(nxt - o, 48)
        out[segs[s] + '.' + n] = b[s * 16 + o:s * 16 + o + L].hex()
    json.dump(out, open(SIG, 'w'), indent=0)
    print(len(out), 'signatures')


def name(path):
    """{(seg, off): "Unit.Proc"} for the stock Dos/Crt procs found in EXE path."""
    m = MZ(path)
    b = bytes(masked(m))
    sigs = json.load(open(SIG))
    res = {}
    for n, h in sigs.items():
        full = bytes.fromhex(h)
        for L in (len(full), 32, 24, 16, 12, 8):
            s = full[:L]
            i = b.find(s)
            if i >= 0 and b.find(s, i + 1) < 0:
                res[i] = n
                break
    segs, _ = segments(m)
    out = {}
    for i, n in res.items():
        sg = max(x for x in segs if x * 16 <= i)
        out[(sg, i - sg * 16)] = n
    return out


if __name__ == '__main__':
    if sys.argv[1] == 'build':
        build()
    else:
        for (s, o), n in sorted(name(sys.argv[2]).items()):
            print(f'{s:04x}:{o:04x} {n}')
