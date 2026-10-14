# DX4 byte-perfect rebuild — checklist

## Setup
- [x] Extract DX4.ZIP read-only to dist/DX4/
- [x] Identify toolchain (BP 7.01 TPC) and get it running in DOSBox-X (tools/dosrun.sh)
- [x] Ghidra export script (tools/ghidra/DumpAll.java)
- [x] Segment / overlay listing tools (tpsegs.py, ovr.py), RTL signatures (rtlsig.py)

## Programs (Borland Pascal 7.01 DOS unless noted)
- [x] DX.EXE (3552 B) — src/dx/DX.PAS, byte-identical
- [x] DX.COM (1077 B) — src/dxcom/DX.ASM (TASM 3.2, tools/bdxcom.sh), byte-identical
- [x] DXM.EXE (97 KB) — menu editor; {$F+,G+,S-}; own text-mode UI units (src/dxm/) — byte-identical (tools/dxmbuild.sh)
  - per-unit check: `tools/tryunit.py dist/DX4/DXM.EXE SEG src/dxm/UNIT.PAS` (MATCH(addr) = only DS addresses differ)
  - [x] 0000 program main (5f0) — src/dxm/DXM.PAS, {$I-,V-}
  - [x] 005f (3300) DXMenu
  - [x] 038f (1e0) ADDPROG: SelectProgram (TBrowser dialog)
  - [x] 03ad (38e0) UserMenu
  - [x] 073b (1520) BROWSER: TBrowser file selector, {$O+,V-}, Exit-form nested procs
  - [x] 088d DATSTR (1c0)
  - [x] 08a9 (1fd0) DIALOGS: dialogs, line editor, drive selector
  - [x] 0aa6 SOUNDS (260)
  - [x] 0acc (6e0) STATUS — clock/date status line, GetKey+macro replay
  - [x] 0b3a (13a0) SAVER: screen savers + password, shared with DXCD, {$O+}
  - [x] 0c74 (12c0) EXECUTE: RunProg + archiver error texts, {$O+}
  - [x] 0da0 U0DA0 (20)
  - [x] 0da2 (1b0) PASSWD
  - [x] 0dbd (480) FONTS
  - [x] 0e05 (b20) HELP: help pager, compiled {$O+} (literal args copied to temps)
  - [x] 0eb7 (fa0) LISTS — TList object (scrolling list)
  - [x] 0fb1 (f30) BUTTONS
  - [x] 10a4 (510) WINDOWS
  - [x] 10f5 TIMES (1e0)
  - [x] 1113 (2d0) SCRSAVE
  - [x] 1140 MOUSE (4c0)
  - [x] 118c U118C (50) — init section only
  - [x] 1191 PALETTE (2c0)
  - [x] 11bd SCREEN (dd0)
  - [x] 129a U129A (90)
  - [x] 12a3 Dos, 12e1 Crt, 1343 System — stock BP 7.01 (verified in full link)
  - [x] link order: uses clauses arranged so TPC -B completion order = original segment order
  - [x] DS layout (typed consts 0..644, vars 694..12f8): config options/HomeDir/History/DriveFlag are DXGlob typed consts, Pal1/Pal2 in Palette, CON/NUL in Execute; block copies are structured assignments (not Move); {$M 24000,0,655360}
  - [x] full-EXE link: work/dxm/DXM.EXE == dist/DX4/DXM.EXE
