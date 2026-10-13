"""Side-by-side disassembly of work/u/orig.bin vs work/u/seg.bin.  usage: dcmp.py START END [START2]"""
import sys
from capstone import Cs, CS_ARCH_X86, CS_MODE_16
md = Cs(CS_ARCH_X86, CS_MODE_16)
a, e = int(sys.argv[1], 16), int(sys.argv[2], 16)
a2 = int(sys.argv[3], 16) if len(sys.argv) > 3 else a
W = __file__.rsplit('/', 2)[0] + '/work/u/'
L = [[f'{i.address:04x} {i.mnemonic} {i.op_str}' for i in md.disasm(open(W + f, 'rb').read()[s:s + e - a + 0x40], s)]
     for f, s in (('orig.bin', a), ('seg.bin', a2))]
for i in range(max(map(len, L))):
    x = L[0][i] if i < len(L[0]) else ''
    y = L[1][i] if i < len(L[1]) else ''
    if int(x[:4] or 'ffff', 16) > e: break
    print(f'{x:44s}{"  " if x[5:] == y[5:] else "**"} {y}')
