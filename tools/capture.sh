#!/bin/bash
# capture.sh OUTDIR SCRIPT "DOS command line"
# Runs an original DX4 program in DOSBox-X with tools/keyharn feeding keys from SCRIPT and dumping screens
# (D lines) into OUTDIR as raw 80xRows char/attr dumps. Uses a fresh copy of dist/DX4 each run; files in
# $EXTRA (a directory) are copied over the install first. Programs that do not quit on the final Esc keys
# are killed after $TIMEOUT seconds (default 300); the screens are kept.
set -e
cd "$(dirname "$0")/.."
OUT=$(mkdir -p "$1" && cd "$1" && pwd); SCRIPT=$2; CMD=$3
W=$(mktemp -d "${TMPDIR:-/tmp}/dxcap.XXXXXX")
cp -R dist/DX4/. "$W/"; chmod -R u+w "$W"
[ -n "$EXTRA" ] && cp -R "$EXTRA"/. "$W/"
cp tools/keyharn/KEYHARN.EXE "$W/"; tr '\n' '\r' < "$SCRIPT" | sed 's/\r/\r\n/g' > "$W/KEYS.TXT"
tools/dosrun.sh "$W" 'KEYHARN KEYS.TXT' "$CMD"
for f in "$W"/*.SCR; do [ -e "$f" ] && cp "$f" "$OUT/"; done
cp "$W/OUT.TXT" "$OUT/run.txt" 2>/dev/null || true
rm -rf "$W"
