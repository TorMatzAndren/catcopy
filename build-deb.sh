#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.2.0}"
PACKAGE="catcopy"
ARCH="all"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Invalid version: $VERSION" >&2
    exit 1
}

[[ -z "$(git status --porcelain)" ]] || {
    echo "Refusing dirty source tree" >&2
    exit 1
}

for tool in git tar dpkg-deb sha256sum; do
    command -v "$tool" >/dev/null
done

COMMIT="$(git rev-parse HEAD)"
export SOURCE_DATE_EPOCH
SOURCE_DATE_EPOCH="$(git log -1 --format=%ct)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SOURCE="$WORK/source"
BUILD="$WORK/package"
OUT="$ROOT/dist"

mkdir -p "$SOURCE" "$BUILD/DEBIAN"
mkdir -p "$BUILD/usr/bin"
mkdir -p "$BUILD/usr/share/doc/$PACKAGE"
mkdir -p "$OUT"

echo "===== CATCOPY DEBIAN BUILD ====="
echo "Version: $VERSION"
echo "Commit:  $COMMIT"

echo
echo "--- EXPORT SOURCE ---"
git archive HEAD | tar -xf - -C "$SOURCE"

echo
echo "--- INSTALL PACKAGE PAYLOAD ---"
install -m755 "$SOURCE/bin/c" \
    "$BUILD/usr/bin/c"

install -m755 "$SOURCE/bin/catcopy" \
    "$BUILD/usr/bin/catcopy"

install -m644 "$SOURCE/README.md" \
    "$BUILD/usr/share/doc/$PACKAGE/README.md"

install -m644 "$SOURCE/LICENSE" \
    "$BUILD/usr/share/doc/$PACKAGE/LICENSE"

cat > "$BUILD/DEBIAN/control" <<CONTROL
Package: catcopy
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: bash, python3, xclip | wl-clipboard | xsel
Recommends: openssh-client
Maintainer: Jarri Systems
Description: Clipboard transport for terminal and developer workflows
 Copy files, stdin, and command output to the clipboard.
 Supports source headers, command capture, and SSH transport.
 Provides both c and catcopy commands.
CONTROL

ARTIFACT="$OUT/${PACKAGE}_${VERSION}_${ARCH}.deb"

echo
echo "--- BUILD PACKAGE ---"
dpkg-deb --root-owner-group --build "$BUILD" "$ARTIFACT"

echo
echo "--- PACKAGE METADATA ---"
dpkg-deb --field "$ARTIFACT"

echo
echo "--- PACKAGE CONTENTS ---"
dpkg-deb --contents "$ARTIFACT"

echo
echo "--- CHECKSUM ---"
sha256sum "$ARTIFACT"

echo
echo "===== BUILD COMPLETE ====="