- [~] DXE.EXE (102 KB) — Turbo Vision program — SKIPPED (out of scope, decided 2026-10-13)
- [~] DXCD.EXE (113 KB) — shares many units with DXM — SKIPPED (out of scope, decided 2026-10-13)
- [ ] DXMAIN.EXE (816 KB, overlay appended to the EXE: FBOV at 0x27510, 654902 B, 68 overlaid units)
  - target = DXMAIN.EXE with its appended overlay; the shipped DXMAIN.OVR (652675 B, 15.4.96) is a different build
  - resident: 0000 main (31b0), 0365 big unit (c6a0), 20ff System; 2339 boot-sector code (after System?)
  - shared with DXM (shape match, work/dxmain_shared.txt; "+" = DXMAIN copy is larger, has extra procs):
    o0353 DXMenu, o0356 UserMenu, 154f DatStr, 1579 Dialogs+, 1824 Sounds, 184a Status, o18bc Saver,
    o18bf Execute+, 18cd Fonts, o1915 Help, 1918 Lists, 1a18 Buttons+, 1c1b Windows+, 1ce7 Times, 1d66 ScrSave,
    1d9f Mouse, 1df3 Palette, 1e26 Screen+; AddProg/Browser/Passwd/U129A not found by shape
  - [~] stock units by signature: 1fc8 Crt (0.56), 202a Dos (0.89), 208a Overlay (0.59), 20ff System; 12cd/12d1 = own LPT2/LPT1 units (not Printer); 2339 unknown — verify byte-exact in link
  - [x] resident shared units match (tryunit vs DXMAIN.EXE, src/dxmain/): DatStr, Sounds, Fonts, ScrSave, Times,
    Palette, Mouse, Lists, Status, Windows, Buttons, Screen, Dialogs
  - [x] overlaid shared units: DXMenu, UserMenu, Saver, Execute (DXMAIN adds RunFull/RunWindow/RunPacker, int 29h capture,
    MovePackWin, PackSettings), Help — all MATCH(addr)
  - [x] o115f Browser, o18c6 Passwd+ (ChangePassword, SelectDrives), o18c9 Toggle (new TToggle object unit) match
  - [x] o115c AddProg matches; U129A: no DXMAIN segment found yet
  - [x] new own overlay units matched: o0fdb KeyMode (key-bar mode menu), o0325 DriveOps (label drive, sys disk),
    o1156 DelTree, o0fd2 RmTree, o0fcf SearchBr (search bar + drive list), o0362 SaveCfg (dx.ini writer, TConfig layout),
    o100a ExtProg (external viewer, edit sys files), o12c4 NumConv (hex/dec/bin), o032e MouseSpd (mouse speed dialog),
    o114d TextSrch (text search in marked files, asm matcher), o0fd8 CopyDlg (copy/move dialog),
    o0322 PanelIni (save setup as / swap panels), o107c Ports (COM/LPT info + UART setup), o0fd5 PanelFrm (panel frame),
    o0334 DirCmp (compare panels), o1153 Filters (filter masks), o1435 Pickers (date/time/size lists); resident 1d10 (hex/bin conv) real,
    o1010 JoinFile (append files), o0328 RenFile (rename), o108f HistMenu (history list, exit/packer/note pickers),
    o1086 ArcDir (LZH/ZIP/ARJ directory readers), o13a5 U13A5 (numbered error/info message boxes),
    o10f5 FileAsk (copy/delete prompts), o106e CDDlg (CD player/tray); resident 1439 U1439 (calendar) byte-identical
    (tools/try1439.py: tryunit wrapper for the segment the table lumps into 1435),
    o156f LongName (Win95 LFN helpers, replaces U156F), o10f2 DirDisk (copy dir tree to disks), o142f AskDlgs (ask dialogs, replaces U142F),
    o1159 Pas (Point-And-Shoot file associations; Lists.SetData rows param is Integer),
    o1077 SysInfo (interrupt list, XMS/EMS info, key test, ports); placeholders U109E (resident XMS), U12C7 (viewer),
    o156b DirTree (dir tree sizes/browser), o033a Clocks (stopwatches), o1097 BootEdit (boot sector text editor),
    o1546 CDAudio (MSCDEX driver, replaces U1546), o1067 CmdMenu (dir command menu + macros), o100d TextView (text viewer)
  - [x] o1013 DiskImg (floppy image make/restore) matches strict (RestoreImage: unused 512-byte Sector buffer + 3-byte gap before Res)
  - [x] o032b ComXfer (serial file transfer) and o0331 PalEdit (palette editor) match strict (PalEdit: 1 [di+PalIdx] table false positive)
  - [x] o031b StateIO (state across shell-outs: XMS/dxtemp.tmp, dx.ini + dxcom.dat loading; TConfig/TFilterOpts moved to DXGlob,
    THistory is [0..26], TPanel.Filter at $13FE) matches strict
  - [x] o035c DrvInfo (drive overview: sizes/free per drive, drive selection bar saved to dx.ini) matches strict
    (loop over Longint I is a repeat/until entered via goto; {$I+} except file procs; U0365 P0365_C3B takes S by value)
  - [x] o13a9 ViewDlgs (viewer dialogs: DlgFrame/InfoBox, CutFile copy-a-range, hex/ascii SearchDlg; replaces U13A9) matches strict;
    placeholders U13B0 (+P13B0_60D/6C0 button pair, $109-byte buttons) and new U13AD (help entry)
  - [x] o1150 FindDlg (extended file search dialog: masks/filters, attributes, date and size ranges, drive bar, load/save
    filter; typed consts DateTo/DateFrom/MinSizeStr/MaxSizeStr/Archive/ReadOnly/SysAttr/Hidden at DS $400..$43A) matches strict
  - [x] o1071 QuickMnu (Quick menu: dxquick.dat list of 61 entries, entry editor with options sub-dialog, parameter prompt,
    run via COMSPEC/RunWindow; TQuickLst = object(TList) with DrawLine override, function QuickMenu returns the command) matches strict
  - [ ] o0340 TreeDlg WIP (agent B, size 0x2330 vs built 0x25c0, procs from 0x6e1 on diverge)
  - [x] strict tryunit recheck (2026-10-14): all matched units pass; remaining 'real diffs' are classifier false positives only:
    Palette/Status/TextView/U1D10/PalEdit ([bx/di+table] typed-const tables without direct DS refs), ComXfer (1 byte, resync in a literal pool)
  - placeholders for not yet decompiled units: U156F, U142F (overlays), U1D10 (resident); DXGlob has overlapping
    Cfg* / ViewerName (0x982) and CfgB809 / BorderColor (0x809) names to reconcile
  - [ ] decompile main + 0365 + remaining ~50 own overlay units
- [~] HERTZ.EXE (26 KB) — Windows NE, Borland Pascal for Windows / OWL — SKIPPED (out of scope, decided 2026-10-13)

## Per program steps
- [ ] map segments → units (stock RTL/TV vs. own)
- [ ] identify stock units byte-exact (System, Dos, Crt, Objects, Drivers, Views…)
- [ ] reproduce DS layout (typed consts / vars) from -GD map
- [ ] decompile own units, compile, compare per segment
- [ ] full EXE compare = identical

## Not in scope (third-party binaries shipped in the zip)
- ARJ.EXE, RAR.EXE, LHA.EXE, PKZIP/PKUNZIP/PKZIPFIX/ZIP2EXE — not Hombergs' code
