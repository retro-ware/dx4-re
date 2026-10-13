#!/bin/sh
# build DX.COM (TASM 3.2) and compare with original
cd "$(dirname "$0")/.." && mkdir -p build/dxcom && cp src/dxcom/DX.ASM build/dxcom/ && tools/dosrun.sh build/dxcom "t:\\bp701\\bin\\tasm dx.asm" && grep -i "error\|warn" build/dxcom/OUT.TXT
python3 tools/obj2com.py build/dxcom/DX.OBJ build/dxcom/DX.COM && cmp build/dxcom/DX.COM dist/DX4/DX.COM && echo DX.COM IDENTICAL
