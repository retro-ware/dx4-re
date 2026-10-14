"""Render a raw text-mode dump (char,attr pairs, 80 columns) as text; with --attr also print the attribute grid."""
import sys
d = open(sys.argv[1], 'rb').read()
rows = len(d) // 160
for r in range(rows):
    print(''.join(bytes([d[r * 160 + 2 * c]]).decode('cp437') for c in range(80)))
if '--attr' in sys.argv:
    for r in range(rows):
        print(' '.join('%02x' % d[r * 160 + 2 * c + 1] for c in range(80)))
