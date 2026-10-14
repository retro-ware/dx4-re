#!/bin/sh
# dosrun.sh WORKDIR "cmd1" "cmd2" ... : run DOS commands in DOSBox-X headless.
# C: = WORKDIR, T: = toolchain dir. Output of each command goes to WORKDIR/OUT.TXT.
W=$(cd "$1" && pwd); shift
T=$(cd "$(dirname "$0")/../toolchain" && pwd)
CONF=$(mktemp /tmp/dosrun.XXXXXX)
{
  echo "[sdl]"; echo "output=surface"
  echo "[dosbox]"; echo "memsize=16"
  echo "[cpu]"; echo "cycles=max"
  echo "[autoexec]"
  echo "mount c \"$W\""; echo "mount t \"$T\""; echo "c:"
  echo "del OUT.TXT"
  for c in "$@"; do printf "%s >> OUT.TXT\n" "$c"; done
  echo "exit"
} > "$CONF"
SDL_VIDEODRIVER=dummy timeout ${TIMEOUT:-300} dosbox-x -conf "$CONF" -nopromptfolder -silent >/dev/null 2>&1
rm -f "$CONF"
