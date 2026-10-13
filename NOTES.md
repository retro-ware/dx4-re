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
