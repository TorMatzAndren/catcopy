# catcopy

catcopy is a developer-focused clipboard pipeline tool for terminal workflows.

It installs two commands:

- `c`
- `catcopy`

Both do the same thing.

catcopy is designed for workflows involving:

- debugging
- Git inspection
- JSON analysis
- command pipelines
- LLM prompting
- multi-file review
- terminal diagnostics
- copy/paste-heavy development workflows

Instead of repeatedly selecting terminal output manually, catcopy lets you push files, command output, and grouped diagnostic sessions directly into the clipboard.

---

# Features

## Copy files directly to clipboard

    c file1.py file2.md

Files are copied with deterministic transport headers:

    ===== TRANSPORT HEADER (NOT PART OF FILE) =====
    PATH: file1.py
    NOTE: Do NOT include this header in any saved documents.
    ===============================================

This preserves file boundaries during:

- ChatGPT workflows
- code review
- debugging
- archival
- multi-file sharing

---

## Copy stdin directly

    echo "hello world" | c

or:

    git diff | c

stdin mode copies raw output without transport headers.

---

## Copy while also printing to stdout

    git diff | c --stdout

or:

    c --stdout -- jq '.' data.json

`--stdout` copies the captured payload to the clipboard and also prints the same payload to stdout.

Status messages are written to stderr when `--stdout` is enabled, so stdout remains usable for pipelines and logs.

---

## Copy command output directly

    c -- git status --porcelain=v1 --branch

Examples:

    c -- jq '.' data.json

    c -- sed -n '1,120p' script.py

    c -- bash -c "sed -n '1,120p' a.py; sed -n '200,260p' a.py"

This is useful for:

- diagnostics
- JSON inspection
- Git review
- LLM prompts
- partial-file extraction
- command snapshots

---

# Batch Mode

Batch mode accumulates multiple commands into a single clipboard capture.

Clear batch:

    c --batch debug --clear

Append commands:

    c --batch debug -- git status

    c --batch debug -- git diff --stat

    c --batch debug -- jq '.' config.json

Copy full batch:

    c --batch debug --show

Each batch section records:

- executed command
- exit status
- cleaned output

Example structure:

    ===== COMMAND =====
    git status

    ===== EXIT STATUS =====
    0

    ===== OUTPUT =====
    On branch main
    nothing to commit

---

# ANSI / Interactive CLI Cleanup

Some CLI tools generate terminal-specific formatting:

- ANSI escapes
- progress bars
- spinners
- carriage-return rewriting
- interactive wrapping

catcopy batch mode automatically removes most terminal control sequences.

This is especially useful for:

- Ollama
- progress-heavy tools
- long-running diagnostics
- captured terminal sessions

Example:

    c --batch llm -- ollama run --nowordwrap qwen3:8b "Explain this code"

---

# Clipboard Backend Detection

catcopy chooses clipboard backends deterministically.

Default auto-detection priority order:

- Wayland session:
  - `wl-copy`

- X11 session:
  - `xclip`
  - `xsel`

- macOS support when available:
  - `pbcopy`

- Fallback probing order:
  - `wl-copy`
  - `xclip`
  - `xsel`

The active environment is detected using:

- `WAYLAND_DISPLAY`
- `DISPLAY`

Backends can also be selected explicitly:

    c --backend xclip README.md

    c --backend wl-copy README.md

    c --backend pbcopy README.md
Supported explicit backend names:

- `auto`- `wl-copy`
- `xclip`
- `xsel`
- `pbcopy`

---

# Requirements

One clipboard backend is required.

## X11

Install either:

    sudo apt install xclip

or:

    sudo apt install xsel

## Wayland

    sudo apt install wl-clipboard

---

# Tested Platforms

Currently verified locally on:

- Linux/X11 with `xclip`

Routing logic verified through mocked backend testing for:

- Wayland (`wl-copy`)
- X11 fallback (`xsel`)

Implemented but not yet personally verified on real systems:

- native Wayland desktop session
- macOS (`pbcopy`)

Native Windows clipboard support is not implemented yet.

---

# Install From Source

    sudo ./install.sh

Installed commands:

    /usr/local/bin/c
    /usr/local/bin/catcopy

---

# Uninstall

    sudo ./uninstall.sh

---

# Build Debian Package

    ./build-deb.sh

Install package:

    sudo apt install ./dist/catcopy_0.1.0_all.deb

---

# Usage

Show help:

    c --help

or:

    catcopy --help

---

# Real-World Examples

## Git review snapshot

    (
      git status
      echo
      git diff --stat
    ) | c

---

## JSON extraction

    c -- jq '.items[] | .name' data.json

---

## Copy and print command output

    c --stdout -- jq '.' data.json

---

## Multi-range file extraction

    c -- bash -c "
    sed -n '1,120p' app.py
    sed -n '200,260p' app.py
    "

---

## LLM workflow

    c README.md script.py notes.md

Paste directly into ChatGPT or another LLM.

---

# Why not just xclip?

`xclip`, `xsel`, and `wl-copy` are excellent low-level clipboard tools.

catcopy focuses on higher-level developer workflows:

- copying multiple files with preserved boundaries
- direct command-output capture
- grouped diagnostic batches
- ANSI cleanup for interactive tools
- deterministic clipboard backend selection
- transport-safe copy/paste into chats and LLM workflows

catcopy uses existing clipboard tools underneath rather than replacing them.

---

# Design Philosophy

catcopy does not try to reinterpret command output.

Instead it focuses on:

- deterministic capture
- explicit transport boundaries
- minimal workflow friction
- terminal interoperability
- preserving command intent
- reducing repetitive manual selection

If output is malformed, the preferred fix is usually:

- adjusting the command itself
- disabling terminal formatting
- using cleaner CLI flags

rather than mutating output aggressively inside catcopy.

---

# Positioning

catcopy is not:

- a clipboard manager
- a shell replacement
- a terminal multiplexer

It is a developer-focused clipboard capture utility for terminal workflows.

---

# Transparency

The implementation used significant ChatGPT assistance during development.

However:

- the workflow design
- command structure
- feature direction
- iterative refinement
- testing
- operational philosophy

were manually driven and reviewed.

---

# License

MIT

# Author

Tor Matz Andrén
http://jarri.systems
http://www.gbsproductions.se
