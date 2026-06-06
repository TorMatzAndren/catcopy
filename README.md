# catcopy

catcopy (`c`) is a developer-focused text transport utility for terminal workflows.

It captures text payloads from files, stdin, commands, and command batches, then sends those payloads to a useful destination.

catcopy installs two commands:

- `c`
- `catcopy`

Both commands are identical.

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
