#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BINDIR="$PREFIX/bin"

rm -f "$BINDIR/c" "$BINDIR/catcopy"

echo "Removed:"
echo "  $BINDIR/c"
echo "  $BINDIR/catcopy"
