#!/usr/bin/env python3
"""Real-PTY regression checks for Catcopy command execution."""

import os
import pathlib
import pty
import select
import signal
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATCOPY = str(ROOT / "bin" / "c")

CHILD = r"""
import os
import sys
import time

mode = sys.argv[1]
tty = os.open("/dev/tty", os.O_RDWR)
os.write(tty, b"CHILD_READY\n")

if mode == "interactive":
    os.write(tty, b"INPUT_PROMPT:")
    answer = os.read(tty, 128)
    os.write(tty, b"INPUT_RECEIVED:" + answer)
    print("CAPTURED_OUTPUT", flush=True)
else:
    time.sleep(30)
"""


def run_case(mode, batch=False):
    with tempfile.TemporaryDirectory() as root:
        temporary = pathlib.Path(root) / "tmp"
        temporary.mkdir(mode=0o700)

        env = os.environ.copy()
        env["TMPDIR"] = str(temporary)
        env["USER"] = "catcopy-pty031"

        args = [CATCOPY, "--stdout"]

        if batch:
            args += ["--batch", "pty031", "--"]
        else:
            args += ["--"]

        args += [sys.executable, "-c", CHILD, mode]

        pid, fd = pty.fork()

        if pid == 0:
            os.execve(CATCOPY, args, env)

        transcript = bytearray()
        sent = False
        status = None
        deadline = time.monotonic() + 8

        try:
            while time.monotonic() < deadline:
                readable, _, _ = select.select([fd], [], [], 0.05)

                if readable:
                    try:
                        chunk = os.read(fd, 4096)
                        if chunk:
                            transcript.extend(chunk)
                    except OSError:
                        pass

                if mode == "interactive":
                    if b"INPUT_PROMPT:" in transcript and not sent:
                        os.write(fd, b"hello-from-pty\n")
                        sent = True
                elif b"CHILD_READY" in transcript and not sent:
                    signum = (
                        signal.SIGTERM if mode == "term"
                        else signal.SIGINT
                    )
                    os.kill(pid, signum)
                    sent = True

                done, result = os.waitpid(pid, os.WNOHANG)
                if done:
                    status = os.waitstatus_to_exitcode(result)
                    break

            if status is None:
                os.kill(pid, signal.SIGKILL)
                os.waitpid(pid, 0)
                raise AssertionError(
                    f"{mode}, batch={batch}: timeout; "
                    f"transcript={transcript!r}"
                )
        finally:
            os.close(fd)

        expected = {
            "interactive": 0,
            "term": 143,
            "int": 130,
        }[mode]

        assert status == expected, (
            mode, batch, status, bytes(transcript)
        )
        assert b"CHILD_READY" in transcript, bytes(transcript)

        if mode == "interactive":
            assert (
                b"INPUT_RECEIVED:hello-from-pty" in transcript
            ), bytes(transcript)
            assert b"CAPTURED_OUTPUT" in transcript, bytes(transcript)

        label = "batch" if batch else "command"
        print(f"PASS: {label} {mode} PTY lifecycle")


for batch in (False, True):
    for mode in ("interactive", "term", "int"):
        run_case(mode, batch=batch)

print("PASS: All six integrated PTY checks")
