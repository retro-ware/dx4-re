#!/bin/bash
# Re-check every finished DXM unit against the original segment.
cd "$(dirname "$0")/.."
while read seg unit; do
  [ -z "$seg" ] && continue
  .venv/bin/python tools/tryunit.py dist/DX4/DXM.EXE $seg src/dxm/$unit.PAS | grep -v "addr map" | sed "s/^/$seg /"
done <<LIST
088d DATSTR
0aa6 SOUNDS
0acc STATUS
0da0 U0DA0
0da2 PASSWD
0dbd FONTS
0fb1 BUTTONS
0eb7 LISTS
08a9 DIALOGS
0e05 HELP
0c74 EXECUTE
0b3a SAVER
073b BROWSER
038f ADDPROG
03ad USERMENU
005f DXMENU
10a4 WINDOWS
10f5 TIMES
1113 SCRSAVE
1140 MOUSE
118c U118C
1191 PALETTE
11bd SCREEN
129a U129A
LIST
