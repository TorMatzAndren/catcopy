#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
ARCH="${ARCH:-all}"
PKG="catcopy"

BUILD_DIR="dist/${PKG}_${VERSION}_${ARCH}"
DEB_DIR="$BUILD_DIR/DEBIAN"

# Clean build
rm -rf dist
mkdir -p "$DEB_DIR" "$BUILD_DIR/usr/bin"

# Install binaries
install -m755 bin/c "$BUILD_DIR/usr/bin/c"
install -m755 bin/catcopy "$BUILD_DIR/usr/bin/catcopy"

# Control file
cat > "$DEB_DIR/control" <<CONTROL
Package: catcopy
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: bash, xclip | wl-clipboard
Maintainer: Matz Andrén
Description: Clipboard pipeline tool for files, stdin, and command output
 catcopy provides c and catcopy commands for copying files with transport
 headers, stdin streams, or command output directly to the clipboard.
CONTROL

# Build package (fixed ownership issue)
dpkg-deb --root-owner-group --build "$BUILD_DIR" "dist/${PKG}_${VERSION}_${ARCH}.deb"

echo "Built: dist/${PKG}_${VERSION}_${ARCH}.deb"
