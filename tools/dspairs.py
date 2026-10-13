"""Pair DS offsets between the original DXM.EXE and a rebuilt one whose code differs only in DS addresses.
usage: dspairs.py ORIG.EXE BUILT.EXE   -> lines 'orig built delta segs'"""
import sys, collections
a = open(sys.argv[1], 'rb').read(); b = open(sys.argv[2], 'rb').read()
ha = int.from_bytes(a[8:10], 'little') * 16; hb = int.from_bytes(b[8:10], 'little') * 16
DSEG = 0x1509 * 16
pairs = collections.defaultdict(set)
i = 0
while i < DSEG - 1:
    if a[ha + i] != b[hb + i] or a[ha + i + 1] != b[hb + i + 1]:
        # take the word starting at the first differing byte, aligned back by one if needed
        j = i if a[ha + i] != b[hb + i] else i
        if a[ha + j] == b[hb + j]: j += 1
        if j > 0 and a[ha + j - 1] == b[hb + j - 1] and a[ha + j + 1] != b[hb + j + 1]:
            pass
        wa = int.from_bytes(a[ha + j:ha + j + 2], 'little'); wb = int.from_bytes(b[hb + j:hb + j + 2], 'little')
        # if only the high byte differs, word starts one earlier
        if a[ha + j + 1] == b[hb + j + 1] and j > 0:
            wa = int.from_bytes(a[ha + j - 1:ha + j + 1], 'little'); wb = int.from_bytes(b[hb + j - 1:hb + j + 1], 'little'); j -= 1
        pairs[wa].add((wb, j // 16 * 0 + j))
        i = j + 2
    else:
        i += 1
for k in sorted(pairs):
    bs = sorted({x for x, _ in pairs[k]})
    print('%04x -> %s  n=%d first@%05x' % (k, ' '.join('%04x(%+d)' % (x, x - k) for x in bs), len(pairs[k]), min(p for _, p in pairs[k])))
