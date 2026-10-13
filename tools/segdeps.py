"""Inter-segment far-call graph of a TP7 EXE.  usage: segdeps.py EXE"""
import sys, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0] + '/tpdec')
from model import Model
M = Model(sys.argv[1])
dep = collections.defaultdict(set)
for s in M.codesegs:
    b = M.seg_bytes(s)
    for i in range(len(b) - 4):
        if b[i] == 0x9a and M.reloc_at(s * 16 + i + 3):
            t = int.from_bytes(b[i + 3:i + 5], 'little')
            if t != s and t != M.sysseg:
                dep[s].add(t)
for s in M.codesegs:
    print(f'{s:04x} -> ' + ' '.join(f'{t:04x}' for t in sorted(dep[s])))
