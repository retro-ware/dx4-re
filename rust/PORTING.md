# Rust port — decisions and original quirks

Spec: the verified Pascal in `src/dxm/` (each unit compiles to the original code). The port is an idiomatic
terminal app (ratatui + crossterm); no DOS/Crt/video-memory emulation.

## Decisions
- File formats are kept bit-compatible: `dxmenu.dat` (31666 B, CP437) and `dx.ini` (1810 B, only the menu
  position is written; all other bytes are preserved).
- Launching: the original writes `dxstart.bat`, exits, and `menu.bat` runs the program and restarts DXM.
  The port runs the program directly (working directory = the program's directory, as `dxstart.bat` did)
  and returns to the menu afterwards.
- Dropped (DOS-only): VGA font/palette/border setup, 28-line mode, mouse-cursor shapes, `menu.bat`/`batch`
  parameter check, `/m` mouse-reset switch.

## Quirks in the original (not copied unless noted)
- Admin menu, cursor keys: skips item 5 "Umbenennen" and slot 12 instead of the headings 1, 6 and 10,
  so the highlight can land on a heading. Port: skips the headings.
- `ChDir` flag of an entry is stored and edited, but DXM ignores it: `dxstart.bat` always changes into the
  program's directory. Port: same (always changes directory), flag kept in the file.
- New group: the original refuses or truncates a name when the menu bar (80 columns) would overflow.
  Port: keeps the 15-group limit; the bar scrolls instead of truncating.
