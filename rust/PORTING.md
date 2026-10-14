# Rust port — decisions and original quirks

Spec: the verified Pascal in `src/dxm/` (and `src/dxmain/` for DXMAIN). Goal: clone the behaviour for modern
terminals; texts are English, file formats are our own.

## Layout
- `dxtui/`: the DX text-mode toolkit. `Crt` emulates the Turbo Pascal Crt unit on a cell grid (char + DOS
  attribute), so screens can be compared cell for cell with DOSBox captures (`ref/`); `term.rs` draws the
  grid with crossterm in the DX palette (true colour) and centres it in larger terminals. On top: dialog
  stack, key input with clock/saver idle work, mouse helpers, buttons, lists, line editor, help viewer.
- `dxm/`: the program menu (DXM.EXE).
- Tests: queued `SNAPSHOT` pseudo keys record screens during a scripted run; `dxm` compares its main screen,
  group switch and admin menu with `ref/dxm/*.SCR` (attributes everywhere, text where it is not translated).

## Decisions
- 80×25 logical screen by default, drawn exactly like the original; larger terminals centre it.
- Settings: `$DX_HOME/dx.conf` (key = value; default `~/.config/dx`), menu: `$DX_HOME/dxmenu.txt`
  (tab-separated, see `dxm/src/menu.rs`). No dx.ini/dxmenu.dat compatibility.
- Launching: the original writes `dxstart.bat`, exits, and `menu.bat` restarts DXM after the program.
  The port suspends the screen, runs the command with `sh -c` and returns to the menu.
- Drives are replaced by "places" (home, /, mounted volumes).
- Dropped (DOS-only): VGA font/palette/border setup, 28-line mode, mouse-cursor shapes, `batch`/`/m`
  arguments, external saver programs, fading/curtain effects.
- Help: `dxtui/help/dxhelp.txt`, translated page by page as features are ported.

## Quirks in the original (not copied unless noted)
- Admin menu, cursor keys: skips item 5 and slot 12 instead of the headings 1, 6 and 10, and opens with the
  "Groups" heading selected. Port: skips the headings and opens on the first function.
- `ChDir` flag of an entry is stored and edited, but DXM ignores it (`dxstart.bat` always changes into the
  program's directory). Port: honours the flag.
- Entry editor "Insert" left the inserted entry's `ChDir` flag at whatever the shifted entry had. Port: uses
  the checkbox.
- New group: Return in the name field only moves to the buttons. Port: Return accepts, Esc cancels.
- `Times.TimeCount` multiplies hours by 2600 instead of 3600, so timings over an hour boundary are off.
  Port: real elapsed time.

## DXM status
- Done: main screen, admin/entry/frame menus, group add/delete/rename/sort, entry editor, entry sort, file
  browser, help viewer (F1), screen saver (stars) with password, launching, saved menu position.
