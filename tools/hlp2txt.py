#!/usr/bin/env python3
"""hlp2txt.py DXHELP.HLP OUT.txt -- dumps the DX help file (THelpPage records, src/dxm/HELP.PAS) as text:
'=== title' starts a page, followed by its lines (trailing blanks removed, up to the page's line count)."""
import sys
d = open(sys.argv[1], 'rb').read()
R = 1 + 77 + 3 * 28 * 77 + 1
out = []
for p in range(len(d) // R):
    r = d[p * R:(p + 1) * R]
    ps = lambda b: b[1:1 + b[0]].decode('cp437')
    out.append('=== ' + ps(r[1:78]).rstrip())
    lines = [ps(r[78 + i * 77:78 + i * 77 + 77]).rstrip() for i in range(r[0] * 28)]
    lines = lines[:max(r[-1], 1)]
    while lines and not lines[-1]:
        lines.pop()
    out += lines
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
