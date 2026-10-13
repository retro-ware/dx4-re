"""Compile one unit standalone (all interface procs referenced) and compare its code segment with an original one.
usage: tryunit.py ORIG.EXE SEGHEX UNIT.PAS [SRCDIR...]   (other units needed are taken from SRCDIR, default: unit's dir)"""
import sys, os, re, shutil, subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT + '/tools'); sys.path.insert(0, ROOT + '/tools/tpdec')
from mz import MZ
from model import Model

MANUAL = {'DXM.EXE': {'12a3:0349': 'Dos.Intr', '12a3:016a': 'Dos.FSearch', '12a3:02a5': 'Dos.Exec', '12a3:03a6': 'Dos.SwapVectors', '12e1:01cc': 'Crt.ClrScr', '12e1:024b': 'Crt.WhereX', '12e1:0257': 'Crt.WhereY',
                       '12e1:02a1': 'Crt.NormVideo', '12e1:0308': 'Crt.KeyPressed'}}
orig, seg, unit = sys.argv[1], int(sys.argv[2], 16), sys.argv[3]
dirs = sys.argv[4:] or [os.path.dirname(os.path.abspath(unit))]
W = ROOT + '/work/u'
shutil.rmtree(W, ignore_errors=True); os.makedirs(W)
for d in dirs:
    for f in os.listdir(d):
        if f.upper().endswith('.PAS'):
            shutil.copy(os.path.join(d, f), W)
src = open(unit, encoding='latin-1').read()
prog = re.search(r'^\s*program\s+(\w+)', src, re.I | re.M)   # a program: compile it as is
name = prog[1] if prog else re.search(r'\bunit\s+(\w+)', src, re.I)[1]
intf = re.split(r'\bimplementation\b', src, flags=re.I)[0]
procs = []
obj = None
for ln in intf.splitlines():
    m_ = re.match(r'\s*(\w+)\s*=\s*object\b', ln, re.I)
    if m_: obj = m_[1]; continue
    if obj and re.match(r'\s*end\s*;', ln, re.I): obj = None; continue
    m_ = re.match(r'\s*(?:procedure|function|constructor|destructor)\s+(\w+)', ln, re.I)
    if m_: procs.append(f'{obj}.{m_[1]}' if obj else m_[1])
body = '\n'.join(f'  P := @{p};' for p in procs)
if prog: shutil.copy(unit, W + '/T.PAS')
else: open(W + '/T.PAS', 'w').write(f'program T;\nuses {name};\nvar P: Pointer;\nbegin\n  if ParamCount = 99 then begin\n{body}\n  end;\nend.\n')
subprocess.run([ROOT + '/tools/dosrun.sh', W, 't:\\bp701\\bin\\tpc -GD -B -Ut:\\bp701\\bin T.PAS'])
out = open(W + '/OUT.TXT', errors='replace').read()
if 'Error' in out:
    print(out[out.find('Error') - 200:][:600]); sys.exit(1)
mp = open(W + '/T.MAP').read()
segs = re.findall(r'^\s*([0-9A-F]{5})H ([0-9A-F]{5})H ([0-9A-F]{5})H (\S+)\s+CODE', mp, re.M)
a, l = [(int(s[0], 16), int(s[2], 16)) for s in segs if s[3].upper() == name.upper()][0]
a0 = a
B = MZ(W + '/T.EXE'); O = Model(orig)
def masked(m):
    b = bytearray(m.image)
    for o in m.reloc_offsets():
        b[o:o + 2] = b'\xee\xee'
        if o >= 3 and m.image[o - 3] == 0x9a:   # far call: target offset depends on the other segment
            b[o - 2:o] = b'\xcc\xcc'
    return b
