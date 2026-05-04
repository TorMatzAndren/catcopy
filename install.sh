#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BINDIR="$PREFIX/bin"

echo "Installing catcopy to $BINDIR"

install -Dm755 bin/c "$BINDIR/c"
install -Dm755 bin/catcopy "$BINDIR/catcopy"

echo "Installed:"
echo "  $BINDIR/c"
echo "  $BINDIR/catcopy"
echo
echo "Run:"
echo "  c --help"
