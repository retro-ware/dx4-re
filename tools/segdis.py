"""Disassemble one code segment of a TP7 EXE with reloc marks and Pascal string literals shown.  usage: segdis.py EXE SEGHEX"""
import sys, subprocess
sys.path.insert(0, __file__.rsplit('/', 1)[0] + '/tpdec')
from model import Model, CS
M = Model(sys.argv[1]); s = int(sys.argv[2], 16)
b = M.seg_bytes(s)
import os, json
_nf = __file__.rsplit('/', 2)[0] + '/work/names_' + os.path.basename(sys.argv[1]).split('.')[0].upper() + '.json'
names = json.load(open(_nf)) if os.path.exists(_nf) else {}
keys = sorted(k for k in M.procs if k[0] == s)
for k in keys:
    p = M.procs[k]
    M.disasm(p)
    print(f'---- proc {k[1]:04x} {"far" if p.far else "near"} ret{p.argsize}')
    for i in p.ins:
        rel = any(M.reloc_at(s * 16 + a) for a in range(i.address, i.address + i.size))
        t = ''
        if i.mnemonic == 'mov' and i.op_str.startswith('di, 0x') and len(i.operands) == 2:
            v = i.operands[1].imm
            if v < len(b) and v + 1 + b[v] <= len(b):
                t = '   ; ' + repr(bytes(b[v + 1:v + 1 + b[v]]).decode('latin-1'))
        if i.mnemonic == 'lcall':
            o = i.operands[1].imm if len(i.operands) > 1 else 0
            seg = int.from_bytes(b[i.address + 3:i.address + 5], 'little')
            if seg == M.sysseg:
                t = '   ; ' + str(M.rtl.get(o, '?'))
            elif f'{seg:04x}:{o:04x}' in names:
                t = '   ; ' + names[f'{seg:04x}:{o:04x}']
        print(f'  {i.address:04x} {i.mnemonic:6s} {i.op_str}{t}')
