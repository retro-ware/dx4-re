"""Find raw 16-bit occurrences of DS offsets in the code of a TP7 EXE.  usage: findref.py EXE HEX..."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0] + '/tpdec')
from model import Model
M = Model(sys.argv[1]); img = M.img
for a in sys.argv[2:]:
    v = int(a, 16); pat = v.to_bytes(2, 'little'); i = 0
    while True:
        i = img.find(pat, i + 1)
        if i < 0 or i >= M.ds * 16: break
        seg = max(s for s in M.codesegs if s * 16 <= i)
        print(f'{v:04x} {seg:04x}:{i - seg * 16:04x} {img[i - 3:i + 3].hex()}')