# overlaid unit (seg is its int 3Fh stub): code and relocations come from the FBOV data appended to the EXE
import struct
from ovr import stubs
OV = {st['seg']: st for st in stubs(O.m)}
ovl = seg in OV
if ovl:
    st = OV[seg]
    ocode = bytes(O.m.overlay[st['fofs']:st['fofs'] + st['csize']])
    orel = struct.unpack_from(f"<{st['rsize'] // 2}H", O.m.overlay, st['fofs'] + st['csize'])
    x = bytearray(ocode)
    for r in orel:
        x[r:r + 2] = b'\xee\xee'
        if r >= 3 and ocode[r - 3] == 0x9a: x[r - 2:r] = b'\xcc\xcc'
    x = x + bytes(-len(x) % 16)
    ocode = ocode + bytes(-len(ocode) % 16)
else:
    ocode = bytes(O.seg_bytes(seg))
    x = masked(O.m)[seg * 16:O.segend[seg] * 16]
y = masked(B)[a:a + l]
y = y + bytes(-len(y) % 16)
from model import CS
d = [k for k in range(min(len(x), len(y))) if x[k] != y[k]]
# split: operand-only differences (same instruction shape, differing disp/imm: DS addresses) vs real ones
def lin(b):   # linear disassembly that resumes after undecodable bytes
    out, p = {}, 0
    while p < len(b):
        n = 0
        for i in CS.disasm(b[p:], p):
            out[i.address] = i; n = i.address + i.size
        p = max(n, p) + (1 if n <= p or n < len(b) else 0)
    return out
xi = lin(bytes(ocode))
yi = lin(bytes(y))
starts = sorted(xi)
ystarts = sorted(yi)
import bisect
real, addr = [], []
for k in d:
    a = starts[bisect.bisect_right(starts, k) - 1] if starts else 0
    i, j = xi.get(a), yi.get(a)
    if not (i and j and a + i.size > k):   # linear disassembly of one side desynced (literals): use the other's
        a = ystarts[bisect.bisect_right(ystarts, k) - 1] if ystarts else 0
        i, j = xi.get(a), yi.get(a)
        if not i and j: i = next(CS.disasm(bytes(ocode[a:a + 16]), a), None)
    dk = [q for q in range(a, a + (i.size if i else 1)) if q < len(y) and x[q] != y[q]]
    if i and j and i.size == j.size and i.mnemonic == j.mnemonic and x[a:a + 1] == y[a:a + 1] and i.op_str.split(",")[0].split("[")[0] == j.op_str.split(",")[0].split("[")[0] \
            and dk and dk[-1] - dk[0] <= 1:
        addr.append(k)
    else:
        real.append(k)
ok = not real and len(x) == len(y)
print(f'{name}: orig={len(x):#x} built={len(y):#x} real diffs={len(real)} addr diffs={len(addr)}', 'MATCH' if ok and not addr else 'MATCH(addr)' if ok else '')
pairs = {}
for k in addr:
    a = starts[bisect.bisect_right(starts, k) - 1]
    i, j = xi.get(a), yi.get(a)
    if not (i and j and a + i.size > k):
        a = ystarts[bisect.bisect_right(ystarts, k) - 1]
        i, j = xi.get(a) or next(CS.disasm(bytes(ocode[a:a + 16]), a)), yi[a]
    ov = [op.imm if op.type == 2 else op.mem.disp for op in i.operands if op.type in (2, 3)]
    bv = [op.imm if op.type == 2 else op.mem.disp for op in j.operands if op.type in (2, 3)]
    for u, v in zip(ov, bv):
        if u != v: pairs.setdefault(u & 0xffff, set()).add(v & 0xffff)
bad = {u: v for u, v in pairs.items() if len(v) > 1 or u < 0x100}
print('  addr map:', ' '.join(f'{u:x}>{"/".join(f"{w:x}" for w in sorted(v))}' for u, v in sorted(pairs.items())))
if bad: print('  SUSPICIOUS:', bad)
# far-call targets, checked by name: orig names from work/names_<EXE>.json (stock Dos/Crt by signature, own units as they
# match), System helpers by rtlsig; built names from the test map's publics.
import json, rtlsig, unitsig
NF = ROOT + '/work/names_' + os.path.basename(orig).split('.')[0].upper() + '.json'
if os.path.exists(NF):
    names = json.load(open(NF))
else:
    names = {f'{a:04x}:{b:04x}': n for (a, b), n in unitsig.name(orig).items()}
