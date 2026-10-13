#!/bin/bash
# Build DXM.EXE from src/dxm into work/dxm (BP 7.01 via DOSBox-X) and compare with the original.
cd "$(dirname "$0")/.."
W=work/dxm; mkdir -p $W; rm -f "$W"/*.TPU "$W"/*.EXE "$W"/*.MAP; cp src/dxm/*.PAS $W/
tools/dosrun.sh $W 't:\bp701\bin\tpc -GD -B -Ut:\bp701\bin DXM.PAS'
grep -a "Error" $W/OUT.TXT && exit 1
cmp $W/DXM.EXE dist/DX4/DXM.EXE && echo "DXM.EXE IDENTICAL"
