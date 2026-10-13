# DOS-Expander 4.0 decompilation — notes

Source: `~/Downloads/DX4.ZIP` (extracted read-only to `dist/DX4/`). Author: Heinz Hombergs, 1994–1996.

## Toolchain
- All DX programs: **Borland Pascal 7.01** (TPC.EXE real-mode compiler, TURBO.TPL from 7.01). Proven by a code
  region where 7.0 and 7.01 RTL differ (only the 7.01 bytes occur in DXE/DXM/DXCD/DXMAIN).
- Toolchain lives in `toolchain/{bp70,bp701,bp70de}` (bin/, tv/, rtl/ sources) — from WinWorld, not committed.
  `~/Downloads/Borland Pascal With Objects 7.0 (1992) (5.25-1.2mb).7z` == the WinWorld 7.0 set (same SHA-1).
- `tools/dosrun.sh DIR cmd...` runs DOS commands in DOSBox-X headless; C: = DIR, T: = toolchain/. Output in DIR/OUT.TXT.
- BPC.EXE needs DPMI files that aren't installed; use TPC.EXE (same codegen).
- `tpc -GD` writes a detailed .MAP with every public var/proc address — use it for data layout.

## Pascal codegen fingerprints (TP 7)
- `enter` / `leave` in prologues = `{$G+}`. No `call` to System stack-check at entry = `{$S-}`.
- SS:SP and min/maxalloc give `{$M stack,heapmin,heapmax}` (DX.EXE: `{$M 1024,0,0}`).
- DS layout: typed constants (all modules, program first, then units, System last) then vars (program, units, System).
  Zero-filled data *before* System's OvrCodeList = program typed constants (`const X: T = ...`).
- A data reference into System's area may be a System variable used directly (DX.EXE reuses `ExitCode`).
- `push ds` as an argument = `Seg(var)`; `DSeg` compiles to `mov ax,ds; push ax`.
- Boolean RTL call after pushing two strings with `or ax,ax` = `Pos(sub, s) <> 0`, not `=`.

## Status
- DX.EXE: byte-identical (src/dx/DX.PAS, tools/bdx.sh).

## TP7 link layout (measured, work/exp1)
- Code segments: program, then units in *reverse* uses order (P uses UA, UB → P, UB, UA, System).
- DS: typed consts first (program, then units in uses order, System), then vars (program, UB, UA, units…, System).
- **Typed constants are smart-linked** (unused ones vanish); **vars are not** (unused vars keep their space).

- TPC codegen: a unit compiled with {$O+} copies every string-literal argument of a far call into a
  stack temp (StrLoad, temp sized to the literal) instead of pushing cs:literal. Seen in DXM 0e05 (HELP).
- DXM main: whole program is {$I-} (no IOCheck after Writeln in main block) and {$V-} (DirStr passed to var string).
  U118C has no procedures, only an init section (main calls 118c:0000 in the unit-init list).
- DXGlob.HomeDir is string[79] (StrStore len 0x4f in DXM main).
- tryunit.py also accepts a `program` source (compiled as is, segment compared by program name).
- A function that never assigns its result still ends with `mov al,[bp-1]`; a call followed by no store means the
  original just called the function as a statement ({$X+}), e.g. DXMAIN Execute.RunPacker.
- Overlay stub entries (int 3Fh table) list interface procs in declaration order, then implementation procs whose
  address is taken (@Handler for SetIntVec).
- Buttons.MouseButton (function) shadows Mouse.MouseButton (var): put Buttons before Mouse in `uses`.
- Dos.DirStr is string[67] in TP7; a local copied with limit 0x4f (80 bytes) is `string[79]`, not DirStr.
- `var P: TRecord` params reuse es:di across field accesses; the original reloading `les di,[bp+x]` before every
  access means the parameter is a pointer (`P: PRecord`, accessed as `P^.field`).