names.update(MANUAL.get(os.path.basename(orig).upper(), {}))
segname = {int(s_[0], 16) >> 4: s_[3] for s_ in segs}
pubs = {(int(a_, 16), int(o_, 16)): segname.get(int(a_, 16), '?') + '.' + n_
        for a_, o_, n_ in re.findall(r'^ ([0-9A-F]{4}):([0-9A-F]{4})\s+(\w+)$', mp, re.M)}
bsys, brtl = rtlsig.name(W + '/T.EXE')
calls, unknown = [], []
def stubname(ts, to):   # far call into an overlaid unit goes to its stub entry: map to the real offset
    if ts in OV and to >= 0x20 and (to - 0x20) % 5 == 0 and (to - 0x20) // 5 < len(OV[ts]['ents']):
        return ts, OV[ts]['ents'][(to - 0x20) // 5]
    return ts, to
for k, cb in ([(r, ocode) for r in orel] if ovl else [(o - seg * 16, None) for o in O.m.reloc_offsets()]):
    img = cb if ovl else O.m.image
    o = k if ovl else k + seg * 16
    if 3 <= k < len(x) and img[o - 3] == 0x9a:
        ts = int.from_bytes(img[o:o + 2], 'little'); to = int.from_bytes(img[o - 2:o], 'little')
        ts, to = stubname(ts, to)
        if ts == seg:
            continue
        bo = a0 + k
        if bo + 2 > len(B.image) or B.image[bo - 3] != 0x9a: continue
        bs = int.from_bytes(B.image[bo:bo + 2], 'little'); bt = int.from_bytes(B.image[bo - 2:bo], 'little')
        on = ('System.' + O.rtl.get(to, f'?{to:x}')) if ts == O.sysseg else names.get(f'{ts:04x}:{to:04x}')
        bn = ('System.' + brtl.get(bt, [f'?{bt:x}'])[0]) if bs == bsys else pubs.get((bs, bt), f'?{bs:x}:{bt:x}')
        on = on and on.replace('BlockCopy', 'Move'); bn = bn.replace('BlockCopy', 'Move')
        if on is None:
            unknown.append(f'{k - 3:x}:{ts:04x}:{to:x}={bn}')
        elif on.split('.', 1)[-1].upper() != bn.split('.', 1)[-1].upper() and not on.split('.', 1)[-1].startswith('?'):
            calls.append(f'{k - 3:x}:{on}>{bn}')
if calls: print('  CALL MISMATCH:', ' '.join(calls[:20]))
if unknown: print('  unnamed targets:', ' '.join(sorted(set(u.split(':', 1)[1] for u in unknown))[:30]))
if ok and not calls:
    for (bs_, bo_), n_ in pubs.items():
        if segname.get(bs_, '').upper() == name.upper():
            names[f'{seg:04x}:{bo_:04x}'] = n_
    json.dump(names, open(NF, 'w'), indent=0, sort_keys=True)
if ovl:   # proc starts: enter / push bp; mov bp,sp (linear disassembly, resyncs after literals)
    pstarts = sorted({0} | {a_ for a_, i_ in xi.items() if i_.mnemonic == 'enter' or (i_.mnemonic == 'push' and i_.op_str == 'bp'
                                and a_ + 1 in xi and xi[a_ + 1].mnemonic == 'mov' and xi[a_ + 1].op_str == 'bp, sp')})
else:
    pstarts = sorted(k_[1] for k_ in O.procs if k_[0] == seg)
if real and pstarts:
    per = {}
    for k in real:
        i_ = bisect.bisect_right(pstarts, k) - 1
        per[pstarts[max(i_, 0)]] = per.get(pstarts[max(i_, 0)], 0) + 1
    print('  per proc:', ' '.join(f'{p_:x}:{n_}' for p_, n_ in sorted(per.items())))
for k in real[:30]:
    print(f'  {k:04x}: {x[k]:02x} {y[k]:02x}')
open(W + '/seg.bin', 'wb').write(y); open(W + '/orig.bin', 'wb').write(x)
