#!/usr/bin/env python3
"""Assert deterministic permissions in a built Catcopy Debian package."""

import io
import stat
import subprocess
import sys
import tarfile

expected_files = {
    "usr/bin/c": 0o755,
    "usr/bin/catcopy": 0o755,
    "usr/share/doc/catcopy/README.md": 0o644,
    "usr/share/doc/catcopy/LICENSE": 0o644,
}
seen_files = set()

payload = subprocess.run(
    ["dpkg-deb", "--fsys-tarfile", sys.argv[1]], check=True, stdout=subprocess.PIPE
).stdout
with tarfile.open(fileobj=io.BytesIO(payload), mode="r:") as archive:
    for member in archive:
        path = member.name.removeprefix("./")
        mode = stat.S_IMODE(member.mode)
        if member.isdir():
            if mode != 0o755:
                raise SystemExit(f"directory mode is {mode:04o}, expected 0755: {path}")
        elif member.isfile():
            expected = expected_files.get(path)
            if expected is None:
                raise SystemExit(f"unexpected package file: {path}")
            if mode != expected:
                raise SystemExit(f"file mode is {mode:04o}, expected {expected:04o}: {path}")
            seen_files.add(path)
        else:
            raise SystemExit(f"unexpected package member type: {path}")

missing = set(expected_files) - seen_files
if missing:
    raise SystemExit(f"missing package files: {sorted(missing)}")
print("Package permissions verified: directories 0755; executables 0755; documentation 0644")
