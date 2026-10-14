#!/bin/sh
# Builds the Rust port and installs it: x4 (file manager, DXMAIN) and dxm (program menu) into ${BIN:-~/bin}.
set -e
cd "$(dirname "$0")/../rust"
cargo build --release
BIN=${BIN:-$HOME/bin}
mkdir -p "$BIN"
install -m 755 target/release/x4 target/release/dxm "$BIN/"
echo "installed x4 and dxm in $BIN"
