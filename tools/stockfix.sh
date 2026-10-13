#!/bin/sh
# iterate: compile stock reference, drop refs that fail
cd "$(dirname "$0")/.."
SKIP=""
for n in $(seq 1 60); do
  python3 tools/mkstockref.py $SKIP >/dev/null
  tools/dosrun.sh work/stock "t:\\bp701\\bin\\tpc -GD -B -Ut:\\bp701\\bin;t:\\bp701\\tv stockref.pas"
  L=$(grep -o "STOCKREF.PAS([0-9]*): Error" work/stock/OUT.TXT | grep -o "[0-9]*" | head -1)
  [ -z "$L" ] && { tail -1 work/stock/OUT.TXT; echo "skipped:$SKIP"; exit 0; }
  Q=$(sed -n "${L}p" work/stock/STOCKREF.PAS | sed 's/.*@\(.*\);.*/\1/' | tr -d '\r')
  grep "Error" work/stock/OUT.TXT | head -1
  SKIP="$SKIP $Q"
done
