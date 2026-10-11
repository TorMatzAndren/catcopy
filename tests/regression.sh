#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
C="$ROOT/bin/c"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MOCK="$WORK/mock"; mkdir "$MOCK"
export TMPDIR="$WORK/tmp" USER=catcopy-test DISPLAY=:99
mkdir -p "$TMPDIR"
PASS=0 FAIL=0
ok() { PASS=$((PASS+1)); printf 'ok - %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'not ok - %s\n' "$1"; }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else fail "$name"; fi; }

signal_case() {
  python3 - "$C" "$TMPDIR" "$WORK" "$1" <<'PY'
import os, pathlib, signal, subprocess, sys, time
c, tmp, work, sig_name = sys.argv[1:]
sig = getattr(signal, "SIG" + sig_name)
marker = pathlib.Path(work) / ("child-" + sig_name)
try: marker.unlink()
except FileNotFoundError: pass
p = subprocess.Popen([c, "--stdout", "--", "bash", "-c",
                      'sleep 30 & echo $! > "$1"; wait', "child", str(marker)],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL)
try:
    deadline = time.monotonic() + 3
    while not marker.exists() and time.monotonic() < deadline and p.poll() is None:
        time.sleep(.02)
    assert marker.exists(), "controlled child did not start"
    child_pid = int(marker.read_text())
    os.kill(p.pid, sig)
    status = p.wait(timeout=4)
    assert status == 128 + sig, (status, 128 + sig)
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        stat = pathlib.Path("/proc") / str(child_pid) / "stat"
        if not stat.exists() or stat.read_text().split()[2] == "Z":
            break
        time.sleep(.02)
    else:
        raise AssertionError("grandchild remained running after signal")
    state = pathlib.Path(tmp) / "catcopy-catcopy-test"
    leftovers = list(state.glob("command.*")) if state.exists() else []
    assert not leftovers, leftovers
except Exception:
    p.kill()
    try: p.wait(timeout=2)
    except subprocess.TimeoutExpired: pass
    raise
PY
}

printf '\377\000A\r\n' > "$WORK/input"
"$C" --stdout "$WORK/input" > "$WORK/out" 2> "$WORK/err"
if python3 - "$WORK/out" "$WORK/input" <<'PY'
import pathlib, sys
out, original = map(lambda p: pathlib.Path(p).read_bytes(), sys.argv[1:])
assert b'PATH:' in out and out.endswith(original + b'\n')
PY
then ok 'file header and bytes'; else fail 'file header and bytes'; fi
printf '\000\377\n' | "$C" --stdout > "$WORK/out" 2> "$WORK/err"
printf '\000\377\n' > "$WORK/expect"
cmp -s "$WORK/expect" "$WORK/out" && ok 'stdin binary fidelity' || fail 'stdin binary fidelity'
"$C" --stdout -- bash -c 'printf "\\377\\000"' > "$WORK/out" 2> "$WORK/err"
printf '\377\000' > "$WORK/expect"
cmp -s "$WORK/expect" "$WORK/out" && ok 'command output fidelity' || fail 'command output fidelity'
grep -q 'Captured command output' "$WORK/err" && ! grep -q 'Captured command output' "$WORK/out" && ok 'stdout and stderr separation' || fail 'stdout and stderr separation'
"$C" --stdout -- bash -c 'printf partial; exit 7' > "$WORK/out" 2> "$WORK/err" && fail 'command exit 7' || [[ $? -eq 7 ]] && ok 'command exit status 7'
[[ ! -s "$WORK/err" ]] || true
find "$TMPDIR" -type f -name 'command.*' | grep -q . && fail 'failed command cleanup' || ok 'failed command cleanup'
cat > "$MOCK/wl-copy" <<'MOCK'
#!/usr/bin/env bash
cat > "$CAPTURE"
MOCK
cat > "$MOCK/xclip" <<'MOCK'
#!/usr/bin/env bash
printf started >> "$LIFECYCLE"
cat > "$CAPTURE"
printf done >> "$LIFECYCLE"
MOCK
cat > "$MOCK/failclip" <<'MOCK'
#!/usr/bin/env bash
cat >/dev/null
exit 9
MOCK
chmod +x "$MOCK"/*
export PATH="$MOCK:$PATH" CAPTURE="$WORK/captured" LIFECYCLE="$WORK/lifecycle" WAYLAND_DISPLAY=wayland-test
"$C" --backend wl-copy -- "$WORK"/missing >/dev/null 2>&1 && fail 'missing file failure' || ok 'failed operation cleanup path'
printf payload | "$C" --backend xclip > "$WORK/out" 2> "$WORK/err"
grep -q 'starteddone' "$LIFECYCLE" && [[ "$(cat "$CAPTURE")" == payload ]] && ok 'xclip lifecycle' || fail 'xclip lifecycle'
printf failure | "$C" --backend failclip > "$WORK/out" 2> "$WORK/err" && fail 'failed backend status' || [[ $? -eq 9 ]] && ok 'failed backend status'
find "$TMPDIR/catcopy-catcopy-test" -type f -name 'stdin.*' | grep -q . && fail 'failed backend cleanup' || ok 'failed backend cleanup'

export CATCOPY_PRIORITY=pbcopy
if "$C" --clipboard < /dev/null > "$WORK/out" 2> "$WORK/err"; then
  fail 'missing backend diagnostic'
else
  grep -q 'no supported clipboard backend' "$WORK/err" && ok 'missing backend diagnostic' || fail 'missing backend diagnostic'
fi
unset WAYLAND_DISPLAY DISPLAY
printf fallback | CATCOPY_PRIORITY=pbcopy PATH="/usr/bin:/bin" "$C" > "$WORK/out" 2> "$WORK/err"
[[ "$(cat "$WORK/out")" == fallback ]] && ok 'automatic stdout fallback' || fail 'automatic stdout fallback'

export DESTINATION=stdout
"$C" --stdout --batch check --clear > "$WORK/out" 2> "$WORK/err"
"$C" --stdout --batch check -- bash -c 'printf "one\r\ntwo\n\033[31mRED\033[0m\n\377"' > "$WORK/out" 2> "$WORK/err"
"$C" --stdout --batch check --path > "$WORK/path" 2> "$WORK/err"
BATCH="$(cat "$WORK/path")"
STATE="$TMPDIR/catcopy-catcopy-test"
stat -c %a "$(dirname "$BATCH")" | grep -qx 700 && stat -c %a "$BATCH" | grep -qx 600 && ok 'batch permissions' || fail 'batch permissions'
if python3 - "$BATCH" <<'PY'
import pathlib, sys
b = pathlib.Path(sys.argv[1]).read_bytes()
assert b'two\n' in b and b'RED' in b and b'\xff' in b and b'\x1b' not in b
assert b'one\n' in b
PY
then ok 'CRLF, ANSI and invalid UTF-8 cleaned batch'; else fail 'CRLF, ANSI and invalid UTF-8 cleaned batch'; fi
"$C" --stdout --batch rawcase --clear >/dev/null 2>&1
"$C" --stdout --batch rawcase --raw -- bash -c 'printf "A\\r\\n\\377"' >/dev/null 2>&1
RAW="$STATE/rawcase.txt"
if python3 - "$RAW" <<'PY'
import pathlib, sys
b = pathlib.Path(sys.argv[1]).read_bytes()
assert b'A\r\n\xff' in b
PY
then ok 'raw batch fidelity'; else fail 'raw batch fidelity'; fi
"$C" --stdout --batch check --show > "$WORK/show" 2> "$WORK/err"
cmp -s "$BATCH" "$WORK/show" && ok 'batch show' || fail 'batch show'
"$C" --stdout --batch check --clear >/dev/null 2>&1
[[ ! -s "$BATCH" ]] && ok 'batch clear' || fail 'batch clear'
ln -s "$WORK/out" "$STATE/link.txt"
"$C" --stdout --batch link --clear >/dev/null 2>&1 && fail 'batch symlink rejection' || ok 'batch symlink rejection'
chmod 755 "$STATE"
"$C" --stdout < /dev/null >/dev/null 2>&1 && fail 'unsafe state directory rejection' || ok 'unsafe state directory rejection'
chmod 700 "$STATE"
mkdir "$WORK/shared-parent"
chmod 777 "$WORK/shared-parent"
if TMPDIR="$WORK/shared-parent" "$C" --stdout < /dev/null >/dev/null 2>&1; then
  fail 'replaceable ancestor rejection'
elif [[ ! -e "$WORK/shared-parent/catcopy-catcopy-test" ]]; then
  ok 'replaceable ancestor rejection'
else fail 'replaceable ancestor rejection'; fi

# Existing safe named batches are appended to, while unsafe aliases are rejected.
printf 'legacy-data\n' > "$STATE/legacy.txt"
chmod 600 "$STATE/legacy.txt"
"$C" --stdout --batch legacy -- bash -c 'printf new-data' >/dev/null 2>&1
if grep -q legacy-data "$STATE/legacy.txt" && grep -q new-data "$STATE/legacy.txt"; then ok 'legacy batch preserved on append'; else fail 'legacy batch preserved on append'; fi
ln "$STATE/legacy.txt" "$STATE/hardlink.txt"
"$C" --stdout --batch hardlink --clear >/dev/null 2>&1 && fail 'batch hardlink rejection' || ok 'batch hardlink rejection'
grep -q legacy-data "$STATE/legacy.txt" && ok 'hardlink target preserved' || fail 'hardlink target preserved'

# Concurrent independent invocations must not interfere with temporary payloads.
for i in 1 2; do (printf "run$i" | "$C" --stdout > "$WORK/concurrent$i" 2> "$WORK/e$i") & done
wait
[[ "$(cat "$WORK/concurrent1")" == run1 && "$(cat "$WORK/concurrent2")" == run2 ]] && ok 'concurrent invocations' || fail 'concurrent invocations'
for sig in TERM INT; do
  if signal_case "$sig"; then ok "SIG$sig bounded exit and cleanup"; else fail "SIG$sig bounded exit and cleanup"; fi
done

# Process substitution must receive the combined stream while tee preserves it.
bash -c 'printf out; printf err >&2' 2>&1 | tee >("$C" --stdout > "$WORK/copied" 2> "$WORK/tee.err") > "$WORK/terminal"
for _ in $(seq 1 100); do [[ -f "$WORK/copied" ]] && [[ "$(cat "$WORK/copied")" == outerr ]] && break; sleep 0.02; done
if cmp -s "$WORK/copied" "$WORK/terminal" && [[ "$(cat "$WORK/copied")" == outerr ]]; then ok 'combined tee transport'; else fail 'combined tee transport'; fi

# A failing command must retain its nonempty output and status in the batch.
if "$C" --stdout --batch failrecord --clear >/dev/null 2>&1 &&
   ! "$C" --stdout --batch failrecord -- bash -c 'printf retained; exit 7' >/dev/null 2>&1; then
  grep -q '^7$' "$STATE/failrecord.txt" && grep -q 'retained' "$STATE/failrecord.txt" && ok 'batch preserves failing output and status' || fail 'batch preserves failing output and status'
else fail 'batch preserves failing output and status'; fi

# Concurrent records share one locked append stream.
"$C" --stdout --batch writers --clear >/dev/null 2>&1
for i in $(seq 1 8); do
  ("$C" --stdout --batch writers -- bash -c 'printf "writer-%s" "$1"' _ "$i" >/dev/null 2>&1) &
done
wait
writer_ok=1
for i in $(seq 1 8); do grep -q "writer-$i" "$STATE/writers.txt" || writer_ok=0; done
if [[ "$writer_ok" -eq 1 ]] && python3 - "$STATE/writers.txt" <<'PY'
import pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
records = data.split(b'===== COMMAND =====\n')[1:]
assert len(records) == 8, len(records)
for record in records:
    assert record.count(b'===== EXIT STATUS =====') == 1
    assert record.count(b'===== OUTPUT =====') == 1
    assert b'writer-' in record
    assert b'\n0\n' in record
PY
then ok 'concurrent batch writers'; else fail 'concurrent batch writers'; fi

# Remote host text is passed as one SSH argument, and the payload remains stdin.
cat > "$MOCK/ssh" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$SSH_ARGS"
cat > "$SSH_PAYLOAD"
MOCK
chmod +x "$MOCK/ssh"
export SSH_ARGS="$WORK/ssh-args" SSH_PAYLOAD="$WORK/ssh-payload"
printf remote-payload | "$C" --to 'host.example' > /dev/null 2> "$WORK/ssh.err"
if [[ "$(cat "$SSH_ARGS")" == $'-o\nBatchMode=yes\nhost.example\nDISPLAY=\':0.0\' XDG_SESSION_TYPE=x11 c --clipboard' ]] && [[ "$(cat "$SSH_PAYLOAD")" == remote-payload ]]; then ok 'SSH argument and payload transport'; else fail 'SSH argument and payload transport'; fi
find "$STATE" -type f \( -name 'files.*' -o -name 'stdin.*' -o -name 'command.*' -o -name '*.cmd.*' -o -name '*.clean.*' \) | grep -q . && fail 'no stale temporary payloads' || ok 'no stale temporary payloads'

printf 'Tests: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
