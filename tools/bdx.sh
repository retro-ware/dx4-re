#!/bin/sh
# build DX.EXE and compare with original
cd "$(dirname "$0")/.." && cp src/dx/DX.PAS build/dx/ && tools/dosrun.sh build/dx "t:\\bp701\\bin\\tpc -GD -Ut:\\bp701\\bin dx.pas" && grep -v "^Turbo\|PAS(" build/dx/OUT.TXT
python3 tools/mz.py build/dx/DX.EXE dist/DX4/DX.EXE; cmp -l build/dx/DX.EXE dist/DX4/DX.EXE | wc -l
