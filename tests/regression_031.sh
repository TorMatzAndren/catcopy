#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
C="$ROOT/bin/c"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/tmp" "$WORK/mock"
chmod 700 "$WORK/tmp"

export TMPDIR="$WORK/tmp"
export USER="catcopy031"
export WAYLAND_DISPLAY="catcopy-test"
export CAPTURE="$WORK/clipboard"
export PATH="$WORK/mock:$PATH"

cat > "$WORK/mock/wl-copy" <<'MOCK'
#!/usr/bin/env bash
cat > "$CAPTURE"
MOCK
chmod +x "$WORK/mock/wl-copy"

echo "--- PIPED COMMAND STDIN ---"
printf 'hello-command' |
  "$C" --stdout -- cat > "$WORK/command.out" 2> "$WORK/command.err"

printf 'hello-command' > "$WORK/expected"
cmp "$WORK/expected" "$WORK/command.out"
echo "PASS: c -- cat preserves piped stdin"

echo "--- PIPED BATCH STDIN ---"
printf 'hello-batch' |
  "$C" --stdout --batch stdin031 -- cat \
  > "$WORK/batch.out" 2> "$WORK/batch.err"

grep -q 'hello-batch' "$WORK/batch.out"
echo "PASS: Batch command preserves piped stdin"

echo "--- UNICODE IN CLEANED BATCH ---"
"$C" --stdout --batch unicode031 -- \
  bash -c 'printf "• bullet\n✓ success\n— dash\n⠙ spinner\n"' \
  > "$WORK/unicode.out" 2> "$WORK/unicode.err"

python3 - "$WORK/unicode.out" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()

# The COMMAND header contains the original command text.
# Check only the cleaned OUTPUT section.
marker = b"===== OUTPUT =====\\n"
assert marker.replace(b"\\n", b"\n") in data
output = data.split(marker.replace(b"\\n", b"\n"), 1)[1]

for expected in (
    "• bullet\n".encode(),
    "✓ success\n".encode(),
    "— dash\n".encode(),
):
    assert expected in output, (expected, output)

assert "⠙ spinner".encode() not in output
assert b"spinner\n" in output
output.decode("utf-8")
print("PASS: Unicode preserved and spinner removed")
PY

echo "--- FAILED COMMAND MUST PRESERVE CLIPBOARD ---"
printf 'precious' > "$CAPTURE"

if "$C" --backend wl-copy -- bash -c 'exit 127' \
  > "$WORK/failed.out" 2> "$WORK/failed.err"; then
  echo "FAIL: Failed command unexpectedly succeeded"
  exit 1
else
  status=$?
  test "$status" -eq 127
fi

printf 'precious' > "$WORK/expected"
cmp "$WORK/expected" "$CAPTURE"
echo "PASS: Failed empty command leaves clipboard intact"

echo "--- FAILED COMMAND WITH OUTPUT ---"
if "$C" --backend wl-copy -- \
  bash -c 'printf diagnostic; exit 7' \
  > "$WORK/partial.out" 2> "$WORK/partial.err"; then
  echo "FAIL: Expected command failure"
  exit 1
else
  status=$?
  test "$status" -eq 7
fi

printf 'diagnostic' > "$WORK/expected"
cmp "$WORK/expected" "$CAPTURE"
echo "PASS: Failed command retains nonempty diagnostics"

echo "===== TARGETED REGRESSIONS PASSED ====="
