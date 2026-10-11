# catcopy — copy files and command output to the clipboard from Linux

**catcopy** (`c`) is a Linux command-line clipboard tool for copying multiple files, stdin, command output, and command batches while preserving useful source boundaries.

Use it to copy files or terminal output directly to the clipboard:

    c README.md script.py
    git diff | c
    c -- git status
    echo "hello world" | c

When copying multiple files, catcopy keeps each file identifiable with transport headers instead of collapsing everything into an ambiguous text blob. It can also write to stdout or send clipboard payloads to another machine over SSH.

catcopy is designed for developer workflows including:

- copying multiple files to the clipboard
- copying command output from the Linux terminal
- sending Git diffs and diagnostics to LLMs
- preserving filenames and source boundaries
- remote clipboard transport
- headless and SSH workflows

catcopy installs two identical commands:

- `c`
- `catcopy`

---

## Quick Start

Catcopy makes it easy to move terminal output, files, and
diagnostics into AI conversations, bug reports, and code reviews.

### Display and copy simultaneously

    command 2>&1 | tee >(c)

Keep output visible in the terminal while copying the same
stdout and stderr to the clipboard.

### Capture a command

    c -- git status

### Copy multiple files

    c README.md script.py config.json

File boundaries are preserved using transport headers.

### Copy a Git diff

    git diff | c

### Capture several diagnostics

    {
      uname -a
      free -h
      df -h
    } 2>&1 | tee >(c)

### Send output to another machine

    c --to workstation README.md

Remote clipboard delivery uses SSH and requires Catcopy on
the receiving machine. `c --to HOST -- command` runs the command locally,
then sends its captured output to HOST; it does not execute the command remotely.
Remote clipboard setup currently supplies X11 `DISPLAY` and does not claim
Wayland support. `C_REMOTE_SESSION` must remain `x11`.

**Privacy:** Catcopy does not automatically redact secrets.
Review captured data before sharing it externally.

---

# Core Concept

catcopy separates:

- Sources
- Destinations

A source produces text.

A destination receives text.

Examples:

    file → clipboard

    command → clipboard

    stdin → stdout

    file → remote clipboard

    batch → remote clipboard

This makes catcopy useful for:

- LLM workflows
- debugging
- Git review
- diagnostics
- documentation
- JSON inspection
- remote administration
- copy/paste-heavy development

---

# Sources

## Files

Copy one or more files with transport headers:

    c README.md

    c script.py notes.md

File mode preserves boundaries using transport headers:

    ===== TRANSPORT HEADER (NOT PART OF FILE) =====
    PATH: README.md
    NOTE: Do NOT include this header in any saved documents.
    ===============================================

Transport headers are intended for:

- LLM workflows
- code review
- debugging
- multi-file sharing

---

## Stdin

Capture stdin directly:

    echo "hello world" | c

    git diff | c

Stdin mode copies raw input without transport headers.

To keep command output visible in the terminal while also copying it, compose
catcopy with `tee`:

    git diff | tee >(c)

To include both stdout and stderr:

    command 2>&1 | tee >(c)

Here `tee` preserves the normal terminal stream while process substitution sends
the same captured stream to catcopy. This is useful for diagnostics and
copy/paste-heavy development sessions where the terminal output and clipboard
capture should contain the same evidence.

---

## Commands

Run a command and capture stdout:

    c -- git status

    c -- jq '.' data.json

    c -- hostnamectl

This is useful for:

- diagnostics
- JSON inspection
- Git review
- system snapshots

---

# Destinations

## Automatic Destination (Default)

Default mode behaves as follows:

- clipboard when available
- stdout when no clipboard is available

Examples:

    c README.md

    git diff | c

This allows catcopy to work in both desktop and headless environments.

---

## Stdout

Force stdout output:

    c --stdout README.md

    c --stdout -- hostnamectl

This never touches the clipboard.

Useful for:

- SSH sessions
- pipes
- scripting
- CI environments

---

## Local Clipboard

Force local clipboard usage:

    c --clipboard README.md

    c --clipboard -- hostnamectl

If no clipboard backend is available, catcopy exits with an error.

---

## Remote Clipboard

Send a payload to another machine and copy it there:

    c --to turbopi README.md

    c --to 100.87.218.21 -- hostnamectl

Remote mode transfers payloads over SSH.

The destination machine must:

- be reachable through SSH
- have catcopy installed
- have a usable clipboard backend

