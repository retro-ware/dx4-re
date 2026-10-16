# DOS-Expander 4.0 — Borland Pascal 7.01 source reconstruction and Rust port

A reconstruction of DOS-Expander 4.0 by Heinz Hombergs (1994-96), a DOS file manager and program menu written in Borland Pascal 7.01. The sources in `src/` reproduce parts of the shipped binaries byte for byte. `rust/` holds a reimplementation for modern terminals.

**No original program files or third-party tools are included.** You need your own copy of `DX4.ZIP` and the Borland Pascal 7.01 toolchain.

## Status

| Program | Result |
|---|---|
| `DX.EXE` (3552 B) | byte-identical |
| `DX.COM` (1077 B, TASM 3.2) | byte-identical |
| `DXM.EXE` (97 KB, menu editor) | byte-identical full link |
| `DXMAIN.EXE` (816 KB, overlaid) | partial: most resident and overlay units match per segment (`tools/tryunit.py`), a few units are placeholders, and there is no full link |
| `DXE.EXE`, `DXCD.EXE`, `HERTZ.EXE` | skipped (out of scope) |

The third-party archivers in the zip (ARJ, RAR, LHA, PKZIP and friends) are not Hombergs' code and are not covered. `CHECKLIST.md` has the per-unit detail and `NOTES.md` has the toolchain and codegen findings.

## Layout
- `src/dx/`, `src/dxcom/`, `src/dxm/` — sources for `DX.EXE`, `DX.COM` and `DXM.EXE`
- `src/dxmain/` — units of `DXMAIN.EXE` reconstructed so far
- `tools/` — build scripts, the DOSBox-X runner (`dosrun.sh`), and analysis helpers (segment and overlay listing, unit comparison, disassembly diffs, Ghidra export)
- `rust/` — Cargo workspace: `dxtui` (text-mode toolkit), `dxm` (program menu), `dx` (file manager); see `rust/PORTING.md`
- `ref/` — screen captures and help texts from the original, used by the Rust screen tests
- `NOTES.md`, `CHECKLIST.md` — working notes and progress

## Rebuilding the Pascal sources
1. Extract your `DX4.ZIP` to `dist/DX4/`.
2. Put Borland Pascal 7.01 (TPC.EXE and its units, plus TASM 3.2 for `DX.COM`) in `toolchain/bp701/`. Install DOSBox-X and Python 3.
3. Run the build scripts from the repo root. Each builds in DOSBox-X and compares with the original.
   - `tools/bdx.sh` — `DX.EXE`
   - `tools/bdxcom.sh` — `DX.COM`
   - `tools/dxmbuild.sh` — `DXM.EXE` (prints `DXM.EXE IDENTICAL` on success)
4. To check a single `DXMAIN.EXE` unit: `tools/tryunit.py dist/DX4/DXMAIN.EXE SEG src/dxmain/UNIT.PAS`.

`toolchain/`, `dist/`, `build/`, `work/` and `orig/` are git-ignored.

## Rust port
The port clones the behaviour of the DOS programs for modern terminals (English texts, its own settings and menu formats). Several DOS-only features are not ported, such as modem, CD player, memory views and printing; see `CHECKLIST.md`.

```
cd rust
cargo run --release -p dxm   # program menu
cargo run --release -p dx --bin x4   # file manager
cargo test
```

Settings live in `$DX_HOME` (default `~/.config/dx`).
