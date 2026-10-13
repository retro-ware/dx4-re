"""Hex dump of a byte range of a code segment.  usage: segbytes.py EXE SEGHEX START END"""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0] + '/tpdec')
from model import Model
M = Model(sys.argv[1]); b = M.seg_bytes(int(sys.argv[2], 16))
a, e = int(sys.argv[3], 16), int(sys.argv[4], 16)
for o in range(a, e, 16):
    print(f'{o:04x}: ' + ' '.join(f'{x:02x}' for x in b[o:min(o + 16, e)]))