Localhost is detected automatically and handled without SSH:

    c --to localhost README.md

### Remote command to local clipboard

The opposite direction does not use `--to`.

To run a command on another machine while copying its output to the clipboard
of the machine where you are sitting, keep `c` outside SSH:

    ssh lucy 'command' 2>&1 | tee >(c)

The data path is:

    remote command -> SSH -> local c -> local clipboard

Here `c` runs locally. The remote machine only produces command output, so it
does not need clipboard access or catcopy installed.

By contrast:

    c --to lucy README.md

uses the opposite data path:

    local source -> SSH -> remote c -> remote clipboard

Use `--to HOST` when the destination clipboard is remote. Put `c` outside
`ssh` when the destination clipboard is local.

---

# Batch Mode

Batch mode accumulates multiple command captures into a single payload.

Clear batch:

    c --batch debug --clear

Append commands:

    c --batch debug -- git status

    c --batch debug -- git diff --stat

    c --batch debug -- jq '.' config.json

Show batch:

    c --batch debug --show

Print batch path:

    c --batch debug --path

Each batch records:

- command
- exit status
- cleaned output

Batch cleaning is intentionally lossy: ANSI control sequences are removed,
carriage-return progress updates are reduced to their final line, and selected
spinner prefixes/control bytes are stripped. This mode preserves non-UTF-8
bytes, but these cleanup rules can alter payload bytes. Use raw batch mode when
the exact command output matters:

    c --batch archive --raw -- command-that-emits-binary-data

Raw mode preserves command output bytes within the framed batch record.

Catcopy requires its state directory to be owned by the current user with mode
0700, batch files with mode 0600, and every ancestor directory to be non-writable
by other UIDs or protected by the sticky bit. Unsafe pre-existing paths are
rejected without changing them. Processes running as the same UID share the
trust boundary and can still modify the directory concurrently outside Catcopy.

Example:

    ===== COMMAND =====
    git status

    ===== EXIT STATUS =====
    0

    ===== OUTPUT =====
    On branch main

---

# ANSI Cleanup

Batch mode automatically removes common terminal formatting:

- ANSI escape sequences
- progress bars
- spinners
- carriage-return updates

Useful for:

- Ollama
- long-running diagnostics
- terminal captures
- interactive tools

Example:

    c --batch llm -- ollama run qwen3:8b "Explain this code"

---

# Clipboard Backends

catcopy supports:

- wl-copy
- xclip
- xsel
- pbcopy

Display detected backends:

    c --backends

Select a backend explicitly:

    c --backend xclip README.md

    c --backend wl-copy README.md

Override auto-selection priority:

    CATCOPY_PRIORITY=xsel,xclip,wl-copy,pbcopy c README.md

---

# Environment Variables

Remote clipboard defaults:

    C_REMOTE_DISPLAY=:0.0

    C_REMOTE_SESSION=x11

Override when necessary:

    C_REMOTE_DISPLAY=:1 c --to workstation README.md

---

# Installation

Install from source:

    sudo ./install.sh

Installed commands:

    /usr/local/bin/c
    /usr/local/bin/catcopy

---

# Build Debian Package

Build:

    ./build-deb.sh

Install:

    sudo apt install ./dist/catcopy_0.1.0_all.deb

---

# Uninstall

    sudo ./uninstall.sh

---

# Examples

Copy files:

    c README.md script.py

Capture command output:

    c -- git status --porcelain=v1 --branch

Copy JSON extraction:

    c -- jq '.items[] | .name' data.json

Remote clipboard transport:

    c --to turbopi README.md

Remote diagnostics:

    c --to 100.87.218.21 -- hostnamectl

Headless output:

    c --stdout README.md

---

# Design Philosophy

catcopy does not attempt to interpret or modify payload content.

Its purpose is to provide:

- deterministic capture
- explicit transport boundaries
- minimal workflow friction
- terminal interoperability
- reliable clipboard transport
- reliable remote transport

If output is malformed, the preferred fix is usually:

- adjusting the command
- disabling formatting at the source
- using cleaner CLI options

rather than mutating payloads aggressively inside catcopy.

---

# Positioning

catcopy is not:

- a clipboard manager
- a shell replacement
- a terminal multiplexer

catcopy is a text transport utility for terminal workflows.

---

# License

MIT

# Author

Tor Matz Andrén

https://jarri.systems

https://www.gbsproductions.se
