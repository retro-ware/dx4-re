#!/bin/sh
# expc.sh FILE.PAS : compile a scratch program in work/exp and disassemble its main code segment
cd "$(dirname "$0")/.."
cp "$1" work/exp/E.PAS
tools/dosrun.sh work/exp 't:\bp701\bin\tpc -GD -Ut:\bp701\bin E.PAS'
grep -A3 Error work/exp/OUT.TXT
.venv/bin/python - <<'PY'
import sys,re; sys.path.insert(0,'tools'); sys.path.insert(0,'tools/tpdec')
from mz import MZ
from model import CS
mp=open('work/exp/E.MAP').read()
s=re.search(r'^\s*([0-9A-F]{5})H ([0-9A-F]{5})H ([0-9A-F]{5})H E\s+CODE',mp,re.M)
a,l=int(s[1],16),int(s[3],16)
m=MZ('work/exp/E.EXE'); b=bytes(m.image)[a:a+l]
for i in CS.disasm(b,0): print(f"{i.address:04x} {i.mnemonic} {i.op_str}")
PY
