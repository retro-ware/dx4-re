#!/usr/bin/env python3
"""mkmenu.py OUT  -- writes a sample DOS dxmenu.dat (original DXM format) for reference captures."""
import sys
NAME, PROG, GNAME, ITEMS, GROUPS = 18, 78, 30, 21, 15
def ps(s, n):
    b = s if isinstance(s, bytes) else s.encode('cp437'); return bytes([len(b)]) + b + bytes(n - len(b))
groups = [("~Spiele", ["TETRIS:C:\\GAMES\\TETRIS.EXE", "Doom:C:\\DOOM\\DOOM.EXE", "-", "Lemmings:C:\\GAMES\\LEM.EXE"]),
          ("~Tools", ["Norton:C:\\NC\\NC.EXE", "Editor:C:\\DOS\\EDIT.COM"]),
          ("~Office", ["Word:C:\\WORD\\WORD.EXE"])]
out = bytes([len(groups)])
for g, items in groups:
    out += ps(g, GNAME) + b'\x01'
    for i in range(ITEMS):
        it = items[i] if i < len(items) else ""
        if it == "-": out += ps(b"\xc4" * NAME, NAME) + ps("", PROG) + b'\x01'; continue
        n, _, p = it.partition(":")
        out += ps(n, NAME) + ps(p, PROG) + b'\x01'
item = 1 + NAME + 1 + PROG + 1
out += bytes((GROUPS - len(groups)) * (1 + GNAME + 1 + ITEMS * item))
open(sys.argv[1], 'wb').write(out)
