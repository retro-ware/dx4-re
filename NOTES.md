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
- `mov si,SEG; mov es,si; mov al,es:[OFS]` = access to a variable declared `absolute SEG:OFS`;
  `mov ax,SEG; push ax; mov di,OFS; pop es; mov ax,es:[di]` = `MemW[SEG:OFS]`.
- Overlay units with many case/message tables: tools/procdump.py (condensed per-proc dump with decoded literals)
  plus a template generator beats hand-transcribing (see U13A5, SysInfo).
- TP allocates locals downward from the last used byte: a multi-byte var after an odd-ending byte var gets one
  alignment byte of gap (9 Booleans at -1..-9 are followed by a Word at -0xc, not -0xa).
- tryunit now treats differing displacements off a base register (locals [bp-x], fields [di+x]) as real diffs
  unless the (built - orig) delta also occurs among direct DS references; "MATCH(addr)" before this change did
  not verify local-variable layout.

- Temp layout rule (Execute.RunWindow, verified): a string-literal temp is Length+1 bytes, NOT rounded; only the *next*
  allocation is word-aligned. So a trailing 1-byte local (odd end) is invisible in a statement whose first temp is a
  literal of even length ('PATH' -> 5 bytes at the same slot), but shifts every later statement's temps by 2.
- Function results live at [bp-1]/[bp-2]/[bp-4] as the first local. Local layout rule (FindDlg, verified against a 0x894
  frame): every multi-byte local (strings included) starts at align_down(free - size + 1); 1-byte locals are not aligned.
  AddGroup = result(-1), two Bytes(-2,-3), S: string[40] at -0x2c (even anyway); FindDlg: Code: Integer(-0x550), then a
  6-byte unused local, SaveS: string[128] at -0x5d8 (a 7-byte string[6] there would land at -0x558 and shift SaveS to -0x5da).
- Statement temps (literal copies, string expression results) use the same rule and the pool restarts at the end of the
  locals for every statement (ParseFilters: ';' temp and the two ErrorBox literals share the same top slot).
- Byte/Char compares with two complex operands: the operand evaluated FIRST (pushed, or loaded into dl) is the RIGHT one;
  al holds the left operand (`if UpCase(C) <> UpCase(Dir[1])`, `Selected[I] <> Valid[I]`).
- `WordVar in [9, 13]` compiles to byte compares on the low byte (`mov al,[W]; cmp al,9; cmp al,13`) while
  `(W = $3F7)` right after it is a word compare: the mixed shape is `(Key in [9, 13]) or (Key = $3F7)`.
- `repeat ... until A or B or (K = c1) or ...` with a far backward jump ends in `cmp K,cN; je exit; jmp loop`; a chain of
  `cmp K,c; je exit` on a Word (not `in`) means ORed equality tests, not a set.
- Dialogs.SelectDrive clobbers Mouse.MouseMap (0x5c60, 0x8c0 bytes): callers save/restore it with `Save := MouseMap`
  (BlockCopy, src pushed first) like AddProg does.
- Unreferenced locals are common (SizeStr/FormatNum: Byte at -1 + Word after T; DiskImg.RestoreImage: 512-byte buffer
  + 3 bytes). The strict classifier catches them; MATCH(addr) under the old one did not.
- tools/dsnames.py builds work/dsnames_DXMAIN.json: original DS offset -> global name, from tryunit addr maps + test link
  map publics (DATA segment paragraph). The 'CfgColors' 65-byte block ($9E0..$A20) is really ~40 separate option globals
  (SaverOn, ThinButtons, ConfirmDel, PackFull, LongNames=$A18 ...) that SaveCfg/StateIO copy as one block -> the DS
  layout step must declare them contiguously (TColors(CfgColors) casts).
- tools/dd.py (orig/built disassembly of ranges), tools/bpoffs.py (bp-offset sets per proc), tools/mapline.py (code
  offset -> source line via T.MAP line table) are the quick strict-diff triage tools.
- Binary-op operand order (SBMixer, verified): the compiler evaluates the operand needing more registers first and
  keeps the other one in cx/dx. `(7 - CurY) + Y` compiles to cx := Y; ax := 7 - CurY; add ax,cx (left complex, right
  simple -> right loaded into cx first), while `Y + (7 - CurY)` gives dx := 7 - CurY; ax := Y; add ax,dx. For `or`:
  `(T and $F) or (V shl 4)` evaluates `V shl 4` first. So when the dump shows a simple operand loaded first into cx,
  it is the RIGHT operand of a left-complex expression.
