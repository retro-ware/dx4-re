"""Build System-RTL helper signatures from work/rtl (reference build) and name helpers in a target EXE.
usage: rtlsig.py build            -> writes tools/rtlsig.json
       rtlsig.py name EXE         -> prints System offset -> helper name for EXE
"""
import sys, json, re, struct
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from mz import MZ
from tpsegs import segments
import capstone

ROOT = __file__.rsplit('/', 2)[0]
SIGLEN = 40

def sysseg(m):
    """System = last code segment (the one containing 'Runtime error')."""
    segs, _ = segments(m)
    i = m.image.find(b'Runtime error')
    return max(s for s in segs if s * 16 <= i)

def masked(m):
    b = bytearray(m.image)
    for o in m.reloc_offsets():
        b[o:o+2] = b'\xff\xff'
    return b

def build():
    m = MZ(ROOT + '/work/rtl/RTL.EXE')
    mp = open(ROOT + '/work/rtl/RTL.MAP').read()
    procs = {}
    for seg, off, name in re.findall(r'([0-9A-F]{4}):([0-9A-F]{4})\s+P_(\w+)', mp):
        procs[name] = (int(seg, 16), int(off, 16))
    S = sysseg(m)
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_16)
    starts = sorted(procs.values())
    names = {}
    for name, (seg, off) in procs.items():
        a = seg * 16 + off
        nxt = min([s * 16 + o for s, o in starts if s * 16 + o > a] + [S * 16])
        calls = []
        for ins in md.disasm(bytes(m.image[a:nxt]), 0):
            if ins.bytes[0] == 0x9a:
                o2, s2 = struct.unpack_from('<HH', ins.bytes, 1)
                if s2 == S:
                    calls.append(o2)
        for k, o2 in enumerate(calls):
            names.setdefault(o2, set()).add(f'{name}#{k}' if len(calls) > 1 else name)
    mb = masked(m)
    ent = sorted(names)
    sigs = []
    for i, o in enumerate(ent):
        a = S * 16 + o
        n = min(SIGLEN, (ent[i+1] - o) if i + 1 < len(ent) else SIGLEN)
        sigs.append(dict(off=o, names=sorted(names[o]), sig=bytes(mb[a:a+n]).hex()))
    json.dump(sigs, open(ROOT + '/tools/rtlsig.json', 'w'), indent=1)
    print(len(sigs), 'helpers')

def name(path):
    m = MZ(path)
    S = sysseg(m)
    mb = masked(m)
    seg = bytes(mb[S*16:])
    sigs = json.load(open(ROOT + '/tools/rtlsig.json'))
    out = {}
    pos = 0
    for s in sigs:                      # helpers appear in the same order as in the reference System
        sig = bytes.fromhex(s['sig'])
        best = None
        for o in range(pos, len(seg) - len(sig)):
            if seg[o] != sig[0]:
                continue
            eq = sum(1 for x, y in zip(sig, seg[o:o+len(sig)]) if x == y)
            if eq >= len(sig) * 0.9:
                best = (eq, o)
                break
        if best:
            out.setdefault(best[1], []).append(s['name'])
            pos = best[1] + 1
    return S, out

if __name__ == '__main__':
    if sys.argv[1] == 'build':
        build()
    else:
        S, out = name(sys.argv[2])
        print(f'System seg {S:04x}')
        for o in sorted(out):
            print(f'{o:04x} {" ".join(out[o])}')
